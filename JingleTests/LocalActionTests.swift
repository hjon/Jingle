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

        let createContentExpectation = self.expectationWithDescription("Creating content")
        session.addContentForApplication(nil, name: "local", senders: nil, disposition: nil) { (ack) -> Void in
            XCTAssertEqual(ack, JingleAck.Ok, "Was not .Ok")

            session.getContentForCreator(.Initiator, name: "local", completion: { (content) -> Void in
                if let content = content {
                    XCTAssertEqual(content.state, ContentState.Starting, "Content did not start in .Starting state")
                } else {
                    XCTFail("No content found")
                }

                createContentExpectation.fulfill()
            })
        }

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testAddingContentsThenStarting() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "peer@example.com")

        let sessionStartWithContentExpectation = self.expectationWithDescription("Start session after adding content")
        session.addContentForApplication(nil, name: "local1", senders: nil, disposition: nil) { (ack) -> Void in return }
        session.addContentForApplication(nil, name: "local2", senders: nil, disposition: nil) { (ack) -> Void in return }
        session.addContentForApplication(nil, name: "local3", senders: nil, disposition: nil) { (ack) -> Void in return }
        session.start { (ack) -> Void in
            XCTAssertEqual(ack, JingleAck.Ok, "Was not .Ok")
            XCTAssertEqual(session.state, SessionState.Pending, "Was not .Pending")

            func checkContentWithName(name: String) {
                session.getContentForCreator(.Initiator, name: name, completion: { (content) -> Void in
                    if let content = content {
                        XCTAssertEqual(content.state, ContentState.Pending, "Content not in .Pending state after starting session")
                    } else {
                        XCTFail("No content found")
                    }
                })

            }

            let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
            dispatch_apply(3, queue, { (index) -> Void in
                checkContentWithName("local\(index + 1)")
            })
            sessionStartWithContentExpectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }
}
