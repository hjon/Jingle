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
    var state: SessionState

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

        if self.role == .Initiator {
            state = .Starting
        } else {
            state = .Pending
        }
    }

    func equivalent(action: ActionData) -> Bool {
        return true
    }

    func processAction(action: ActionData) {
    }
}
