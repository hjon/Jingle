//
//  OutOfOrderTests.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/16/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import XCTest

@testable import Jingle

class OutOfOrderTests: XCTestCase {
    var initiatorSession = Session(initiator: "me@example.com", responder: "peer@example.com", role: .Initiator, sid: "12345")
    var responderSession = Session(initiator: "me@example.com", responder: "peer@example.com", role: .Responder, sid: "12345")

    override func setUp() {
        super.setUp()

        initiatorSession = Session(initiator: "me@example.com", responder: "peer@example.com", role: .Initiator, sid: "12345")
        responderSession = Session(initiator: "me@example.com", responder: "peer@example.com", role: .Responder, sid: "12345")
    }

    // MARK: Session initiate on initiator's session
    func testSessionInitiateOnInitiatorSessionStarting() {
        initiatorSession.state = .Starting

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on initiator's session")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnInitiatorSessionUnacked() {
        initiatorSession.state = .Unacked

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on initiator's session")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnInitiatorSessionPending() {
        initiatorSession.state = .Pending

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on initiator's session")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnInitiatorSessionActive() {
        initiatorSession.state = .Active

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on initiator's session")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnInitiatorSessionEnded() {
        initiatorSession.state = .Ended

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on initiator's session")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    // MARK: Session initiate on responder's session
    // Should only succeed if in .Starting state
    func testSessionInitiateOnResponderSessionStarting() {
        responderSession.state = .Starting

        let ackExpectation = self.expectationWithDescription("Session initiate on responder's session")
        var request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.Ok, "Was not .Ok; should process session initiate on responder's session in .Starting")
            ackExpectation.fulfill()
        }
        let contentRequest = JingleContentRequest(creator: .Initiator, name: "testing")
        request.contents = [contentRequest]
        responderSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnResponderSessionUnacked() {
        initiatorSession.state = .Unacked

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on responder's session in .Unacked")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnResponderSessionPending() {
        initiatorSession.state = .Pending

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on responder's session in .Pending")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnResponderSessionActive() {
        initiatorSession.state = .Active

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on responder's session in .Active")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionInitiateOnResponderSessionEnded() {
        initiatorSession.state = .Ended

        let outOfOrderExpectation = self.expectationWithDescription("Session initiate on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session initiate on responder's session in .Ended")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)
        
        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    // MARK: Session accept on initiator's session
    // Should only succeed if in .Pending state
    func testSessionAcceptOnInitiatorSessionStarting() {
        initiatorSession.state = .Starting

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on initiator's session in .Starting")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnInitiatorSessionUnacked() {
        initiatorSession.state = .Unacked

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on initiator's session in .Unacked")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnInitiatorSessionPending() {
        initiatorSession.state = .Pending

        initiatorSession.addContentForApplication(nil, name: "local", senders: nil, disposition: nil) { (ack) -> Void in
            self.initiatorSession.getContentForCreator(.Initiator, name: "local", completion: { (content) -> Void in
                if let content = content {
                    content.state = .Pending
                }
            })
        }

        let ackExpectation = self.expectationWithDescription("Session accept on initiator's session")
        var request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.Ok, "Was not .Ok; should process session accept on initiator's session in .Pending")
            ackExpectation.fulfill()
        }
        let contentRequest = JingleContentRequest(creator: .Initiator, name: "local")
        request.contents = [contentRequest]
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnInitiatorSessionActive() {
        initiatorSession.state = .Active

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on initiator's session in .Active")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnInitiatorSessionEnded() {
        initiatorSession.state = .Ended

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on initiator's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on initiator's session in .Ended")
            outOfOrderExpectation.fulfill()
        }
        initiatorSession.processRequest(request)
        
        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    // MARK: Session initiate on initiator's session
    func testSessionAcceptOnResponderSessionStarting() {
        responderSession.state = .Starting

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on responder's session")
            outOfOrderExpectation.fulfill()
        }
        responderSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnResponderSessionUnacked() {
        responderSession.state = .Unacked

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on responder's session")
            outOfOrderExpectation.fulfill()
        }
        responderSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnResponderSessionPending() {
        responderSession.state = .Pending

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on responder's session")
            outOfOrderExpectation.fulfill()
        }
        responderSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnResponderSessionActive() {
        responderSession.state = .Active

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on responder's session")
            outOfOrderExpectation.fulfill()
        }
        responderSession.processRequest(request)

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testSessionAcceptOnResponderSessionEnded() {
        responderSession.state = .Ended

        let outOfOrderExpectation = self.expectationWithDescription("Session accept on responder's session")
        let request = JingleRequest(sid: "12345", action: .SessionAccept) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.OutOfOrder, "Was not .OutOfOrder; cannot process session accept on responder's session")
            outOfOrderExpectation.fulfill()
        }
        responderSession.processRequest(request)
        
        self.waitForExpectationsWithTimeout(1, handler: nil)
    }
}
