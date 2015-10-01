//
//  LocalActionTests.swift
//  Jingle
//
//  Created by Jon Hjelle on 10/1/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import XCTest

@testable import Jingle

class LocalActionTests: XCTestCase {
    func testContentAddAction() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "peer@example.com")
        print(session)

        let createContentExpectation = self.expectationWithDescription("Creating content")
        session.addContentForApplication(nil, name: "local", senders: nil, disposition: nil) { (ack) -> Void in
            XCTAssertEqual(ack, JingleAck.Ok, "Was not .Ok")

            let content = session.contentForCreator(.Initiator, name: "local")
            XCTAssertNotNil(content, "No content found")
            if let content = content {
                XCTAssertEqual(content.state, ContentState.Starting, "Content did not start in .Starting state")
            }

            createContentExpectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }
}
