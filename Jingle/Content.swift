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
    var state = ContentState.Starting
    var unackedSendersChange: Senders?

    init(session: Session, creator: Role, name: String, senders: Senders = .Both, disposition: Disposition = .Session) {
        self.session = session
        self.creator = creator
        self.name = name
        self.senders = senders
        self.disposition = disposition
    }

    func equivalent(request: JingleContentRequest) -> Bool {
        return true
    }

    func validateRemoteAction(action: ActionName, request: JingleContentRequest) -> JingleAck {
        switch action {
        case .ContentAdd:
            guard state == .Starting else {
                return .OutOfOrder
            }
        case .ContentModify:
            guard state == .Pending || state == .Active else {
                return .OutOfOrder
            }

            if let unackedSenders = unackedSendersChange, requestSenders = request.senders {
                if session.role == .Initiator && unackedSenders == requestSenders {
                    return .TieBreak
                }
            }
        case .ContentAccept, .ContentReject:
            guard creator == session.role && state == .Pending else {
                return .OutOfOrder
            }
        default:
            return .Ok
        }
        return .Ok
    }

    func executeRemoteAction(action: ActionName, request: JingleContentRequest) {
        switch action {
        case .ContentAdd:
            state = .Pending
        case .ContentAccept:
            state = .Active
        case .ContentReject:
            state = .Rejected
        case .ContentRemove:
            state = .Removed
        default:
            return
        }
    }
}

extension Content: Equatable {}

func ==(lhs: Content, rhs: Content) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension Content: Hashable {
    var hashValue: Int {
        return "\(creator),\(name)".hashValue
    }
}
