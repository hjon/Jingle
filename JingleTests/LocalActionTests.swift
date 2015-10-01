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

            let content = session.contentForCreator(.Initiator, name: "local")
            XCTAssertNotNil(content, "No content found")
            if let content = content {
                XCTAssertEqual(content.state, ContentState.Starting, "Content did not start in .Starting state")
            }

            createContentExpectation.fulfill()
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

            let content1 = session.contentForCreator(.Initiator, name: "local1")
            XCTAssertNotNil(content1, "No content found")
            if let content = content1 {
                XCTAssertEqual(content.state, ContentState.Pending, "Content did not in .Pending state after starting session")
            }

            let content2 = session.contentForCreator(.Initiator, name: "local2")
            XCTAssertNotNil(content2, "No content found")
            if let content = content2 {
                XCTAssertEqual(content.state, ContentState.Pending, "Content did not in .Pending state after starting session")
            }

            let content3 = session.contentForCreator(.Initiator, name: "local3")
            XCTAssertNotNil(content3, "No content found")
            if let content = content3 {
                XCTAssertEqual(content.state, ContentState.Pending, "Content did not in .Pending state after starting session")
            }
            sessionStartWithContentExpectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }
}
