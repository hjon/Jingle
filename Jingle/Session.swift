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
        switch request.action {
        case .SessionInitiate:
            if role == .Initiator || state != .Starting {
                return request.completionBlock(.OutOfOrder)
            }
        case .SessionAccept:
            if role != .Initiator || state != .Pending {
                return request.completionBlock(.OutOfOrder)
            }
        case .ContentAdd:
            if request.contents == nil || request.contents?.count == 0 {
                request.completionBlock(.BadRequest)
                return
            }
            if self.role == .Initiator {
                if let creatorContents = contentsForCreator(self.role) {
                    for (_, content) in creatorContents {
                        let contentRequest = JingleContentRequest(creator: self.role, name: "test")
                        if content.state == .Unacked && content.equivalent(contentRequest) {
                            request.completionBlock(.TieBreak)
                            return
                        }
                    }
                }
            }
        case .ContentModify:
            if request.contents == nil || request.contents?.count == 0 {
                request.completionBlock(.BadRequest)
                return
            }
            if self.role == .Initiator {
                if let requestContents = request.contents {
                    for contentRequest in requestContents {
                        let existingContent = contentForCreator(contentRequest.creator, name: contentRequest.name)
                        if let unackedSendersChange = existingContent?.unackedSendersChange, requestSendersChange = contentRequest.senders {
                            if unackedSendersChange != requestSendersChange {
                                request.completionBlock(.TieBreak)
                                return
                            }
                        }
                    }
                }
            }
        default:
            break
        }

        request.completionBlock(.Ok)

        switch request.action {
        case .SessionInitiate:
            state = .Pending
        case .SessionAccept:
            state = .Active
        case .SessionTerminate:
            state = .Ended
        case .ContentAdd:
            if let contents = request.contents {
                for contentRequest in contents {
                    let content = Content(session: self, creator: peerRole, name: contentRequest.name, senders: contentRequest.senders ?? .Both, disposition: contentRequest.disposition ?? .Session)
                    addContent(content)
                }
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
