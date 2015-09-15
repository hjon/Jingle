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
}

enum JingleAck {
    case Ack
    case BadRequest
    case TieBreak
    case UnknownSession
    case OutOfOrder
}

struct ContentData {
    let creator: Role
    let name: String
    let disposition: Disposition?
    let senders: Senders?
    let application: Any?
    let transport: Any?
}

struct ActionData {
    let sid: String
    let initiator: String?
    let responder: String?
    let action: ActionName
    let contents: Array<ContentData>?
    let info: Any?
    let signalBlock: ((JingleAck) -> Void)
}
