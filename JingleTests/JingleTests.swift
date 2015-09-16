//
//  JingleTests.swift
//  JingleTests
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import XCTest

@testable import Jingle

class JingleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSessionCreation() {
        let sessionExpectation = self.expectationWithDescription("Unknown session")
        let sessionManager = SessionManager()
        let request = JingleRequest(sid: "12345", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.Ack, "Was not .Ack")
            sessionExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "peer@example.com")
        let session = sessionManager.sessionForPeer("peer@example.com", sid: "12345")
        XCTAssertNotNil(session, "Session doesn't exist")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testUnknownSession() {
        let unknownSessionExpectation = self.expectationWithDescription("Unknown session")
        let sessionManager = SessionManager()
        let request = JingleRequest(sid: "12345", action: .ContentAdd) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.UnknownSession, "Was not .UnknownSession")
            unknownSessionExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "peer@example.com")
        let session = sessionManager.sessionForPeer("peer@example.com", sid: "12345")
        XCTAssertNil(session, "Session exists")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testTieBreakWinWithLowerLocalSID() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "peer@example.com")
        session.state = .Unacked

        let tieBreakExpectation = self.expectationWithDescription("Tie break - win with lower local SID")
        let request = JingleRequest(sid: "\(session.sid)1", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.TieBreak, "Was not .TieBreak")
            tieBreakExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "peer@example.com")
        XCTAssertEqual(sessionManager.sessionsForPeer("peer@example.com")?.count, 1, "Incorrect number of sessions for peer")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testTieBreakLoseWithHigherLocalSID() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "peer@example.com")
        session.state = .Unacked

        let tieBreakExpectation = self.expectationWithDescription("Tie break - lose with higher local SID")
        let request = JingleRequest(sid: " \(session.sid)", action: .SessionInitiate) { jingleAck in
            XCTAssertTrue(jingleAck == .Ack, "Was not .Ack")
            tieBreakExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "peer@example.com")
        XCTAssertEqual(sessionManager.sessionsForPeer("peer@example.com")?.count, 2, "Incorrect number of sessions for peer")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testTieBreakWinWithLowerSelfID() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "peer@example.com")
        session.state = .Unacked

        let tieBreakExpectation = self.expectationWithDescription("Tie break - with lower self ID")
        let request = JingleRequest(sid: "\(session.sid)", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.TieBreak, "Was not .TieBreak")
            tieBreakExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "peer@example.com")
        XCTAssertTrue(sessionManager.sessionsForPeer("peer@example.com")?.count == 1, "Incorrect number of sessions for peer")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testTieBreakLoseWithHigherSelfID() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("zme@example.com", peer: "peer@example.com")
        session.state = .Unacked

        let tieBreakExpectation = self.expectationWithDescription("Tie break - lose with higher self ID")
        let request = JingleRequest(sid: "\(session.sid)", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.Ack, "Was not .Ack")
            tieBreakExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "zme@example.com", peer: "peer@example.com")
        XCTAssertEqual(sessionManager.sessionsForPeer("peer@example.com")?.count, 1, "Incorrect number of sessions for peer")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }

    func testTieBreakBadRequestWithSameEverything() {
        let sessionManager = SessionManager()
        let session = sessionManager.createSession("me@example.com", peer: "me@example.com")
        session.state = .Unacked

        let tieBreakExpectation = self.expectationWithDescription("Tie break - bad request with everything the same")
        let request = JingleRequest(sid: "\(session.sid)", action: .SessionInitiate) { jingleAck in
            XCTAssertEqual(jingleAck, JingleAck.BadRequest, "Was not .BadRequest")
            tieBreakExpectation.fulfill()
        }
        sessionManager.processRequest(request, me: "me@example.com", peer: "me@example.com")
        XCTAssertEqual(sessionManager.sessionsForPeer("me@example.com")?.count, 1, "Incorrect number of sessions for peer")

        self.waitForExpectationsWithTimeout(1, handler: nil)
    }
}
