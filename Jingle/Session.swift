//
//  Session.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/11/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import Foundation

enum Role: String {
    case Initiator = "initiator"
    case Responder = "responder"
}

enum SessionState {
    case Starting
    case Unacked
    case Pending
    case Active
    case Ended
}

class Session {
    let initiator: String
    let responder: String
    let role: Role
    let sid: String
    var state = SessionState.Starting
    var contents = [String: [String: Content]]() // mapped by creator, then name
    private let queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.name = "Sesssion.ActionQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .Utility
        return queue
    }()

    var peer: String {
        if role == .Initiator {
            return responder
        } else {
            return initiator
        }
    }

    var peerRole: Role {
        if role == .Initiator {
            return .Responder
        } else {
            return .Initiator
        }
    }

    init(initiator: String, responder: String, role: Role, sid: String) {
        self.initiator = initiator
        self.responder = responder
        self.role = role
        self.sid = sid
    }

    func equivalent(request: JingleRequest) -> Bool {
        let count = countEquivalentContents(request.contents) { (content, request) in
            return true
        }
        return count > 0
    }

    private func addContent(content: Content) {
        var creatorContents = contents[content.creator.rawValue] ?? [:]
        creatorContents[content.name] = content
        contents[content.creator.rawValue] = creatorContents
    }

    func contentForCreator(creator: Role, name: String) -> Content? {
        guard let creatorContents = contents[creator.rawValue] else {
            return nil
        }
        return creatorContents[name]
    }

    private func contentsForCreator(creator: Role) -> [String: Content]? {
        return contents[creator.rawValue]
    }

    func createContentWithName(name: String?, senders: Senders?, disposition: Disposition?) -> Content {
        let content = Content(session: self, creator: self.role, name: name ?? NSUUID().UUIDString, senders: senders ?? .Both, disposition: disposition ?? .Session)
        addContent(content)
        return content
    }

    private func sendRequest(request: JingleRequest) {
        // Do something and call request.completionBlock
    }

    typealias ContentFilter = (content: Content, contentRequest: JingleContentRequest) -> Bool

    private func countEquivalentContents(contentRequests: [JingleContentRequest], filter: ContentFilter) -> Int {
        var equivalentContents = Set<Content>()
        for request in contentRequests {
            if let contents = contentsForCreator(request.creator) {
                for (_, content) in contents where content.equivalent(request) {
                    if filter(content: content, contentRequest: request) {
                        equivalentContents.insert(content)
                    }
                }
            }
        }
        return equivalentContents.count
    }

    private func countAffectedContents(contentRequests: [JingleContentRequest], filter: ContentFilter) -> Int {
        var affectedContents = Set<Content>()
        for request in contentRequests {
            if let content = contentForCreator(request.creator, name: request.name) {
                if filter(content: content, contentRequest: request) {
                    affectedContents.insert(content)
                }
            }
        }
        return affectedContents.count
    }

    private func internalProcessRemoteRequest(request: JingleRequest) {
        // Make sure any action that needs to include contents actually includes contents in the request
        let requiredContentActions: Set<ActionName> = [.SessionInitiate, .SessionAccept, .ContentAdd, .ContentAccept, .ContentRemove, .ContentReject, .ContentModify, .TransportReplace, .TransportReject, .TransportAccept]
        if requiredContentActions.contains(request.action) {
            guard request.contents.count > 0 else {
                request.completionBlock(.BadRequest)
                return
            }
        }

        // Make sure SessionInitiate and ContentAdd don't try to change any existing contents; make sure any other request isn't trying to add a content
        let numAffectedContents = countAffectedContents(request.contents) { content, contentRequest in return true }
        if request.action == .SessionInitiate || request.action == .ContentAdd {
            guard numAffectedContents == 0 else {
                request.completionBlock(.BadRequest)
                return
            }
        } else {
            guard numAffectedContents == request.contents.count else {
                request.completionBlock(.BadRequest)
                return
            }
        }

        // Check for out-of-order session requests
        switch request.action {
        case .SessionInitiate:
            if role == .Initiator || state != .Starting {
                return request.completionBlock(.OutOfOrder)
            }
        case .SessionAccept:
            if role != .Initiator || state != .Pending {
                return request.completionBlock(.OutOfOrder)
            }
        default:
            break
        }

        // Check for content-level tie breaks
        if self.role == .Initiator {
            switch request.action {
            case .ContentAdd:
                let numEquivalentContents = countEquivalentContents(request.contents) { content, contentRequest in
                    return content.state == .Unacked
                }
                if numEquivalentContents > 0 {
                    request.completionBlock(.TieBreak)
                    return
                }
            case .ContentModify:
                let numAffectedContents = countAffectedContents(request.contents) { content, contentRequest in
                    if let unackedSendersChange = content.unackedSendersChange, requestSendersChange = contentRequest.senders {
                        return !(unackedSendersChange == requestSendersChange)
                    } else {
                        return false
                    }
                }
                if numAffectedContents > 0 {
                    request.completionBlock(.TieBreak)
                    return
                }
            default:
                break
            }
        }

        // Make sure all content requests are in-order
        let numInOrderRequests = countAffectedContents(request.contents) { content, contentRequest in
            switch request.action {
            case .ContentModify:
                return (content.state == .Pending || content.state == .Active)
            case .ContentAccept, .ContentReject:
                return (contentRequest.creator == self.role && content.state == .Pending)
            default:
                return true
            }
        }
        if numInOrderRequests != request.contents.count {
            request.completionBlock(.OutOfOrder)
            return
        }

        // Ack that we received the request (with no precondition failures) and we're about to process the request
        request.completionBlock(.Ok)

        // Perform the action
        switch request.action {
        case .SessionInitiate:
            state = .Pending
        case .SessionAccept:
            state = .Active
        case .SessionTerminate:
            state = .Ended
        case .ContentAdd:
            for contentRequest in request.contents {
                let content = Content(session: self, creator: peerRole, name: contentRequest.name, senders: contentRequest.senders ?? .Both, disposition: contentRequest.disposition ?? .Session)
                addContent(content)
            }
        default:
            break
        }
    }

    func processRequest(request: JingleRequest) {
        let operation = NSBlockOperation() {
            self.internalProcessRemoteRequest(request)
        }
        // TODO: Enum for .Remote and .Local and remap .Normal and .High?
        operation.queuePriority = .Normal
        queue.addOperation(operation)
    }

    private func internalProcessLocalRequest(request: JingleRequest) {
        switch request.action {
        case .SessionInitiate:
            if role == .Responder || state == .Starting {
                return request.completionBlock(.OutOfOrder)
            }
        case .SessionAccept:
            if role == .Initiator || state == .Pending {
                return request.completionBlock(.OutOfOrder)
            }
        default:
            break
        }

        switch request.action {
        case .SessionInitiate:
            state = .Unacked
            var outgoingRequest = JingleRequest(sid: sid, action: .SessionInitiate) { jingleAck in
                if jingleAck == .Ok {
                    self.state = .Pending
                } else {
                    self.state = .Ended
                }
                request.completionBlock(jingleAck)
            }
            outgoingRequest.initiator = initiator
            sendRequest(outgoingRequest)
        case .SessionAccept:
            state = .Active
            var outgoingRequest = JingleRequest(sid: sid, action: .SessionAccept, completionBlock: request.completionBlock)
            outgoingRequest.responder = responder
            sendRequest(outgoingRequest)
        case .SessionTerminate:
            state = .Ended
            var outgoingRequest = JingleRequest(sid: sid, action: .SessionTerminate, completionBlock: request.completionBlock)
            outgoingRequest.reason = request.reason
            sendRequest(outgoingRequest)
        default:
            break
        }
    }

    private func processLocalRequest(request: JingleRequest) {
        let operation = NSBlockOperation() {
            self.internalProcessLocalRequest(request)
        }
        // TODO: Enum for .Remote and .Local and remap .Normal and .High?
        operation.queuePriority = .High
        queue.addOperation(operation)
    }

    // MARK: Session actions
    func start(completionBlock: (JingleAck) -> Void) {
        processLocalRequest(JingleRequest(sid: sid, action: .SessionInitiate, completionBlock: completionBlock))
    }

    func accept(completionBlock: (JingleAck) -> Void) {
        processLocalRequest(JingleRequest(sid: sid, action: .SessionAccept, completionBlock: completionBlock))
    }

    func endWithReason(reason: JingleReason?, completionBlock: (JingleAck) -> Void) {
        var request = JingleRequest(sid: sid, action: .SessionTerminate, completionBlock: completionBlock)
        request.reason = reason
        processLocalRequest(request)
    }
}
