//
//  StringOctetCollation.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

enum OctetOrdering {
    case Equal
    case Less
    case Greater
}

func octetOrderingWithString(string1: String, _ string2: String) -> OctetOrdering {
    let buffer1 = [UInt8](string1.utf8)
    let buffer2 = [UInt8](string2.utf8)

    let count1 = buffer1.count
    let count2 = buffer2.count

    let count = min(count1, count2)
    for index in 0..<count {
        let octet1 = buffer1[index]
        let octet2 = buffer2[index]

        if octet1 < octet2 {
            return .Less
        } else if octet1 > octet2 {
            return .Greater
        }
    }

    if count1 < count2 {
        return .Less
    } else if count1 > count2 {
        return .Greater
    } else {
        return .Equal
    }
}
