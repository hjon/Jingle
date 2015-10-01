//
//  ActionData.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

enum ActionName: String {
    case ContentAccept = "content-accept"
    case ContentAdd = "content-add"
    case ContentModify = "content-modify"
    case ContentReject = "content-reject"
    case ContentRemove = "content-remove"
    case DescriptionInfo = "description-info"
    case SecurityInfo = "security-info"
    case SessionAccept = "session-accept"
    case SessionInfo = "session-info"
    case SessionInitiate = "session-initiate"
    case SessionTerminate = "session-terminate"
    case TransportAccept = "transport-accept"
    case TransportInfo = "transport-info"
    case TransportReject = "transport-reject"
    case TransportReplace = "transport-replace"

    func requiresContent() -> Bool {
        let requiredContentActions: Set<ActionName> = [.SessionInitiate, .SessionAccept, .ContentAdd, .ContentAccept, .ContentRemove, .ContentReject, .ContentModify, .TransportReplace, .TransportReject, .TransportAccept]
        if requiredContentActions.contains(self) {
            return true
        } else {
            return false
        }
    }

    func contentAction() -> ActionName {
        switch self {
        case .SessionInitiate:
            return .ContentAdd
        case .SessionAccept:
            return .ContentAccept
        case .SessionTerminate:
            return .ContentRemove
        default:
            return self
        }
    }
}

enum JingleAck {
    case Ok
    case BadRequest
    case TieBreak
    case UnknownSession
    case OutOfOrder

    static func reduceAcks(acks: [JingleAck]) -> JingleAck {
        return acks.reduce(JingleAck.Ok) { previous, current in
            switch current {
            case .BadRequest:
                return .BadRequest
            case .TieBreak:
                if previous == .BadRequest {
                    return .BadRequest
                } else {
                    return .TieBreak
                }
            case .OutOfOrder:
                if previous == .Ok || previous == .UnknownSession {
                    return .OutOfOrder
                } else {
                    return previous
                }
            case .UnknownSession:
                if previous == .Ok {
                    return .UnknownSession
                } else {
                    return previous
                }
            case .Ok:
                return previous
            }
        }
    }
}

enum JingleReason {
    case AlternativeSession(String, String?)
    case Busy(String?)
    case Cancel(String?)
    case ConnectivityError(String?)
    case Decline(String?)
    case Expired(String?)
    case FailedApplication(String?)
    case FailedTransport(String?)
    case GeneralError(String?)
    case Gone(String?)
    case IncompatibleParameters(String?)
    case MediaError(String?)
    case SecurityError(String?)
    case Success(String?)
    case Timeout(String?)
    case UnsupportedApplications(String?)
    case UnsupportedTransports(String?)
}

struct JingleContentRequest {
    let creator: Role
    let name: String
    var disposition: Disposition?
    var senders: Senders?
    var application: Any?
    var transport: Any?

    init(creator: Role, name: String) {
        self.creator = creator
        self.name = name

        disposition = nil
        senders = nil
        application = nil
        transport = nil
    }
}

struct JingleRequest {
    let sid: String
    var initiator: String?
    var responder: String?
    let action: ActionName
    var reason: JingleReason?
    var contents = [JingleContentRequest]()
    var info: Any?
    let completionBlock: ((JingleAck) -> Void)

    init(sid: String, action: ActionName, completionBlock: ((JingleAck) -> Void)) {
        self.sid = sid
        self.action = action
        self.completionBlock = completionBlock

        initiator = nil
        responder = nil
        reason = nil
        info = nil
    }
}

struct JingleLocalRequest {
    let sid: String
    var initiator: String?
    var responder: String?
    let action: ActionName
    var reason: JingleReason?
    var contents = [JingleContentRequest]()
    var info: Any?
    let completionBlock: ((JingleAck) -> Void)

    init(sid: String, action: ActionName, completionBlock: ((JingleAck) -> Void)) {
        self.sid = sid
        self.action = action
        self.completionBlock = completionBlock

        initiator = nil
        responder = nil
        reason = nil
        info = nil
    }
}
