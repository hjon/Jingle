//
//  SessionManager.swift
//  Jingle
//
//  Created by Jon Hjelle on 9/12/15.
//  Copyright © 2015 Jon Hjelle. All rights reserved.
//

import Foundation

class SessionManager {
    var sessions = [String: [String: Session]]() // mapped by peer, then sid

    private func addSession(session: Session) {
        if var peerSessions = sessions[session.peer] {
            peerSessions[session.sid] = session
        } else {
            var peerSessions = [String: Session]()
            peerSessions[session.sid] = session
            sessions[session.peer] = peerSessions
        }
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

    func processAction(action: ActionData, me: String, peer: String) {
        if let session = sessionForPeer(peer, sid: action.sid) {
            session.processAction(action)
            return
        }

        guard action.action == .SessionInitiate else {
            action.signalBlock(.UnknownSession)
            return
        }

        var pendingSessions = [Session]()
        if let peerSessions = sessionsForPeer(peer) {
            for (_, session) in peerSessions {
                if session.state == .Pending && session.equivalent(action) {
                    pendingSessions += [session]
                }
            }
        }
        if let existingSession = pendingSessions.first {
            let sidOrdering = octetOrderingWithString(action.sid, existingSession.sid)
            if sidOrdering == .Less {
                // Fall through to create the session and process action
            } else if sidOrdering == .Greater {
                action.signalBlock(.TieBreak)
            } else {
                let userOrdering = octetOrderingWithString(peer, me)
                if userOrdering == .Less {
                    // Fall through to create the session and process action
                } else if userOrdering == .Greater {
                    action.signalBlock(.TieBreak)
                } else {
                    action.signalBlock(.BadRequest)
                }
            }
        }

        let session = Session(initiator: peer, responder: me, role: .Responder, sid: action.sid)
        addSession(session)
        session.processAction(action)
    }
}
