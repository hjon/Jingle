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
        return countEquivalentContents(request.contents) > 0
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

    private func countEquivalentContents(contentRequests: [JingleContentRequest]) -> Int {
        var equivalentContents = Set<Content>()
        for request in contentRequests {
            if let contents = contentsForCreator(request.creator) {
                for (_, content) in contents where content.equivalent(request) {
                    if content.state == .Unacked {
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
        // Check for out-of-order session requests
        if request.action == .SessionInitiate {
            guard role == .Responder && state == .Starting else {
                return request.completionBlock(.OutOfOrder)
            }
        } else if request.action == .SessionAccept {
            guard role == .Initiator && state == .Pending else {
                return request.completionBlock(.OutOfOrder)
            }
        }

        // Make sure any action that needs to include contents actually includes contents in the request
        if request.action.requiresContent() {
            guard request.contents.count > 0 else {
                request.completionBlock(.BadRequest)
                return
            }
        }

        let contentAction = request.action.contentAction()

        // Check for content-level tie breaks
        if self.role == .Initiator && contentAction == .ContentAdd {
            if countEquivalentContents(request.contents) > 0 {
                request.completionBlock(.TieBreak)
                return
            }
        }

        // Content-level validations
        var validationResults = [JingleAck]()
        for contentRequest in request.contents {
            if let localContent = contentForCreator(contentRequest.creator, name: contentRequest.name) {
                validationResults.append(localContent.validateRemoteAction(contentAction, request: contentRequest))
            } else {
                if contentAction != .ContentAdd {
                    validationResults.append(.BadRequest)
                }
            }
        }

        // Ack that we received the request with the results of precondition checks
        let finalAck = JingleAck.reduceAcks(validationResults)
        request.completionBlock(finalAck)
        guard finalAck == .Ok else {
            return
        }

        // Perform the action
        switch request.action {
        case .SessionInitiate:
            state = .Pending
        case .SessionAccept:
            state = .Active
        case .SessionTerminate:
            state = .Ended
        default:
            break
        }

        if contentAction == .ContentAdd {
            for contentRequest in request.contents {
                let content = Content(session: self, creator: contentRequest.creator, name: contentRequest.name, senders: contentRequest.senders ?? .Both, disposition: contentRequest.disposition ?? .Session)
                addContent(content)
            }
        }

        // Make sure all of these have executed before moving on
        let group = dispatch_group_create()
        for contentRequest in request.contents {
            if let localContent = contentForCreator(contentRequest.creator, name: contentRequest.name) {
                dispatch_group_enter(group)
                localContent.executeRemoteAction(contentAction, request: contentRequest) {
                    dispatch_group_leave(group)
                }
            }
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
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
        // Check for out-of-order session requests
        if request.action == .SessionInitiate {
            guard role == .Initiator && state == .Starting else {
                return request.completionBlock(.OutOfOrder)
            }
        } else if request.action == .SessionAccept {
            guard role == .Responder && state == .Pending else {
                return request.completionBlock(.OutOfOrder)
            }
        }

        // Make sure any action that needs to include contents actually includes contents in the request
        if request.action.requiresContent() {
            guard request.contents.count > 0 else {
                request.completionBlock(.BadRequest)
                return
            }
        }

        let contentAction = request.action.contentAction()

        // Content-level validations
        var validationResults = [JingleAck]()
        for contentRequest in request.contents {
            if let localContent = contentForCreator(contentRequest.creator, name: contentRequest.name) {
                validationResults.append(localContent.validateLocalAction(contentAction, request: contentRequest))
            } else {
                if contentAction != .ContentAdd {
                    validationResults.append(.BadRequest)
                }
            }
        }

        // Ack that we received the request with the results of precondition checks
        let finalAck = JingleAck.reduceAcks(validationResults)
        request.completionBlock(finalAck)
        guard finalAck == .Ok else {
            return
        }

        // Make sure all of these have executed before moving on
        let group = dispatch_group_create()
        for contentRequest in request.contents {
            if let localContent = contentForCreator(contentRequest.creator, name: contentRequest.name) {
                dispatch_group_enter(group)
                localContent.executeLocalAction(contentAction, request: contentRequest) {
                    dispatch_group_leave(group)
                }
            }
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)

        // Perform the action
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

        if contentAction == .ContentAdd {
            for contentRequest in request.contents {
                let content = Content(session: self, creator: contentRequest.creator, name: contentRequest.name, senders: contentRequest.senders ?? .Both, disposition: contentRequest.disposition ?? .Session)
                addContent(content)
            }
        }

        for contentRequest in request.contents {
            if let localContent = contentForCreator(contentRequest.creator, name: contentRequest.name) {
                // TODO: Want to make sure all of these have executed before moving on
                localContent.executeRemoteAction(contentAction, request: contentRequest)
            }
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
