#if canImport(Messages)
import Messages
import SwiftUI
import UIKit

// MARK: - Noum iMessage App Extension
//
// `MessagesViewController` subclass that hosts a SwiftUI surface inside
// the iMessage app drawer. The user taps the Noum icon, sees a preview
// of their current speaking stats, and taps "Challenge them" to drop a
// rich bubble into the conversation.
//
// On send, the bubble carries a `noum://practice` URL. When the
// recipient (or sender, on their own device) taps the bubble, iOS opens
// the URL — the main Noum app's `onOpenURL` handler routes them into a
// fresh practice rep.
//
// The extension is read-only with respect to user state. It reads the
// shared snapshot from the App Group `group.com.jordancoaten.noum` and
// renders it; it never writes back. State authority remains in the
// main app.

@objc(NoumMessagesViewController)
final class NoumMessagesViewController: MSMessagesAppViewController {

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        installContent()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        installContent()
    }

    // MARK: - Content

    private func installContent() {
        // Tear down any previous host before re-installing — `willBecomeActive`
        // and `didTransition` can both fire during the same session.
        children.forEach { child in
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        let snapshot = SharedNoumState.read()
        let host = UIHostingController(
            rootView: MessagesChallengeView(
                snapshot: snapshot,
                onChallenge: { [weak self] in
                    self?.sendChallenge(snapshot: snapshot)
                }
            )
        )
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Send

    private func sendChallenge(snapshot: SharedNoumState) {
        guard let conversation = activeConversation else { return }

        let layout = MSMessageTemplateLayout()
        layout.caption = "Challenge me on Noum"
        layout.subcaption = challengeSubcaption(for: snapshot)
        layout.trailingCaption = "Tap to take the rep"
        if let preview = ShareCard.render(snapshot: snapshot) {
            layout.image = preview
        }

        let message = MSMessage()
        message.layout = layout
        message.url = challengeURL(snapshot: snapshot)
        message.summaryText = "Challenge from Noum"

        conversation.insert(message) { error in
            if let error = error {
                #if DEBUG
                NSLog("NoumMessages: insert failed — %@", error.localizedDescription)
                #endif
            }
        }

        // Slide back to compact so the user can hit Send.
        requestPresentationStyle(.compact)
    }

    private func challengeURL(snapshot: SharedNoumState) -> URL {
        // The main app's `onOpenURL` already handles `noum://`. Carry the
        // sender's rating along so the recipient flow can show "they're
        // at 612 — can you match it?".
        var components = URLComponents()
        components.scheme = "noum"
        components.host = "practice"
        components.queryItems = [
            URLQueryItem(name: "rating", value: String(snapshot.rating)),
            URLQueryItem(name: "streak", value: String(snapshot.currentStreak))
        ]
        return components.url ?? URL(string: "noum://practice")!
    }

    private func challengeSubcaption(for snapshot: SharedNoumState) -> String {
        let rating = snapshot.rating
        let streak = snapshot.currentStreak
        if streak <= 0 { return "Speaking rating \(rating)" }
        return "Rating \(rating) · \(streak)-day streak"
    }
}

#endif
