//
//  SessionManager.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import Foundation

class SessionManager {
    // Probably use dispatch_queue for access
    var sessions = [String: [String: Session]]() // mapped by peer, then sid

    private let queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.name = "SessionManager.ProcessQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .Utility
        return queue
    }()

    private func addSession(session: Session) {
        var peerSessions = sessions[session.peer] ?? [:]
        peerSessions[session.sid] = session
        sessions[session.peer] = peerSessions
    }

    func sessionForPeer(peer: String, sid: String) -> Session? {
        guard let peerSessions = sessions[peer] else {
            return nil
        }
        return peerSessions[sid]
    }

    func sessionsForPeer(peer: String) -> [String: Session]? {
        return sessions[peer]
    }

    func createSession(me: String, peer: String) -> Session {
        var sid = NSUUID().UUIDString
        // On the very small chance there's a sid conflict
        while (sessionForPeer(peer, sid: sid) != nil) {
            sid = NSUUID().UUIDString
        }

        let session = Session(initiator: me, responder: peer, role: .Initiator, sid: sid)
        addSession(session)
        return session
    }

    func internalProcessRequest(request: JingleRequest, me: String, peer: String) {
        if let session = sessionForPeer(peer, sid: request.sid) {
            if session.state == .Pending || session.state == .Active {
                session.processRequest(request)
                return
            }
        }

        guard request.action == .SessionInitiate else {
            request.completionBlock(.UnknownSession)
            return
        }

        var pendingSessions = [Session]()
        if let peerSessions = sessionsForPeer(peer) {
            for (_, session) in peerSessions {
                if session.state == .Unacked && session.equivalent(request) {
                    pendingSessions += [session]
                }
            }
        }
        if let existingSession = pendingSessions.first {
            let sidOrdering = octetOrderingWithString(request.sid, existingSession.sid)
            if sidOrdering == .Less {
                // Fall through to create the session and process action
            } else if sidOrdering == .Greater {
                request.completionBlock(.TieBreak)
                return
            } else {
                let userOrdering = octetOrderingWithString(peer, me)
                if userOrdering == .Less {
                    // Fall through to create the session and process action
                } else if userOrdering == .Greater {
                    request.completionBlock(.TieBreak)
                    return
                } else {
                    request.completionBlock(.BadRequest)
                    return
                }
            }
        }

        let session = Session(initiator: peer, responder: me, role: .Responder, sid: request.sid)
        addSession(session)
        session.processRequest(request)
    }

    func processRequest(request: JingleRequest, me: String, peer: String) {
        queue.addOperationWithBlock { self.internalProcessRequest(request, me: me, peer: peer) }
    }
}
