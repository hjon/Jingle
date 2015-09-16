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

    init(initiator: String, responder: String, role: Role, sid: String) {
        self.initiator = initiator
        self.responder = responder
        self.role = role
        self.sid = sid
    }

    func equivalent(request: JingleRequest) -> Bool {
        return true
    }

    private func sendRequest(request: JingleRequest) {
        // Do something and call request.completionBlock
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
