//
//  Content.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/11/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

enum Disposition: String {
    case Session = "session"
    case EarlySession = "early-session"
}

enum Senders: String {
    case None = "none"
    case Both = "both"
    case Initiator = "initiator"
    case Responder = "responder"
}

enum ContentState {
    case Starting
    case Unacked
    case Pending
    case Active
    case Rejected
    case Removed
}

class Content {
    unowned let session: Session
    let creator: Role
    let name: String
    let disposition: Disposition
    var senders: Senders
    var state: ContentState

    init(session: Session, creator: Role, name: String, senders: Senders = .Both, disposition: Disposition = .Session) {
        self.session = session
        self.creator = creator
        self.name = name
        self.senders = senders
        self.disposition = disposition

        if self.creator == self.session.role {
            state = .Starting
        } else {
            state = .Pending
        }
    }
}
