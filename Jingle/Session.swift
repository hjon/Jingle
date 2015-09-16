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

    func equivalent(action: ActionData) -> Bool {
        return true
    }

    private func internalProcessRemoteRequest(request: ActionData) {
        switch request.action {
        case .SessionInitiate:
            if role == .Initiator || state != .Starting {
                return request.signalBlock(.OutOfOrder)
            }
        case .SessionAccept:
            if role != .Initiator || state != .Pending {
                return request.signalBlock(.OutOfOrder)
            }
        default:
            break
        }

        request.signalBlock(.Ack)

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

    func processAction(action: ActionData) {
        let operation = NSBlockOperation() {
            self.internalProcessRemoteRequest(action)
        }
        // TODO: Enum for .Remote and .Local and remap .Normal and .High?
        operation.queuePriority = .Normal
        queue.addOperation(operation)
    }
}
