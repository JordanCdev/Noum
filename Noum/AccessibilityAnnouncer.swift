#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Accessibility announcer
//
// The single place VoiceOver announcements are posted from.
//
// Sighted users learn that a surface changed by seeing it change. On a live
// coach call nothing is tapped when the coach starts speaking, so a VoiceOver
// user gets silence: the caption label is correct, but VoiceOver only reads a
// label when focus lands on it, and focus never moves on its own.
//
// Rules this type exists to enforce in ONE place:
//
// 1. Never announce speech the user is about to hear anyway. If Aloud is on
//    and a voice is available, the coach's reply is already spoken — a
//    simultaneous VoiceOver announcement of the same words is a double-speak
//    bug, not accessibility.
// 2. Never announce the user's own words back to them. Partial transcripts
//    update per syllable while they speak.
// 3. Never announce what didn't change. Repeat suppression is here, not at
//    each call site, so no surface can regress it independently.
// 4. Stay bounded. A long coach turn is truncated — VoiceOver users can read
//    the full caption by focusing it; an announcement is a notification.

@available(iOS 17.0, *)
enum AccessibilityAnnouncer {
    /// Announcements longer than this are truncated. A caption is a reading
    /// surface; an announcement is a "something changed" nudge.
    static let maximumLength = 240

    /// Last announced string, used to suppress duplicates. SwiftUI re-evaluates
    /// `onChange` on unrelated state churn, so without this a stable caption
    /// can be announced repeatedly.
    @MainActor private static var lastAnnouncement: String?

    @MainActor
    static var isVoiceOverRunning: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isVoiceOverRunning
        #else
        return false
        #endif
    }

    /// Post a VoiceOver announcement. No-ops when VoiceOver is off, when the
    /// message is blank, or when it repeats the previous announcement.
    @MainActor
    static func announce(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isVoiceOverRunning, trimmed != lastAnnouncement else { return }
        lastAnnouncement = trimmed

        let bounded = trimmed.count > maximumLength
            ? String(trimmed.prefix(maximumLength)) + "…"
            : trimmed

        #if canImport(UIKit)
        // High priority so a state change ("Listening") isn't dropped while
        // VoiceOver is mid-utterance on something else.
        let announcement = AttributedString(
            bounded,
            attributes: AttributeContainer.accessibilitySpeechAnnouncementPriority(.high)
        )
        AccessibilityNotification.Announcement(announcement).post()
        #endif
    }

    /// Clears repeat suppression. Call when a surface is dismissed so the same
    /// line can announce again on the next visit.
    @MainActor
    static func reset() {
        lastAnnouncement = nil
    }
}

#endif
