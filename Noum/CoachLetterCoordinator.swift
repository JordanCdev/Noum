#if canImport(SwiftUI)
import Foundation
import SwiftUI

// MARK: - Coach Letter Coordinator
//
// Bridge between the deterministic letter generator and the live
// SwiftUI surfaces. Lives on the MainActor so it reads every store
// the letter input needs without per-view threading.
//
// One method, three effects:
//   1. Snapshots the prior calendar month's sessions + baseline.
//   2. Generates a CoachLetter via `CoachLetterGenerator.generate(...)`.
//   3. Persists to `CoachLetterStore.shared` AND injects a rendered
//      coach turn into the Ask Noum thread via
//      `AskNoumStore.injectCoachTurn(_:)`.
//
// Mirrors the M20 `ForwardPlanCoordinator` shape so the architectural
// pattern is consistent across coach-grade artifacts.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
enum CoachLetterCoordinator {

    /// Build the letter input from live stores. Pure-ish — the only
    /// side effect is reading published properties.
    static func buildInput(monthKey: String) -> CoachLetterInput {
        let voice = CoachingProfileStore.shared.profile?.speakingStyleGoal
        let baseline = BaselineStore.shared.baseline
        let allSessions = PracticeSessionStore.shared.sessions
        let bigMoment = BigMomentStore.shared.activeMoment
        let bigMomentDays = bigMoment.flatMap { BigMomentStore.daysUntil($0) }

        let sessionsInMonth: [PracticeSession]
        if let (start, end) = CoachLetter.dateRange(forMonthKey: monthKey) {
            sessionsInMonth = allSessions.filter { $0.date >= start && $0.date < end }
        } else {
            sessionsInMonth = []
        }

        return CoachLetterInput(
            monthKey: monthKey,
            voice: voice,
            baseline: baseline,
            sessionsInMonth: sessionsInMonth,
            allSessions: allSessions,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDays
        )
    }

    /// Generate the letter for the prior calendar month and drop it
    /// into the Ask Noum thread. Returns the new letter so the caller
    /// can present feedback (toast, badge, deep-link).
    ///
    /// Idempotent: if a letter for the target month already exists,
    /// returns the existing one without re-injecting.
    @discardableResult
    static func generateAndAnnounce(now: Date = Date()) -> CoachLetter {
        let monthKey = CoachLetter.previousMonthKey(now: now)

        // Idempotency — if we already wrote this month's letter,
        // return it without re-injecting. The chat thread should
        // not get a duplicate bubble.
        if let existing = CoachLetterStore.shared.letters.first(where: { $0.month == monthKey }) {
            return existing
        }

        let input = buildInput(monthKey: monthKey)
        var letter = CoachLetterGenerator.generate(input: input, now: now)
        let injectedID = AskNoumStore.shared.injectCoachTurn(letter.content)
        letter = CoachLetter(
            id: letter.id,
            month: letter.month,
            content: letter.content,
            voiceAtGeneration: letter.voiceAtGeneration,
            generatedAt: letter.generatedAt,
            injectedMessageID: injectedID,
            isAIBacked: letter.isAIBacked
        )
        CoachLetterStore.shared.record(letter)
        return letter
    }

    /// Auto-fire decision: on app launch / scene-active, should we
    /// generate this month's letter now? Yes when:
    ///   - We're on day 1-3 of a new month (grace window for users
    ///     who don't open the app on the 1st), AND
    ///   - We don't already have a letter for the prior month, AND
    ///   - The user has at least 1 session in their history (don't
    ///     fire on a brand-new install with no data at all)
    ///
    /// The generator itself handles the thin-data path (≥5 sessions
    /// for confident verdict; honest copy otherwise), so this gate
    /// is the cheaper "is there anything to read" check.
    static func shouldAutoFire(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let day = calendar.component(.day, from: now)
        guard day >= 1, day <= 3 else { return false }
        let monthKey = CoachLetter.previousMonthKey(now: now)
        guard !CoachLetterStore.shared.hasLetter(for: monthKey) else { return false }
        guard !PracticeSessionStore.shared.sessions.isEmpty else { return false }
        return true
    }

    /// Convenience: check + fire in one call. Safe to call repeatedly
    /// (idempotent in both gating + generation paths).
    static func autoFireIfDue(now: Date = Date()) {
        guard shouldAutoFire(now: now) else { return }
        generateAndAnnounce(now: now)
    }
}

#endif
