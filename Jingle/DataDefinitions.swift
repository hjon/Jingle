//
//  ActionData.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

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
    let action: String
    let contents: Array<ContentData>?
    let info: Any?
}
