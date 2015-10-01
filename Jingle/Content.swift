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

    func executeRemoteAction(action: ActionName, request: JingleContentRequest, completion: () -> Void) {
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
            completion()
            return
        }
        completion()
    }

    func validateLocalAction(action: ActionName, request: JingleContentRequest) -> JingleAck {
        switch action {
        case .ContentAdd:
            guard state == .Starting else {
                return .OutOfOrder
            }
        case .ContentModify:
            guard state == .Pending || state == .Active else {
                return .OutOfOrder
            }
        case .ContentAccept, .ContentReject:
            guard creator != session.role && state == .Pending else {
                return .OutOfOrder
            }
        default:
            return .Ok
        }
        return .Ok
    }

    func executeLocalAction(action: ActionName, request: JingleContentRequest?, completion: (JingleContentRequest) -> Void) {
        if action == .SessionInitiate {
            state = .Unacked
            // Ultimately create an offer based on application/transport, which had been deferred from a content-add before the session started
            var contentRequest = JingleContentRequest(creator: creator, name: name)
            contentRequest.senders = senders
            contentRequest.disposition = disposition
            completion(contentRequest)
            return
        }

        switch action {
        case .ContentAdd:
            state = .Starting
            if (session.state != .Starting) {
                // Ultimately will create offer based on application/transport and return that
                var contentRequest = JingleContentRequest(creator: creator, name: name)
                contentRequest.senders = senders
                contentRequest.disposition = disposition
                completion(contentRequest)
                return
            } else {
                // Otherwise initialize everything and return default result (which is just a dummy for this case)
            }
        case .ContentAccept:
            state = .Active
        case .ContentReject:
            state = .Rejected
        case .ContentRemove:
            state = .Removed
        default:
            break
        }

        let contentRequest = JingleContentRequest(creator: creator, name: name)
        completion(contentRequest)
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
