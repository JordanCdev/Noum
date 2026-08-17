#if canImport(SwiftUI)
import SwiftUI
import os

// MARK: - Ask Noum view
//
// The chat surface for the user's persistent coaching thread. Reads from
// `AskNoumStore` for the message log and `AICoachChatService` for the
// actual model calls. System prompt + user context block are produced
// by `CoachContextBuilder` at send-time.
//
// Layout (top to bottom):
//   • Header: native navigation title and back behavior. Coach interpretation
//     uses the shared scope mark instead of borrowing live-audio identity.
//   • Current focus strip: visible only when the thread has messages and the
//     case file has an active target/focus.
//   • Empty state (no messages): one recommended ask, with alternatives tucked
//     into a menu. Removes first-message friction without a prompt tray.
//   • Thread: alternating user (right-aligned brand-blue bubble) +
//     coach (left-aligned) rows. Only the current coach read receives the
//     authored card + scope identity; older replies become quiet history.
//     The in-flight bubble uses the same static coach-read mark. A just-landed reply then REVEALS word by word
//     (the coach reads as writing to you, not popping in fully formed) —
//     view-only timing, the store still holds the full text, and
//     reduce-motion lands it instantly.
//   • Continuation: a single "Next move" panel when a drill/choice/follow-up
//     is earned; generic replies stay quiet.
//   • Input bar: rounded text field + ONE 44pt trailing control that swaps
//     glyph by draft state — mic when empty, arrow.up when there's text,
//     stop.fill while recording. Disabled while a reply is in flight; falls
//     back to send-only when voice can't be served.
//
// Brand alignment: white cards on light background, brand-purple accents
// for the coach surface, with role-specific static graphics.

/// Pure presentation contract for a typed transport limitation. Keeping the
/// retry policy beside the copy prevents a permanent on-device identity from
/// offering a button that can only return the same result.
struct AskNoumAvailabilityPresentation: Equatable {
    let message: String
    let showsCheckAgain: Bool
    let connectsLocalGuest: Bool

    static func resolve(
        _ reason: CoachChatUnavailableReason
    ) -> AskNoumAvailabilityPresentation {
        switch reason {
        case .authenticationPending:
            return AskNoumAvailabilityPresentation(
                message: "Noum is temporarily unavailable. Your message is still here.",
                showsCheckAgain: true,
                connectsLocalGuest: false
            )
        case .localOnlyGuest:
            return AskNoumAvailabilityPresentation(
                message: "Connect this guest once to use live coaching. Your practice stays on this device if the connection fails.",
                showsCheckAgain: false,
                connectsLocalGuest: true
            )
        case .secureSessionMissing:
            return AskNoumAvailabilityPresentation(
                message: "Your coaching history is loaded, but Ask Noum needs its secure session reconnected. Your practice is unchanged.",
                showsCheckAgain: true,
                connectsLocalGuest: false
            )
        case .backendVersionMissing:
            return AskNoumAvailabilityPresentation(
                message: "This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it.",
                showsCheckAgain: true,
                connectsLocalGuest: false
            )
        case .debugProviderMissing:
            return AskNoumAvailabilityPresentation(
                message: "Live coaching isn’t connected in this build.",
                showsCheckAgain: true,
                connectsLocalGuest: false
            )
        case .service:
            return AskNoumAvailabilityPresentation(
                message: "Noum is temporarily unavailable. Your message is still here.",
                showsCheckAgain: true,
                connectsLocalGuest: false
            )
        }
    }
}

/// Pure policy for the unavailable banner's escalation affordance. Repeated
/// failed re-checks on a *reportable* reason lead the banner with a support
/// report; self-resolving states never route to support. Kept beside
/// `AskNoumAvailabilityPresentation` so the copy and the escalation policy
/// gating the same banner live together — and stay testable without SwiftUI.
enum AskNoumAvailabilityRecheckPolicy {
    /// Failed re-checks on a reportable reason before "Report issue" leads.
    static let reportThreshold = 2

    /// Only failures where reporting is the real remediation count toward
    /// the threshold. `.authenticationPending` settles on its own once auth
    /// hydrates, `.debugProviderMissing` is a debug-build configuration
    /// state, and `.localOnlyGuest` has its own Connect affordance — none
    /// of those is a support issue.
    static func countsTowardReport(_ reason: CoachChatUnavailableReason) -> Bool {
        switch reason {
        case .authenticationPending, .debugProviderMissing, .localOnlyGuest:
            return false
        case .secureSessionMissing, .backendVersionMissing, .service:
            return true
        }
    }

    /// Whether the banner should lead with "Report issue" for this reason
    /// at this failed-re-check count. A quiet re-check always stays
    /// alongside the report so recovery never requires leaving the screen.
    static func shouldOfferReport(
        reason: CoachChatUnavailableReason,
        failedRechecks: Int
    ) -> Bool {
        countsTowardReport(reason) && failedRechecks >= reportThreshold
    }

    /// Privacy-safe diagnostic code for the support draft — a stable label
    /// per typed reason, never account or content data.
    static func reportCode(for reason: CoachChatUnavailableReason) -> String {
        switch reason {
        case .authenticationPending: return "authenticationPending"
        case .localOnlyGuest: return "localOnlyGuest"
        case .secureSessionMissing: return "secureSessionMissing"
        case .backendVersionMissing: return "backendVersionMissing"
        case .debugProviderMissing: return "debugProviderMissing"
        case .service: return "service"
        }
    }
}

// MARK: - Coach message formatting

enum CoachMessageTextFormatter {
    struct InlineSegment: Equatable {
        let text: String
        let isStrong: Bool
    }

    enum Block: Equatable {
        case paragraph(String)
        case bullet(String)
        case numbered(Int, String)
    }

    static func blocks(from text: String) -> [Block] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { raw -> Block? in
                let trimmed = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                if let bullet = bulletText(from: trimmed) {
                    return .bullet(bullet)
                }
                if let numbered = numberedText(from: trimmed) {
                    return .numbered(numbered.index, numbered.text)
                }
                return .paragraph(strippedHeadingPrefix(from: trimmed))
            }
    }

    static func inlineSegments(from text: String) -> [InlineSegment] {
        if let leadIn = plainLeadInSegments(from: text) {
            return leadIn
        }

        var segments: [InlineSegment] = []
        var buffer = ""
        var isStrong = false
        var index = text.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(InlineSegment(text: buffer, isStrong: isStrong))
            buffer = ""
        }

        while index < text.endIndex {
            let next = text.index(after: index)
            if next < text.endIndex,
               text[index] == "*",
               text[next] == "*" {
                flush()
                isStrong.toggle()
                index = text.index(after: next)
            } else {
                buffer.append(text[index])
                index = next
            }
        }
        flush()
        return segments.isEmpty ? [InlineSegment(text: text, isStrong: false)] : segments
    }

    private static func plainLeadInSegments(from text: String) -> [InlineSegment]? {
        let leadIns = [
            "Read:", "The read:", "Coach read:", "Move:", "Next move:",
            "Why:", "Evidence:", "Try:", "Try this:", "Focus:",
            "Target:", "Next rep:", "Drill:"
        ]
        let lower = text.lowercased()
        guard let match = leadIns.first(where: { lower.hasPrefix($0.lowercased()) }) else {
            return nil
        }
        let split = text.index(text.startIndex, offsetBy: match.count)
        let rest = String(text[split...])
        return [
            InlineSegment(text: String(text[..<split]), isStrong: true),
            InlineSegment(text: rest, isStrong: false)
        ].filter { !$0.text.isEmpty }
    }

    private static func bulletText(from trimmed: String) -> String? {
        for marker in ["- ", "* ", "• "] where trimmed.hasPrefix(marker) {
            let value = String(trimmed.dropFirst(marker.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func numberedText(from trimmed: String) -> (index: Int, text: String)? {
        guard let separator = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return nil
        }
        let prefix = trimmed[..<separator]
        guard !prefix.isEmpty,
              prefix.allSatisfy({ $0.isNumber }),
              let index = Int(prefix),
              index > 0 else {
            return nil
        }
        let afterSeparator = trimmed.index(after: separator)
        guard afterSeparator < trimmed.endIndex,
              trimmed[afterSeparator].isWhitespace else {
            return nil
        }
        let value = String(trimmed[afterSeparator...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : (index, value)
    }

    private static func strippedHeadingPrefix(from trimmed: String) -> String {
        var value = trimmed
        while value.first == "#" {
            value.removeFirst()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AskNoumCoachVisibleText {
    /// Last-line render-time defense for coach text. The store SHOULD hand us
    /// already-sanitized copy — `AICoachChatService` strips scaffolding before
    /// storage — but the display layer must NEVER render raw scaffold (a
    /// `Read:` / `Next move:` lead-in, a `**bold**` label) even if something
    /// upstream slips: a legacy persisted row, a UI-test seed, or a future
    /// pipeline change. This re-runs the SAME shared strip the service uses
    /// (`CoachReplyTextSanitizer.coachReplyText`) — not a fork of the regex —
    /// so a scaffold label can never reach a `Text()` view. It keeps bullets
    /// and numbered steps so chat still scans well.
    ///
    /// Falls back to the trimmed original ONLY if the sanitizer would blank the
    /// bubble entirely (an all-scaffold reply). That is an extreme edge the
    /// store already routes to a failure notice upstream; a possibly-imperfect
    /// line still beats a silently empty coach bubble.
    static func displayText(for message: CoachMessage) -> String {
        let sanitized = CoachReplyTextSanitizer.coachReplyText(from: message.text)
        if !sanitized.isEmpty { return sanitized }
        return message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func text(
        for message: CoachMessage,
        revealingMessageID: UUID?,
        revealedText: String
    ) -> String {
        guard message.id == revealingMessageID else { return displayText(for: message) }
        if message.isPending {
            return displayText(for: message)
        }
        // `revealedText` is a prefix built from `displayText(for:)` in
        // `startReveal`, so it is already sanitized — rendering it verbatim
        // keeps the word-by-word reveal in lockstep with the final text.
        return revealedText
    }
}

/// Bounded provenance line shown directly beneath the latest coach response.
/// It names only inputs the user can inspect and stays silent when either side
/// of the claim is missing.
enum AskNoumEvidenceMetadata {
    static func line(
        responseKind: CoachChatResponseKind?,
        hasCurrentFocus: Bool,
        recentRepCount: Int
    ) -> String? {
        // Only this lane is contractually allowed to transmit personal
        // assessment/history evidence. General, conversational, memory-only,
        // and legacy unknown replies must not borrow a global account count to
        // imply that their visible wording came from recent reps.
        guard responseKind == .personalEvidenceRead else { return nil }
        guard hasCurrentFocus, recentRepCount > 0 else { return nil }
        let boundedCount = min(recentRepCount, 12)
        let noun = boundedCount == 1 ? "rep" : "reps"
        return "Based on your current focus and \(boundedCount) recent \(noun)"
    }
}

/// User-safe projection of the single intervention already selected by the
/// coach reasoning pass. This exposes authored coaching material — model line,
/// drill, and observable pass condition — without exposing private assessment
/// scores, deliberation, provider diagnostics, or hidden prompt content.
struct AskNoumPracticeMovePresentation: Equatable {
    let title: String
    let modelLine: String
    let drill: String
    let passCondition: String

    static func make(metadata: CoachTurnMetadata?) -> AskNoumPracticeMovePresentation? {
        guard let assessment = metadata?.assessment else { return nil }
        let posture = CoachReplyPosture.resolve(
            userText: assessment.questionRestatement,
            requestedMetrics: assessment.requestedMetrics ?? []
        )
        guard posture == .coachedAttempt,
              let intervention = CoachReasoningPass.interventionForAssessment(
                  assessment,
                  posture: posture
              ),
              intervention.id != "presence-before-practice" else {
            return nil
        }
        let exactDrill = assessment.nextProofTest
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AskNoumPracticeMovePresentation(
            title: intervention.title,
            modelLine: intervention.modelLine,
            drill: exactDrill.isEmpty ? intervention.drill : exactDrill,
            passCondition: intervention.passCondition
        )
    }
}

/// User-facing projection of the bounded personal context available to Ask
/// Noum. This is deliberately a presentation value rather than another state
/// owner: the source of truth remains the existing profile, practice, proof,
/// memory, and thread stores that `CoachReplyPipeline` already reads.
///
/// Keep the labels categorical. They explain what can enter secure coaching
/// without rendering speech content or creating content-bearing analytics.
struct AskNoumAttachedContextPresentation: Equatable {
    static let maximumVerifiedQuotes = 3
    static let privacyExplanation = "These categories stay inside Ask Noum’s secure coaching flow. Growth analytics never records your words, prompts, or transcripts."

    let headline: String
    let categoryLine: String
    /// One short line for the visible context pill, derived from the SAME
    /// resolved inputs as the VoiceOver wording — so the pill never claims
    /// a focus that didn't resolve or evidence that isn't attached.
    let summaryLine: String

    static func make(
        latestTimedPracticeLabel: String?,
        hasLatestTimedTranscript: Bool,
        hasRecentPractice: Bool,
        verifiedQuoteCount: Int,
        currentFocus: String?,
        hasSavedGoal: Bool,
        conversationMessageCount: Int
    ) -> AskNoumAttachedContextPresentation {
        let practiceLabel = normalized(latestTimedPracticeLabel)
        let focus = normalized(currentFocus)

        let headline: String
        switch (practiceLabel, focus) {
        case let (practice?, focus?):
            headline = "\(practice) · focus: \(focus)"
        case let (practice?, nil):
            headline = "\(practice) coaching context"
        case let (nil, focus?):
            headline = "Current focus: \(focus)"
        case (nil, nil):
            headline = "Your coaching context"
        }

        var categories: [String] = []
        if hasRecentPractice {
            categories.append("recent rep summaries")
        }
        if hasLatestTimedTranscript, let practiceLabel {
            categories.append("latest \(practiceLabel) transcript")
        }
        let boundedQuotes = min(max(0, verifiedQuoteCount), maximumVerifiedQuotes)
        if boundedQuotes > 0 {
            categories.append("\(boundedQuotes) verified \(boundedQuotes == 1 ? "quote" : "quotes")")
        }
        if focus != nil {
            categories.append("current coaching focus")
        }
        if hasSavedGoal {
            categories.append("saved speaking goal")
        }
        if conversationMessageCount > 0 {
            // AskNoumStore owns and enforces its replay limit. The UI names the
            // bounded category without duplicating that persistence constant.
            categories.append("this bounded conversation")
        }

        let categoryLine = categories.isEmpty
            ? "No personal evidence is attached yet."
            : "Attached: \(categories.joined(separator: " · "))."

        let summaryLine: String
        switch (hasRecentPractice, focus != nil) {
        case (true, true):
            summaryLine = "Using your recent reps + current focus"
        case (true, false):
            summaryLine = "Using your recent reps"
        case (false, true):
            summaryLine = "Using your current focus"
        case (false, false):
            summaryLine = categories.isEmpty
                ? "No personal evidence attached yet"
                : "Using your coaching context"
        }

        return AskNoumAttachedContextPresentation(
            headline: headline,
            categoryLine: categoryLine,
            summaryLine: summaryLine
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum AskNoumVisibleCopy {
    static let currentFocus = "Current focus"
    // "Coach check-in", not "Review your focus" — "focus" already labels the
    // strip and the context pill on the same empty screen, and the chip is a
    // coach priority signal rather than case-file vocabulary (the visible-copy
    // test bans case-file language like "review due").
    static let coachCheckIn = "Coach check-in"
    static let askNoum = "Ask Noum"

    static let primaryLabels = [currentFocus, coachCheckIn, askNoum]
}

@available(iOS 17.0, macOS 12.0, *)
struct CoachFormattedMessageText: View {
    let text: String
    let textColor: Color
    let accent: Color

    private var blocks: [CoachMessageTextFormatter.Block] {
        CoachMessageTextFormatter.blocks(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: CoachMessageTextFormatter.Block) -> some View {
        switch block {
        case .paragraph(let value):
            inlineText(value)
                .foregroundStyle(textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("•")
                    .font(Typography.figtree(size: 18, weight: .bold, relativeTo: .body))
                    .foregroundStyle(accent)
                    .frame(width: 12, alignment: .center)
                inlineText(value)
                    .foregroundStyle(textColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .numbered(let index, let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("\(index).")
                    .font(Typography.monoDigit(Typography.figtree(size: 17, weight: .bold, relativeTo: .body)))
                    .foregroundStyle(accent)
                    .frame(width: 22, alignment: .trailing)
                inlineText(value)
                    .foregroundStyle(textColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inlineText(_ raw: String) -> Text {
        CoachMessageTextFormatter.inlineSegments(from: raw).reduce(Text("")) { partial, segment in
            partial + Text(segment.text)
                .font(
                    segment.isStrong
                    ? Typography.figtree(size: 17, weight: .bold, relativeTo: .body)
                    : Typography.figtree(size: 17, weight: .medium, relativeTo: .body)
                )
        }
    }
}

// MARK: - Spoken-coach-mode pure logic (S5, routes since C5)
//
// The decision of WHETHER (and through WHICH engines) to speak a
// freshly-landed coach turn is isolated here as pure, view-free logic so it
// can be unit-tested without standing up the SwiftUI view, an audio engine,
// or a model. `AskNoumView.runReply` and the live call's `handleUtterance`
// call `spokenRoute(...)` at the single chokepoint where a reply becomes
// visible (`store.completeCoachTurn`), and only then drive
// `IMMessageSpeaker.shared.speak(...)`.
//
// The voice → tone mapping translates the user's CHOSEN `SpeakingStyleGoal`
// into the `IMTargetTone` the TTS layer reads for voice selection, so the
// coach's spoken register leans toward the voice the user is training. A nil
// chosen voice (the user hasn't picked) maps to a steady, neutral `.calm`
// coach voice — never an invented register.
@available(iOS 17.0, macOS 12.0, *)
enum AskNoumSpokenMode {

    /// How a landed coach turn reaches the user's ears, if at all.
    enum SpokenRoute: Equatable {
        /// Live `.reply`: full engine chain — cloud TTS first, on-device
        /// system voice as the terminal fallback so a TTS outage degrades
        /// to an audible reply instead of a silent bubble.
        case fullChain
        /// Stay silent (toggle off, unsupported locale, failure, empty).
        case none
    }

    /// The single source of truth for "how should this landed outcome be
    /// spoken?".
    ///
    /// Non-`.none` ONLY when ALL hold:
    ///   • the voice-mode toggle is ON (`spokenRepliesEnabled`),
    ///   • the active locale supports AI (`localeSupportsAI`) — non-English
    ///     users stay clean text-only, matching the chat-reply locale gate,
    ///   • the outcome carries non-empty spoken coach text after sanitizer
    ///     removes UI-only formatting and scaffold labels.
    ///
    /// A `.failure` (any cause) is NEVER spoken — it renders as a system notice
    /// in the store, not the coach's voice. An all-whitespace reply is also
    /// rejected (defensive; the store routes that to `.failure(.empty)` anyway,
    /// but the predicate must not depend on that downstream behavior).
    static func spokenRoute(
        outcome: ChatOutcome,
        spokenRepliesEnabled: Bool,
        localeSupportsAI: Bool
    ) -> SpokenRoute {
        guard spokenRepliesEnabled, localeSupportsAI else { return .none }
        switch outcome {
        case .reply(let text):
            return CoachReplyTextSanitizer.spokenText(from: text).isEmpty ? .none : .fullChain
        case .failure:
            return .none
        }
    }

    /// The coach text a non-`.none` route speaks. Nil for `.failure` and empty
    /// outcomes — total, so callers can `if let` without re-deriving the
    /// route's preconditions.
    static func spokenText(for outcome: ChatOutcome) -> String? {
        switch outcome {
        case .reply(let text):
            let trimmed = CoachReplyTextSanitizer.spokenText(from: text)
            return trimmed.isEmpty ? nil : trimmed
        case .failure:
            return nil
        }
    }

    /// Map the user's chosen training voice to the spoken coach tone. Pure +
    /// total so it is trivially testable and never crashes on a new case.
    static func coachTone(for voice: SpeakingStyleGoal?) -> IMTargetTone {
        switch voice {
        case .authoritative: return .confident
        case .warm: return .warm
        case .concise: return .concise
        case .persuasive: return .assertive
        case .executive: return .professional
        case .storytelling: return .warm
        case nil: return .calm
        }
    }
}

// MARK: - Day-0 seeded coach presence (coach-parity eval move 2)
//
// Before the first completed rep the coach has a stated goal (the
// CoachingProfile from onboarding) but ZERO evidence. The old behavior
// locked the thread door until rep 1 — the coach couldn't be talked to
// exactly when a first-timer was deciding whether to trust the product.
// This opens the door with an honest seeded presence instead of a fake
// conversation:
//
//   • The greeting is a PURE deterministic template from enum-derived
//     profile fields — no LLM call, no fabricated read, and never a
//     verbatim quote of user-typed text (lock-screen-safety rule).
//   • The composer is replaced by a "run your first rep" CTA + a plain
//     one-line reason. Full coach replies stay gated on rep 1 because
//     a reply with zero reps would be a guess wearing a coach voice.
//
// Pure + view-free so the gate and the template are unit-testable.
@available(iOS 17.0, macOS 12.0, *)
enum AskNoumDayZeroGreeting {

    /// True before the user's FIRST completed rep — the window where the
    /// thread is seeded/read-only.
    static func isActive(sessionCount: Int) -> Bool {
        sessionCount < 1
    }

    /// Persisted chat can survive a profile or session reset. It becomes
    /// visible again only after this account has produced fresh evidence.
    static func canDisplayPersistedThread(sessionCount: Int) -> Bool {
        !isActive(sessionCount: sessionCount)
    }

    /// Deterministic seeded greeting. Acknowledges the stated challenge
    /// and/or chosen voice using enum-derived copy only, states plainly
    /// that there is no read yet (weak evidence → soft language), and
    /// invites ONE rep for a real read. Total — every input combination
    /// returns a non-empty, non-overclaiming line.
    static func greeting(
        challenge: SpeakingChallenge?,
        voice: SpeakingStyleGoal?
    ) -> String {
        let evidenceInvite = "No read yet. One short rep gives me evidence; then I can name the first focus worth training."
        let acknowledgement: String?
        switch (challenge, voice) {
        case let (challenge?, voice?):
            acknowledgement = "You want to work on \(challenge.trainingFocusFragment) and to \(voice.coachingDescription)."
        case let (challenge?, nil):
            acknowledgement = "You want to work on \(challenge.trainingFocusFragment)."
        case let (nil, voice?):
            acknowledgement = "You want to \(voice.coachingDescription)."
        case (nil, nil):
            acknowledgement = nil
        }
        guard let acknowledgement else { return evidenceInvite }
        return acknowledgement + " " + evidenceInvite
    }

    /// Headline over the seeded greeting card.
    static let headline = "Before rep one"

    /// Title for the first-rep CTA that stands in for the composer.
    static let firstRepCTATitle = "Start first rep"

    /// One-line honest reason the composer is not there yet. Plain
    /// statement, no countdown, no shame.
    static let inputLockedNote = "The thread opens after one rep, so the coaching starts from evidence."
}

@available(iOS 17.0, macOS 12.0, *)
struct AskNoumView: View {
    private static let speechLog = Logger(subsystem: "uk.co.otherpath.noum", category: "AskNoumSpeech")

    @StateObject private var store = AskNoumStore.shared
    @StateObject private var authManager = AuthManager.shared
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore
    /// A3: lets a coach reply that names a concrete mode/exercise surface a
    /// tappable launch card that pushes the matching practice destination onto
    /// the shared stack (same routing Home/Summary use).
    @Binding var navigationPath: NavigationPath
    /// When set, the chat options menu can start the live coach call. Kept out
    /// of the visible header row so it reads as an action, not a false "live"
    /// status.
    var onGoLive: (() -> Void)? = nil
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var proofMomentStore = ProofMomentStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachCheckInStore = CoachCheckInStore.shared
    /// Established mode suggestions depend on account-scoped cloud consent.
    /// Observing the existing owner makes a consent change rebuild the visible
    /// launch projection before the user taps it.
    @StateObject private var aiSettings = AISettingsManager.shared

    @State private var draft: String = ""
    @State private var didLandFirstAppear = false
    @State private var liveCoachAvailability: CoachChatTransportAvailability = .checking
    @State private var isPreparingSend = false
    @FocusState private var inputFocused: Bool

    // S3 — the in-chat goal set/change intent detected on the most-recent user
    // turn (`CoachContextBuilder.detectGoalIntent`, set in `send(_:)`). Drives
    // the ephemeral `goalProposalRow` confirmation card and injects a GOAL
    // context line into the next reply so the coach PROPOSES rather than
    // assumes. Held as view state (not derived from the message log) so it
    // survives view rebuilds and is cleared on commit/decline — the card
    // collapses when this returns to nil. The model NEVER writes to the
    // profile; only a tap on this card's chip commits.
    @State private var pendingGoalIntent: CoachContextBuilder.GoalIntent?
    @State private var goalSaveError: String?
    /// The latest reply's authored move stays collapsed until requested so
    /// normal conversation remains calm rather than becoming a report card.
    @State private var expandedCoachDetailMessageID: UUID?

    // Transparent memory / trajectory — sheet presentation for "Your
    // trajectory", opened from the memory-usage pill under the latest coach
    // reply (and from the thread options menu for discoverability).
    @State private var showTrajectorySheet = false
    /// Failed availability re-checks this visit on reportable reasons
    /// (`AskNoumAvailabilityRecheckPolicy`); at the threshold the banner
    /// leads with a support report, with a quiet re-check kept alongside.
    /// Reset by the `liveCoachAvailability` observer whenever availability
    /// is restored by ANY path — appear task, auth event, banner re-check,
    /// or a successful reply — so a stale count never fast-tracks the next
    /// outage to "Report issue".
    @State private var availabilityRecheckFailures = 0

    // Living-coach-presence (Pillar A) — progressive reply reveal. The store
    // holds the full reply text (source of truth); the view reveals it word by
    // word so the coach reads as *writing to you* rather than the reply popping
    // in fully-formed. `revealingMessageID` marks the one coach row currently
    // animating; `revealedText` is its visible prefix. Both reset when the
    // reveal completes (the bubble falls back to the full `message.text`).
    // Fully gated on reduce-motion — when it's on, no reveal is armed and
    // replies land instantly. `revealTask` is cancelled on a new turn and on
    // disappear so a superseded reveal never mutates state for the wrong row.
    @State private var revealingMessageID: UUID? = nil
    @State private var revealedText: String = ""
    @State private var revealTask: Task<Void, Never>? = nil
    @State private var replyTask: Task<Void, Never>? = nil
    @State private var pendingReplyCoachID: UUID? = nil
    @State private var pendingReplyLease: AskNoumReplyLease? = nil

    // V4.6.1 — availability episode tracking for the banner's feedback
    // beats. `coachUnavailableEpisodeActive` is true from the moment the
    // coach becomes unavailable until a genuine restore: the warning haptic
    // fires only on the opening edge, so failed re-checks bouncing through
    // `.checking` back to `.unavailable` never re-buzz. A restore that ends
    // an episode shows the transient "Back online." confirmation, which
    // auto-fades via `restoredConfirmationTask` (cancelled on teardown and
    // whenever a fresh probe supersedes it).
    @State private var coachUnavailableEpisodeActive = false
    @State private var showsCoachRestoredConfirmation = false
    @State private var restoredConfirmationTask: Task<Void, Never>? = nil

    // Voice input wrapper — shipped in `AskNoumVoiceInput.swift`. Single
    // instance per view so the tap-to-toggle lifecycle owns the audio
    // engine + recognition task. Tap once → start recording; tap again
    // → stop and send. The view reads `state` + `unavailableReason` to
    // drive UI, and calls `toggle()` from the button action.
    @StateObject private var voiceInput = AskNoumVoiceInput()

    // S5 — spoken coach mode. `speaker` drives the "coach is speaking" state
    // (its `isSpeaking` is the real AVAudioPlayer lifecycle, never a timer) and
    // exposes `canSpeakReplies` so the toggle hides when no TTS provider is
    // configured. `voiceSettings` owns the persisted, default-OFF toggle
    // (`askNoumSpokenRepliesEnabled`) on the existing playback-settings owner —
    // no new store. Both are shared singletons, observed so the speaking-state
    // UI + toggle re-render on change.
    @StateObject private var speaker = IMMessageSpeaker.shared
    @StateObject private var voiceSettings = IMVoicePlaybackSettingsManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Foregrounding re-probes an unavailable coach (see the scenePhase
    /// observer) so a recovered backend never stays hidden behind the banner.
    @Environment(\.scenePhase) private var scenePhase
    /// "Report issue" opens the pre-filled support mail; the completion
    /// falls back to the hosted support page when no mail client handles
    /// `mailto:` — the tap must never silently no-op.
    @Environment(\.openURL) private var openURL

    init(
        sessionStore: PracticeSessionStore,
        ratingStore: RatingStore,
        coachingProfileStore: CoachingProfileStore,
        navigationPath: Binding<NavigationPath>,
        onGoLive: (() -> Void)? = nil,
        startsInTextMode: Bool = false
    ) {
        self.sessionStore = sessionStore
        self.ratingStore = ratingStore
        self.coachingProfileStore = coachingProfileStore
        self._navigationPath = navigationPath
        self.onGoLive = onGoLive
        _ = startsInTextMode
    }

    private var voice: SpeakingStyleGoal? {
        // The CHOSEN voice, not the always-populated effective default — so
        // the header/persona stay generic ("Your personal communications
        // coach.") until the user actually picks a voice, and the coach
        // offers to set one instead of inventing "authoritative."
        coachingProfileStore.profile?.chosenStyleGoal
    }

    /// True before the first completed rep — the seeded/read-only window.
    /// While active the empty state shows the deterministic day-0 greeting
    /// and the composer is replaced by a first-rep CTA (full replies stay
    /// gated on rep 1; see `AskNoumDayZeroGreeting`).
    private var isDayZero: Bool {
        AskNoumDayZeroGreeting.isActive(sessionCount: sessionStore.progressEligibleSessionCount)
    }

    private var canDisplayPersistedThread: Bool {
        AskNoumDayZeroGreeting.canDisplayPersistedThread(
            sessionCount: sessionStore.progressEligibleSessionCount
        )
    }

    /// Bounded, honest read of what's currently feeding personalization —
    /// built fresh from the same read-only stores the reply pipeline uses.
    /// See `TrajectorySummaryBuilder` for the no-overclaim contract.
    private var memoryTrajectorySnapshot: MemoryTrajectorySnapshot {
        TrajectorySummaryBuilder.build(
            profile: coachingProfileStore.profile,
            baseline: baselineStore.baseline,
            sessions: sessionStore.sessions,
            coachMemory: coachMemoryStore.currentMemory,
            now: Date()
        )
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                attachedContextCard
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            if isDayZero {
                                // Persisted messages can outlive a profile/session reset.
                                // Keep them quarantined until this account has fresh evidence.
                                dayZeroIntroCard
                            } else if store.messages.isEmpty {
                                // V4.6.1 — when the first message lands, the
                                // intro card compresses + fades away (driven
                                // by the `listChange` animation on the
                                // container below) so the conversation
                                // visibly takes the screen. Reduce Motion
                                // keeps the paired plain fade.
                                standardEmptyState
                                    .transition(reduceMotion
                                        ? .opacity
                                        : .scale(scale: 0.94, anchor: .top).combined(with: .opacity))
                            } else {
                                ForEach(store.messages) { message in
                                    messageRow(message: message)
                                        .id(message.id)
                                }
                                // ONE continuation surface per turn — the
                                // arbiter (`CoachContextBuilder.continuationSurface`)
                                // picks the single surface this reply earned:
                                // a pending decision (goal commit / hypothesis
                                // verdict / revised-read verdict) outranks the
                                // "Next move" panel, which itself collapses
                                // drill + follow-up chips into one primary
                                // action. Never two calls-to-action stacked
                                // under one coach reply.
                                switch activeContinuationSurface {
                                case .goalProposal:
                                    goalProposalRow
                                        .id("goalProposal")
                                case .hypothesisAcknowledgement:
                                    hypothesisAckRow
                                        .id("hypothesisAck")
                                case .revisedReadFollowUp:
                                    revisedReadFollowUpRow
                                        .id("revisedReadFollowUp")
                                case .nextMove:
                                    coachNextMovePanel(
                                        launch: suggestedModeLaunch,
                                        chips: followUpChips ?? []
                                    )
                                    .id("coachNextMove")
                                case nil:
                                    EmptyView()
                                }

                                // End chat — the deliberate session exit,
                                // at the BOTTOM of the thread (owner
                                // refinement on T2: "like end chat which
                                // takes you home, and shouldn't be at the
                                // top"). Same register as the live call's
                                // Leave and the verdict's bottom Done.
                                endChatRow
                            }
                            // Bottom spacer keeps the last message off
                            // the input bar so it's never visually cramped.
                            Color.clear.frame(height: Spacing.lg)
                                .id("bottom")
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                        // V4.6.1 — animates the empty-state → conversation
                        // handoff (and its reverse on a thread clear). Keyed
                        // to the emptiness flip only, so ordinary message
                        // appends never re-trigger a container animation.
                        .animation(
                            reduceMotion ? .v46ReduceMotionFade : .listChange,
                            value: store.messages.isEmpty
                        )
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: store.isAwaitingReply) { _, awaiting in
                        scrollToBottom(proxy: proxy)
                        if awaiting {
                            // A reply just went in-flight. Pre-arm the reveal on
                            // the pending coach row NOW (on main) so the instant
                            // it lands it renders an empty prefix and writes out
                            // — never a one-frame flash of the full text. Cancel
                            // any superseded reveal first. Skipped under
                            // reduce-motion (no reveal is ever armed).
                            revealTask?.cancel()
                            if !reduceMotion,
                               let pendingID = store.messages.last(where: { $0.role == .coach })?.id {
                                revealingMessageID = pendingID
                                revealedText = ""
                            } else {
                                revealingMessageID = nil
                                revealedText = ""
                            }
                        } else {
                            // The reply hydrated — fire the AI chip request for
                            // the freshly landed coach message (idempotent;
                            // cache-deduped).
                            if canDisplayPersistedThread, let coachID = latestLandedCoachID {
                                requestAIChipsIfNeeded(for: coachID)
                            }
                            // Reveal the landed reply word by word. Normally the
                            // row was pre-armed above; the cross-surface inject
                            // path (Summary bridge) sets isAwaitingReply before
                            // this view observes it, so fall back to the latest
                            // landed coach id. Only reveal a REAL coach bubble —
                            // a `.failure` becomes a systemNotice, so don't
                            // re-reveal an older message.
                            let revealID = revealingMessageID ?? latestLandedCoachID
                            if !reduceMotion,
                               let id = revealID,
                               let landed = store.messages.first(where: { $0.id == id }),
                               landed.role == .coach, !landed.isPending, !landed.text.isEmpty {
                                startReveal(of: landed, proxy: proxy)
                            } else {
                                // V4.6.1 — reply-landed ack for Reduce Motion
                                // users: the word reveal never runs under RM,
                                // so this observer is their only landing
                                // moment. Guarded to THIS turn's reply — a
                                // just-landed reply is the thread's LAST row;
                                // a failure resolves the pending row to a
                                // system notice and a cancel removes it, so
                                // neither (nor any older reply) can fire it.
                                // Suppressed while the mic records. The
                                // motion path fires the same ack at reveal
                                // completion instead — exactly one of the
                                // two ever runs per reply.
                                if reduceMotion,
                                   let landed = store.messages.last,
                                   landed.role == .coach, !landed.isPending, !landed.text.isEmpty,
                                   voiceInput.state != .recording {
                                    CoachHaptic.selectionTap()
                                }
                                revealingMessageID = nil
                                revealedText = ""
                            }
                        }
                    }
                    .onAppear {
                        if !didLandFirstAppear {
                            didLandFirstAppear = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                scrollToBottom(proxy: proxy)
                            }
                            // If the thread was rehydrated from disk with
                            // a landed coach reply at the tail, request
                            // AI chips for it once — same behavior as a
                            // fresh reply that just hydrated.
                            if let coachID = latestLandedCoachID {
                                requestAIChipsIfNeeded(for: coachID)
                            }
                        }
                    }
                }
                if isDayZero {
                    // Day-0: the composer is honestly absent, not greyed.
                    // One CTA toward the rep that earns the first real
                    // reply, with the reason in plain words above it.
                    dayZeroFooter
                } else {
                    inputArea
                }
            }
        }
        .navigationTitle("Ask Noum")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                threadOptionsMenu
            }
        }
        .sheet(isPresented: $showTrajectorySheet) {
            TrajectoryView(snapshot: memoryTrajectorySnapshot)
        }
        // T2 (owner refinement): the deliberate exit is the bottom-of-thread
        // "End chat" row (`endChatRow`), not a top-bar control — "shouldn't
        // be at the top." The standard back chevron stays for plain
        // navigation; End chat is the session-ending action that returns
        // straight Home.
        .onAppear {
            // T3 — owner: "clicking stop on voice dictation auto-inserts the
            // message into chat to upload again; it should auto-send on stop."
            // The final transcript now dispatches the user turn directly
            // through the single `send(_:)` funnel (same path as typed text,
            // chips, and the live call's `handleUtterance`) so stopping
            // dictation immediately runs the reply pipeline — no second tap on
            // the composer. `send(_:)` keeps the day-0 gate, goal-intent
            // detection, and barge-in stop, so auto-send inherits every
            // invariant the explicit path had.
            voiceInput.onFinalTranscript = { transcript in
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                inputFocused = false
                send(
                    trimmed,
                    clearDraftWhenSent: true
                )
            }
            // Pick up any cross-surface inject (e.g. Summary's "Talk to
            // your coach about this rep" bridge dropped a seed message
            // into the store right before pushing us onto the nav
            // stack). The store hands back the matching coachID once
            // and clears its own signal — so re-mounts of this view
            // won't fire a second reply for the same opener.
            if let coachID = store.consumePendingInjectedCoachID(),
               let replyLease = store.replyLease(for: coachID) {
                replyTask?.cancel()
                pendingReplyCoachID = coachID
                pendingReplyLease = replyLease
                replyTask = Task {
                    await runInjectedReply(
                        coachID: coachID,
                        expected: replyLease
                    )
                }
            }
        }
        .task {
            await refreshAvailability()
        }
        .onChange(
            of: authManager.localGuestCloudConnectionState
        ) { _, state in
            switch state {
            case .connecting:
                liveCoachAvailability = .checking
            case .finalizing, .connected, .failed:
                Task { @MainActor in
                    await refreshAvailability()
                }
            case .idle:
                break
            }
        }
        .onChange(
            of: authManager.initialAccountHydrationState
        ) { _, state in
            guard state == .ready else { return }
            Task { @MainActor in
                await refreshAvailability()
            }
        }
        // Availability restored by ANY path — the appear task, an auth
        // event, a banner re-check, or a successful reply — clears the
        // failed-re-check count, so a stale count never fast-tracks the
        // next outage straight to "Report issue".
        .onChange(of: liveCoachAvailability) { _, availability in
            if availability == .available {
                availabilityRecheckFailures = 0
            }
            // V4.6.1 — availability feedback beats, once per EPISODE:
            // the soft warning double-tick fires only on the edge INTO
            // `.unavailable` (never on `.checking`, never again while
            // failed re-checks bounce through `.checking` and back). A
            // restore that closes an episode shows the transient
            // "Back online." row — visual confirmation only, no haptic
            // on good news the banner is already announcing.
            switch availability {
            case .unavailable:
                if !coachUnavailableEpisodeActive {
                    coachUnavailableEpisodeActive = true
                    CoachHaptic.unavailableNotice()
                }
            case .available:
                if coachUnavailableEpisodeActive {
                    coachUnavailableEpisodeActive = false
                    presentRestoredConfirmation()
                }
            case .checking:
                // A fresh probe (send/retry) supersedes any lingering
                // restore confirmation — the row must reflect the probe,
                // not stale good news.
                if showsCoachRestoredConfirmation {
                    restoredConfirmationTask?.cancel()
                    showsCoachRestoredConfirmation = false
                }
            }
        }
        // Returning to the app re-probes an unavailable coach so a
        // recovered backend never stays invisible behind the banner.
        // Guarded to the unavailable state — a healthy composer shouldn't
        // flash "Connecting…" on every foreground.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  case .unavailable = liveCoachAvailability else { return }
            Task { @MainActor in
                await refreshAvailability()
            }
        }
        .onDisappear {
            // S5 — barge-in/teardown: never let the coach's voice bleed across
            // a navigation pop. Mirrors `SuddenDeathPracticeView.stopPromptReadout`
            // calling `IMMessageSpeaker.shared.stop()` on `.onDisappear`. Cheap
            // no-op when nothing is playing.
            speaker.stop()
            // Backing out mid-dictation must release the mic. Without this the
            // AVAudioEngine keeps running, the cloud (Deepgram) websocket keeps
            // streaming (billable), the audio session stays held in
            // playAndRecord+duckOthers, and InteractionSoundEngine.recordingActive
            // stays true — every tap/selection sound app-wide silenced until the
            // 30s max-duration timer finally fires. Cheap no-op when idle.
            voiceInput.cancelRecording()
            // Never let a half-written reveal mutate state after we've left.
            revealTask?.cancel()
            replyTask?.cancel()
            // The transient "Back online." confirmation joins the same
            // teardown — its auto-fade task must never write state after
            // a pop, and a re-push starts from the quiet resting bar.
            restoredConfirmationTask?.cancel()
            showsCoachRestoredConfirmation = false
            if let pendingReplyCoachID, let pendingReplyLease {
                _ = store.cancelPendingCoachTurn(
                    id: pendingReplyCoachID,
                    expected: pendingReplyLease
                )
                self.pendingReplyCoachID = nil
                self.pendingReplyLease = nil
            }
        }
    }

    // MARK: - Attached context

    /// Glanceable, inspectable context receipt from the same stores the reply
    /// pipeline already uses. It replaces the ambiguous one-line focus pill:
    /// the user can now see the bounded categories in play and reach the
    /// existing trajectory/privacy owners without opening a blank chat path.
    @ViewBuilder
    private var attachedContextCard: some View {
        // One quiet line, not a briefing card: the user needs to KNOW the
        // coach reads their context and be able to manage it — the detail
        // itself lives behind Manage (goals/evidence sheet). Full wording
        // is preserved for VoiceOver. The visible line comes from the same
        // presentation the VoiceOver label uses, so it never claims a focus
        // that didn't resolve or evidence that isn't attached.
        if canDisplayPersistedThread {
            let presentation = attachedContextPresentation
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // AX sizes: one capsule line truncates — stack the
                    // summary above Manage and let it wrap without a cap.
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        attachedContextSummaryLine(presentation, lineLimit: nil)
                        attachedContextManagementMenu
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.innerSurface,
                        in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .stroke(AppColor.pro.opacity(0.14), lineWidth: 1)
                    )
                } else {
                    HStack(alignment: .center, spacing: Spacing.xs) {
                        attachedContextSummaryLine(presentation, lineLimit: 1)

                        Spacer(minLength: Spacing.xs)

                        attachedContextManagementMenu
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 6)
                    .frame(minHeight: 40)
                    .background(AppColor.innerSurface, in: Capsule())
                    .overlay(Capsule().stroke(AppColor.pro.opacity(0.14), lineWidth: 1))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xs)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Attached coaching context. \(presentation.headline). \(presentation.categoryLine). \(AskNoumAttachedContextPresentation.privacyExplanation)")
            .accessibilityIdentifier("askNoum.attachedContext")
        }
    }

    private func attachedContextSummaryLine(
        _ presentation: AskNoumAttachedContextPresentation,
        lineLimit: Int?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: "paperclip")
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.pro)
                .accessibilityHidden(true)

            Text(presentation.summaryLine)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("askNoum.attachedContext.summary")
        }
    }

    private var attachedContextManagementMenu: some View {
        Menu {
            Button {
                showTrajectorySheet = true
            } label: {
                Label("Review goals and evidence", systemImage: "list.bullet.rectangle")
            }

            Button {
                navigationPath.append(AppDestination.settings)
            } label: {
                Label("Cloud processing settings", systemImage: "lock.shield")
            }
        } label: {
            Text("Manage")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .padding(.horizontal, Spacing.sm)
                .frame(minWidth: 72, minHeight: 44)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .accessibilityLabel("Manage attached coaching context")
        .accessibilityHint("Review goals and evidence, or open cloud processing settings.")
        .accessibilityIdentifier("askNoum.attachedContext.manage")
    }

    private var attachedContextPresentation: AskNoumAttachedContextPresentation {
        let eligibleSessions = PracticeProgressEligibility.eligibleSessions(in: sessionStore.sessions)
        let latestTimedPractice = eligibleSessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        let focus = Self.currentFocusValue(caseFile: coachMemoryStore.currentMemory?.caseFile)
            ?? coachMemoryStore.currentMemory?.currentLever?.displayName
        let compatibleProofCount = proofMomentStore.recent(
            limit: AskNoumAttachedContextPresentation.maximumVerifiedQuotes,
            compatibleWith: voice
        ).count

        return AskNoumAttachedContextPresentation.make(
            latestTimedPracticeLabel: latestTimedPractice?.mode.displayLabel,
            hasLatestTimedTranscript: latestTimedPractice?.transcript
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false,
            hasRecentPractice: !eligibleSessions.isEmpty,
            verifiedQuoteCount: compatibleProofCount,
            currentFocus: focus,
            hasSavedGoal: coachingProfileStore.profile != nil,
            conversationMessageCount: store.replayForModel.count
        )
    }

    // MARK: - Thread options
    //
    // One compact menu owns secondary chat actions. This keeps the coach header
    // focused on presence ("Noum") instead of exposing implementation toggles:
    // live-call launch, spoken-reply preference, and clear-thread all live here.
    @ViewBuilder
    private var threadOptionsMenu: some View {
        if shouldShowThreadOptions {
            Menu {
                if let onGoLive {
                    Button(action: onGoLive) {
                        Label("Start coach call", systemImage: "phone.waveform")
                    }
                }
                if speaker.canSpeakReplies {
                    Button {
                        toggleSpokenReplies()
                    } label: {
                        Label(
                            voiceSettings.askNoumSpokenRepliesEnabled
                            ? "Spoken replies on"
                            : "Spoken replies off",
                            systemImage: voiceSettings.askNoumSpokenRepliesEnabled
                            ? "speaker.wave.2.fill"
                            : "speaker.slash.fill"
                        )
                    }
                }
                Button {
                    showTrajectorySheet = true
                } label: {
                    Label("Manage attached context", systemImage: "brain")
                }
                .accessibilityHint("Reviews the goals, recent reps, and trends Noum can use for coaching.")
                .accessibilityIdentifier("askNoum.trajectoryMenuItem")

                if !store.messages.isEmpty {
                    Button(role: .destructive) {
                        store.clearThread()
                        // Drop any un-acted goal proposal so a wiped thread
                        // doesn't carry a stale intent into the next turn.
                        pendingGoalIntent = nil
                        goalSaveError = nil
                    } label: {
                        Label("Clear thread", systemImage: "trash")
                    }
                    // A destructive action whose scope is genuinely ambiguous:
                    // the label doesn't say whether practice history goes too.
                    // It doesn't — say so before the tap.
                    .accessibilityHint("Removes this conversation. Your practice history stays.")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Chat options")
            .accessibilityIdentifier("askNoum.threadOptions")
        }
    }

    private var shouldShowThreadOptions: Bool {
        // A pre-rep account has no current thread evidence. Keep any restored
        // history quarantined until a fresh rep re-opens the coaching thread.
        canDisplayPersistedThread
    }

    private func toggleSpokenReplies() {
        CoachHaptic.selectionTap()
        let newValue = !voiceSettings.askNoumSpokenRepliesEnabled
        voiceSettings.askNoumSpokenRepliesEnabled = newValue
        // Turning voice OFF should silence any reply still playing — the user
        // just asked for text-only; honor it immediately.
        if !newValue {
            speaker.stop()
        }
    }

    private var activeCaseSubtitle: String? {
        Self.currentFocusLine(caseFile: coachMemoryStore.currentMemory?.caseFile)
    }

    static func currentFocusLine(caseFile: CoachCaseFile?) -> String? {
        guard let caseFile, let value = currentFocusValue(caseFile: caseFile) else { return nil }
        let target = caseFile.observableTarget?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if target?.isEmpty == false || caseFile.focus != nil {
            return "Current focus: \(value)"
        }
        return "Current practice: \(value)"
    }

    static func currentFocusValue(caseFile: CoachCaseFile?) -> String? {
        guard let caseFile else { return nil }
        if let target = caseFile.observableTarget?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !target.isEmpty {
            return Self.shortCaseLine(CoachDisplayCopy.normalized(target), maxLength: 64)
        }
        if let focus = caseFile.focus {
            return focus.displayName
        }
        if let intervention = caseFile.activeIntervention?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !intervention.isEmpty {
            return Self.shortCaseLine(CoachDisplayCopy.normalized(intervention), maxLength: 64)
        }
        return nil
    }

    static func shortCaseLine(_ raw: String, maxLength: Int = 58) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let prefix = trimmed.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "\u{2026}"
        }
        return String(prefix) + "\u{2026}"
    }

    // MARK: - Empty state (starter prompts)

    /// Day-0 seeded greeting card. Same chrome as the standard empty
    /// state so the surface reads as the same coach, one day earlier.
    /// Copy is the pure `AskNoumDayZeroGreeting` template — enum-derived
    /// acknowledgement of the stated goal/challenge plus the one-rep
    /// invite. The matching CTA lives in `dayZeroFooter`, where the
    /// composer would otherwise be.
    private var dayZeroIntroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            NoumSemanticGraphic(
                role: .coachRead,
                tint: AppColor.coachAccent,
                size: NoumControlMetric.minimumTouchTarget
            )
            .accessibilityHidden(true)

            Text(AskNoumDayZeroGreeting.headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Text(AskNoumDayZeroGreeting.greeting(
                challenge: coachingProfileStore.profile?.biggestChallenge,
                voice: voice
            ))
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.pro.opacity(0.06), AppColor.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("askNoum.dayZeroIntro")
    }

    private var standardEmptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NoumSemanticGraphic(
                role: .coachRead,
                tint: AppColor.coachAccent,
                size: NoumControlMetric.minimumTouchTarget
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(emptyStateHeadline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(emptyStateBody)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            standingPlanLandingStrip

            caseReviewStarterChip

            starterPrimaryAction
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.pro.opacity(0.06), AppColor.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.20), lineWidth: 1)
        )
        // Fire the AI starter generation once per input signature while the
        // empty state is on screen. Opening suggestions are AI-only: until a
        // provider returns a clean tailored set, the composer remains the
        // honest affordance instead of surfacing canned coach copy.
        .task(id: starterSignature) {
            await requestAIStartersIfNeeded()
        }
    }

    // MARK: - Day-0 footer (stands in for the composer)

    /// Replaces the input bar before rep 1. A plain one-line reason +
    /// ONE CTA that routes into the same recommended first rep the Home
    /// hero's Begin button starts — not a dead/disabled composer.
    private var dayZeroFooter: some View {
        VStack(spacing: Spacing.sm) {
            Text(AskNoumDayZeroGreeting.inputLockedNote)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryCTA(AskNoumDayZeroGreeting.firstRepCTATitle, icon: "play.fill", tint: AppColor.pro) {
                beginFirstRep()
            }
            // "Start first rep" doesn't say the tap leaves the chat for a
            // practice screen, or that the rep is the coach's recommendation
            // rather than a picker.
            .accessibilityHint("Leaves the chat and opens the practice rep your coach recommends.")
            .accessibilityIdentifier("askNoum.dayZeroBegin")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("askNoum.dayZeroFooter")
    }

    /// Route into the recommended first rep — the same blueprint +
    /// router pair `HomeCoachCard.beginRecommendedRep` uses, so the
    /// coach's "run one rep" invite lands in the exact rep the Home
    /// hero would start. No new routing logic.
    private func beginFirstRep() {
        CoachHaptic.selectionTap()
        let availability = NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: IMModeAvailability.isAvailable
        )
        let blueprint = availability.resolving(RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: streakFreezeManager.currentStreak,
            daysSinceLastSession: 0,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            summaryStyle: .compact
        ).blueprint)
        navigationPath.append(
            SummaryLookingAheadRouter.destination(
                for: blueprint,
                imAvailable: IMModeAvailability.isAvailable,
                modeAvailability: availability
            )
        )
    }

    private var emptyStateHeadline: String {
        if activeCaseSubtitle != nil {
            // Not "current focus" — that word is reserved for the strip and
            // pill on the same screen so it lands at most twice per screen.
            return "Start with what you're working on."
        }
        if let voice = voice {
            return Self.voiceEmptyStateHeadline(for: voice)
        }
        return "Start with a coaching read."
    }

    /// Grammatical per-voice opener. Most voice TITLES are adjectival
    /// ("Warm and welcoming") and can't stand alone as a noun, so they take
    /// a "voice" suffix; "Executive presence" already ends in a noun and
    /// takes none. Static + exhaustive so a new voice case forces a
    /// deliberate reading here.
    static func voiceEmptyStateHeadline(for voice: SpeakingStyleGoal) -> String {
        switch voice {
        case .authoritative: return "Start with your authoritative voice."
        case .warm: return "Start with your warm and welcoming voice."
        case .concise: return "Start with your concise and sharp voice."
        case .persuasive: return "Start with your persuasive voice."
        case .executive: return "Start with your executive presence."
        case .storytelling: return "Start with your storytelling voice."
        }
    }

    // MARK: - Standing plan landing strip

    @ViewBuilder
    private var standingPlanLandingStrip: some View {
        if let line = Self.standingPlanLandingLine(caseFile: coachMemoryStore.currentMemory?.caseFile) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AppColor.pro.opacity(0.70))
                    .frame(width: 3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(AskNoumVisibleCopy.currentFocus)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.coachPlanText)
                    Text(line)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.coachPlanText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current coaching case: \(line)")
            .accessibilityIdentifier("askNoum.emptyState.standingPlan")
        }
    }

    static func standingPlanLandingLine(caseFile: CoachCaseFile?) -> String? {
        guard let raw = caseFile?.callLandingAnchor?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        let clean = CoachReplyTextSanitizer.liveLandingText(from: raw)
        guard !clean.isEmpty else { return nil }
        return shortCaseLine(clean, maxLength: 150)
    }

    // MARK: - Case-review starter chip
    //
    // Empty-state companion to `InterventionReviewPromptCard`. Renders
    // only when the active `CoachIntervention.isReviewDue(at:)`
    // predicate returns true — same eligibility gate the summary card
    // uses, so the two surfaces honour the same case-file cadence.
    //
    // Why a distinct visual register (calendar icon, brand-purple
    // tinted background, heavier stroke) rather than just another
    // entry in the starter-prompts catalog:
    //   • The chip is a coach priority signal, not a generic prompt.
    //     The user reads "your coach has a check-in queued" in one
    //     beat, not "here's another thing you could ask."
    //   • The display label is intentionally short (the
    //     `interventionReviewStarterHeadline` helper renders ~40 chars).
    //     The actual dispatched opener is the full `interventionReviewOpener`,
    //     same string the summary card sends — so the reply lands
    //     with mode + focus + followed-rep depth in scope and a
    //     voice-shaped review question already asked.
    //   • Voice continuity: tapping the chip from Ask Noum and tapping
    //     "Review with coach" from the summary produce the identical
    //     chat thread. No surface-specific phrasing drift.
    @ViewBuilder
    private var caseReviewStarterChip: some View {
        if let memory = coachMemoryStore.currentMemory,
           let intervention = memory.activeIntervention,
           intervention.isReviewDue(at: Date()) {
            Button {
                let opener = CoachDisplayCopy.normalized(
                    CoachContextBuilder.interventionReviewOpener(
                        intervention: intervention,
                        voice: voice,
                        reflectionPattern: memory.reflectionPattern
                    )
                )
                send(opener)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AskNoumVisibleCopy.coachCheckIn)
                            .font(Typography.captionSmall.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                        Text(CoachContextBuilder.interventionReviewStarterHeadline(for: intervention))
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.pro.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Review the active coaching case with Noum")
            .accessibilityHint("Opens the case-review conversation with the same context the post-rep card uses.")
            .accessibilityIdentifier("askNoum.emptyState.caseReviewChip")
        }
    }

    private var emptyStateBody: String {
        switch voice {
        case .authoritative:
            return "I'll keep it direct: one read, one reason, one move."
        case .warm:
            return "Bring the moment that felt awkward or important. We'll make the next attempt feel more like you."
        case .concise:
            return "Short question in, sharp coaching move out."
        case .persuasive:
            return "Tell me who you need to move. I'll work backwards to the line that carries weight."
        case .executive:
            return "Top-line first. We'll stay on the move that changes the room."
        case .storytelling:
            return "Give me the scene. I'll help you find the turn that makes it land."
        case .none:
            return "I read your practice history before replying, then keep the answer focused."
        }
    }

    @ViewBuilder
    private var starterPrimaryAction: some View {
        let layout = Self.coachOptionLayout(for: displayedStarters)
        if let primary = layout.primary {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    send(primary)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended ask")
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(primary)
                                .font(Typography.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Spacing.xs)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.cardBackground,
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recommended ask: \(primary)")

                if !layout.overflow.isEmpty {
                    starterMoreMenu(options: layout.overflow)
                }
            }
        }
    }

    private func starterMoreMenu(options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    send(option)
                }
            }
        } label: {
            Label("Other useful asks", systemImage: "ellipsis.circle")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.pro)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel("Other useful asks")
    }

    // MARK: - Follow-up chips
    //
    // Quiet "keep the thread alive" suggestions surfaced beneath the
    // most-recent coach reply. User-visible chips are AI-only. The
    // deterministic `followUpSuggestions(...)` path still acts as an
    // eligibility guard so generic replies do not sprout a chip tray just
    // because a model can invent one, but those deterministic strings are
    // never rendered as the coach.
    //
    // Visibility contract:
    //   • Latest message must be a coach reply.
    //   • Reply must NOT be pending (no chips for an in-flight bubble).
    //   • Reply must NOT be a system notice (no chips when the model
    //     failed — there's nothing useful to follow up on).
    //   • No reply in flight at all (`!isAwaitingReply`) — keeps the
    //     row from flickering as the user is mid-send.
    //
    // Returns `nil` when the chip row should collapse entirely. Returns
    // a `[String]` (possibly empty after detection) otherwise — the
    // view bails on empty arrays too via the `chips.isEmpty` guard at
    // the call site.
    private var followUpChips: [String]? {
        guard !store.isAwaitingReply,
              let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        let previousMessages = store.messages.dropLast()
        let previousCoachReply = previousMessages
            .last(where: { $0.role == .coach && !$0.isPending })?
            .text
        let lastUserTurn = previousMessages
            .last(where: { $0.role == .user })?
            .text
        let deterministic = CoachContextBuilder.followUpSuggestions(
            forCoachReply: last.text,
            previousCoachReply: previousCoachReply,
            lastUserTurn: lastUserTurn,
            voice: voice
        )
        return Self.aiGeneratedSuggestions(
            cached: store.aiChips(for: last.id),
            eligible: !deterministic.isEmpty
        )
    }

    /// A3: the single capability-resolved practice launch the LATEST coach
    /// reply points at, if any. Lifecycle is implicit + clean: it is computed
    /// from `store.messages.last` only, so it appears under the freshest coach
    /// reply that names a mode, is superseded the moment a new turn lands, and
    /// is dismissed by navigating away on tap. Nil while awaiting a reply, on
    /// a user turn, or when the reply names no mode (no card rather than a
    /// guess). Reading the published consent makes its availability dependency
    /// explicit to SwiftUI.
    private var suggestedModeLaunch: AskNoumModeSuggestion.LaunchProjection? {
        _ = aiSettings.cloudProcessingConsent
        guard !store.isAwaitingReply,
              let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        let imAvailable = IMModeAvailability.isAvailable
        return AskNoumModeSuggestion.launchProjection(
            in: last.text,
            modeAvailability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: imAvailable
            ),
            imAvailable: imAvailable
        )
    }

    /// The ONE continuation surface the current turn earned, resolved by the
    /// pure arbiter on `CoachContextBuilder` from each surface's own
    /// eligibility composite. The body renders only the returned case, so a
    /// pending decision (goal commit / hypothesis verdict / revised-read
    /// verdict) and the "Next move" panel can never stack under one reply.
    private var activeContinuationSurface: CoachContextBuilder.ChatContinuationSurface? {
        let layout = Self.coachOptionLayout(for: followUpChips ?? [])
        return CoachContextBuilder.continuationSurface(
            goalProposalEligible: shouldShowGoalProposal,
            hypothesisAckEligible: shouldShowHypothesisAck,
            revisedReadFollowUpEligible: shouldShowRevisedReadFollowUp,
            nextMoveAvailable: suggestedModeLaunch != nil || layout.primary != nil
        )
    }

    /// Coach message ID of the most-recent landed reply, if any. Drives
    /// the AI chip request — when this flips to a new ID we kick off a
    /// generation request for that reply (the previous reply's chips
    /// stay cached and don't need to re-roll).
    private var latestLandedCoachID: UUID? {
        guard let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        return last.id
    }

    /// Fire an AI chip generation request for the given coach reply if
    /// one hasn't already been cached. Idempotent — re-entry with a
    /// cached ID is a no-op, so the on-change hook can safely fire
    /// every time the messages array mutates.
    private func requestAIChipsIfNeeded(for coachID: UUID) {
        // Skip if we already have chips for this reply — view rebuilds
        // must not re-roll generation.
        if store.aiChips(for: coachID) != nil { return }
        guard let sendAdmission = store.sendAdmission() else { return }
        // Find the coach reply + the user turn that preceded it. The
        // generation request needs both for context-tailoring.
        guard let coachIdx = store.messages.firstIndex(where: { $0.id == coachID }) else { return }
        let coachReply = store.messages[coachIdx].text
        let lastUserTurn = store.messages
            .prefix(coachIdx)
            .last(where: { $0.role == .user })?
            .text ?? ""
        guard !lastUserTurn.isEmpty else { return }
        let previousCoachReply = store.messages
            .prefix(coachIdx)
            .last(where: { $0.role == .coach && !$0.isPending })?
            .text
        let deterministic = CoachContextBuilder.followUpSuggestions(
            forCoachReply: coachReply,
            previousCoachReply: previousCoachReply,
            lastUserTurn: lastUserTurn,
            voice: voice
        )
        guard !deterministic.isEmpty else { return }
        let voiceCapture = voice
        // Privacy-bounded summary of the user's recent reps (score / theme
        // / declared-intent / coach headline — NEVER raw transcript). Gives
        // the follow-up chips a real anchor ("ask about my last rep")
        // instead of pure conversational follow-up. Nil when there's no
        // usable history → the chip path falls through to today's behavior.
        let digestCapture = CoachContextBuilder.recentSessionDigestForChips(
            sessions: sessionStore.sessions,
            baseline: baselineStore.baseline
        )
        guard let providerLease = store.auxiliaryProviderLease(
            expected: sendAdmission
        ) else { return }
        let providerTask = Task { @MainActor in
            defer {
                store.unregisterAuxiliaryProviderWork(expected: providerLease)
            }
            guard store.auxiliaryProviderWorkIsCurrent(providerLease),
                  !Task.isCancelled else {
                return
            }
            let generated = await CoachContextBuilder.generateAIFollowUpChips(
                lastUserTurn: lastUserTurn,
                lastCoachReply: coachReply,
                voice: voiceCapture,
                recentSessionDigest: digestCapture,
                performRequest: { request in
                    try await store.performAuxiliaryProviderRequest(
                        request,
                        expected: providerLease
                    )
                }
            )
            // Cache only on success — nil means no chip row. Deterministic
            // suggestions stay eligibility-only and are not user-visible.
            if let chips = generated, !chips.isEmpty {
                _ = store.setAIChips(
                    chips,
                    for: coachID,
                    expected: sendAdmission
                )
            }
        }
        guard store.registerAuxiliaryProviderWorkCancellation(
            expected: providerLease,
            cancel: { providerTask.cancel() }
        ) else {
            providerTask.cancel()
            return
        }
    }

    // MARK: - Empty-state starter prompts (AI-only)
    //
    // Opening prompts are useful only when they feel like the coach has read
    // the user's actual state. The old deterministic catalog still exists as
    // a pure context/safety primitive, but this view no longer renders it as
    // a "Recommended ask." If the AI path has not produced clean prompts, the
    // empty state simply leaves the user with the composer and case-review
    // affordances.

    /// Slow-changing rotation seed (day-of-year): the starter trio re-rolls
    /// daily instead of being identical on every open (owner feedback
    /// 2026-06-10), while staying stable within a session.
    private var starterRotation: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    /// Stable signature of the inputs that shape the starters. A change to
    /// the chosen voice, the active upcoming moment, or the weakest
    /// dimension re-rolls the AI starters; idle re-renders reuse the cache.
    private var starterSignature: String {
        let voicePart = voice?.rawValue ?? "none"
        let momentPart = bigMomentStore.activeMoment.map { moment -> String in
            let days = BigMomentStore.daysUntil(moment).map(String.init) ?? "x"
            return "\(moment.category.rawValue)#\(days)"
        } ?? "nomoment"
        let weakPart = PracticeTopics.weakestDimensionLabel(for: baselineStore.baseline) ?? "noweak"
        let checkInPart = weeklyCheckInDueForChat ? "checkinDue" : "checkinQuiet"
        let hasMotivation = {
            guard let profile = coachingProfileStore.profile else { return false }
            return !profile.whyNowReference.isEmpty || !profile.successVisionReference.isEmpty
        }()
        let motivationPart = hasMotivation ? "motivation" : "nomotivation"
        // Day-bucket component: the AI-tailored starters re-roll daily too,
        // not only when voice/moment/weakness change.
        return "\(voicePart)|\(momentPart)|\(weakPart)|\(checkInPart)|\(motivationPart)|r\(starterRotation)"
    }

    private var weeklyCheckInDueForChat: Bool {
        sessionStore.progressEligibleSessionCount > 0 && coachCheckInStore.isCheckInDue()
    }

    /// Starters shown in the empty state. AI-generated or hidden; never a
    /// deterministic coach-like fallback.
    private var displayedStarters: [String] {
        Self.aiGeneratedSuggestions(cached: store.starterChips(for: starterSignature), eligible: true)
    }

    /// Fire an AI starter generation request for the current signature if
    /// one hasn't already been cached. Idempotent — re-entry with a cached
    /// signature is a no-op, so the `.task(id:)` hook can safely re-fire.
    private func requestAIStartersIfNeeded() async {
        let signature = starterSignature
        // Skip if we already have starters for this signature.
        if store.starterChips(for: signature) != nil { return }
        guard let sendAdmission = store.sendAdmission() else { return }
        let voiceCapture = voice
        let momentCapture = bigMomentStore.activeMoment
        let baselineCapture = baselineStore.baseline
        let profileCapture = coachingProfileStore.profile
        let weeklyCheckInDueCapture = weeklyCheckInDueForChat
        // Same privacy-bounded recent-rep digest as the follow-up chips.
        let digestCapture = CoachContextBuilder.recentSessionDigestForChips(
            sessions: sessionStore.sessions,
            baseline: baselineCapture
        )
        guard let providerLease = store.auxiliaryProviderLease(
            expected: sendAdmission
        ) else { return }
        let providerTask = Task { @MainActor in
            defer {
                store.unregisterAuxiliaryProviderWork(expected: providerLease)
            }
            guard store.auxiliaryProviderWorkIsCurrent(providerLease),
                  !Task.isCancelled else {
                return nil as [String]?
            }
            return await CoachContextBuilder.generateAIStarterPrompts(
                voice: voiceCapture,
                bigMoment: momentCapture,
                baseline: baselineCapture,
                profile: profileCapture,
                weeklyCheckInDue: weeklyCheckInDueCapture,
                recentSessionDigest: digestCapture,
                performRequest: { request in
                    try await store.performAuxiliaryProviderRequest(
                        request,
                        expected: providerLease
                    )
                }
            )
        }
        guard store.registerAuxiliaryProviderWorkCancellation(
            expected: providerLease,
            cancel: { providerTask.cancel() }
        ) else {
            providerTask.cancel()
            return
        }
        let generated = await withTaskCancellationHandler(
            operation: { await providerTask.value },
            onCancel: { providerTask.cancel() }
        )
        // Cache only on success — nil leaves no suggested ask. That is
        // quieter and more honest than showing canned coach copy.
        if let chips = generated, !chips.isEmpty {
            await MainActor.run {
                _ = store.setStarterChips(
                    chips,
                    for: signature,
                    expected: sendAdmission
                )
            }
        }
    }

    // MARK: - Hypothesis acknowledgement row (post-case-review reply)
    //
    // Renders below the coach's reply to an `interventionReviewOpener`
    // dispatch (from either the summary card or the empty-state chip).
    // Three one-tap chips — confirmed / uncertain / rejected — let the
    // user lodge their verdict on the working hypothesis without typing
    // a sentence. The tap:
    //   1. Persists the verdict to `CoachMemoryStore.shared` via
    //      `noteHypothesisAcknowledgement(_:)`. The ack lands in
    //      durable case-file storage immediately.
    //   2. Dispatches the chip's voice-shaped text as a user turn via
    //      the existing `send(_:)` path. This keeps the chat surface
    //      continuous — the chip reads as a real reply, the model gets
    //      a coherent conversation, and the next reply lands with the
    //      user's verdict reflected in the user-context block (the
    //      builder reads `memory.hypothesisAcknowledgement` and
    //      surfaces a coach-direction line).
    //
    // Eligibility (`shouldShowHypothesisAcknowledgement`):
    //   • Most-recent message is a non-pending coach reply.
    //   • The user turn that triggered it begins with
    //     `interventionReviewOpenerLead` ("Time to review the active
    //     case:" — pinned on `CoachContextBuilder`).
    //   • The current memory's `workingHypothesis` is non-empty
    //     (otherwise there's nothing for the user to acknowledge).
    //   • The user hasn't already acknowledged this hypothesis (the
    //     snapshot guard on `CoachHypothesisAcknowledgement.appliesTo`
    //     — a stale ack from a prior case read re-prompts).
    //
    // Vision alignment:
    //   • Coach-parity gap closure. Per `docs/VISION.md`, the case
    //     formulation needs an explicit "reason for changing course."
    //     The user's hypothesis verdict IS that reason — the next
    //     `CoachCourseChange` entry can reference whether the user
    //     confirmed or rejected the read.
    //   • Pillar #5 (Personalized coaching). A real coach asks "does
    //     that sound right?" after sharing a read; we owe the same
    //     structured back-channel.
    @ViewBuilder
    private var hypothesisAckRow: some View {
        if shouldShowHypothesisAck {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Does this read match?")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Does this coaching read match?")
                    // Names the chip group below it — a heading so the rotor
                    // lands on the question before the three verdict chips.
                    .accessibilityAddTraits(.isHeader)

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(hypothesisAckChips, id: \.confidence) { chip in
                        Button {
                            recordHypothesisAck(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ackChipGlyph(for: chip.confidence))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            // 44pt minimum: these chips are the only way to tell Noum a read is
                            // wrong, and they were ~29pt. Correcting a coach is not a minor action.
                            .frame(minHeight: 44)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Acknowledge: \(chip.label)")
                        .accessibilityIdentifier("askNoum.hypothesisAck.\(chip.confidence.rawValue)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the hypothesis-ack row. The predicate
    /// from `CoachContextBuilder` covers the chat-shape check; the
    /// store-level check ensures we don't render a row the user has
    /// already answered for the currently-carried hypothesis.
    private var shouldShowHypothesisAck: Bool {
        guard CoachContextBuilder.shouldShowHypothesisAcknowledgement(messages: store.messages) else { return false }
        guard let memory = coachMemoryStore.currentMemory,
              let hypothesis = memory.workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return false }
        // Suppress if the user has already acknowledged THIS hypothesis.
        // A drift to a different working hypothesis (memory rebuild) drops
        // the ack via `appliesTo`, which re-enables the row.
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
            return false
        }
        return true
    }

    private var hypothesisAckChips: [CoachContextBuilder.HypothesisAcknowledgementChip] {
        CoachContextBuilder.hypothesisAcknowledgementChips(for: voice)
    }

    private func ackChipGlyph(for confidence: CoachHypothesisConfidence) -> String {
        switch confidence {
        case .confirmed: return "checkmark.circle"
        case .uncertain: return "questionmark.circle"
        case .rejected: return "arrow.triangle.2.circlepath"
        }
    }

    private func recordHypothesisAck(_ chip: CoachContextBuilder.HypothesisAcknowledgementChip) {
        // Persist the verdict first so it lands in case-file storage even
        // if the dispatched user turn fails to reach the model (no
        // provider, locale block). The durable record is the priority;
        // the chat continuation is the courtesy.
        coachMemoryStore.noteHypothesisAcknowledgement(chip.confidence)
        send(chip.dispatchText)
    }

    // MARK: - Revised-read follow-up row (post-rebuild reply)
    //
    // Renders below the coach's reply to a `revisedReadOpener` dispatch
    // (the round-29 seed routed by `SummaryView.talkToNoumOpener` when the
    // post-rep `RevisedReadCard` is showing). Three voice-shaped one-tap
    // chips — stick / add / push back — let the user land a verdict on
    // the rebuilt working hypothesis without typing a sentence. The tap
    // path mirrors the round-26 `hypothesisAckRow` exactly:
    //
    //   1. Persists the verdict to `CoachMemoryStore.shared` via
    //      `noteHypothesisAcknowledgement(_:)`. The ack is tagged to the
    //      NEW (rebuilt) working hypothesis snapshot — `appliesTo` will
    //      preserve it across re-renders until the next memory rebuild.
    //   2. Dispatches the chip's voice-shaped text as a user turn via the
    //      existing `send(_:)` path. The chat thread stays continuous —
    //      the chip reads as a real reply, the model gets a coherent
    //      conversation, the next coach reply lands with the user's
    //      verdict reflected in the user-context block (the builder reads
    //      `memory.hypothesisAcknowledgement`).
    //
    // Eligibility (`shouldShowRevisedReadFollowUp`):
    //   • Most-recent message is a non-pending coach reply.
    //   • The user turn that triggered it begins with `revisedReadOpenerLead`
    //     ("Picking up the case file — I flagged the prior read as off." —
    //     pinned on `CoachContextBuilder` since round 29).
    //   • The current memory's `workingHypothesis` is non-empty.
    //   • The user hasn't already lodged a verdict on this rebuild (same
    //     `CoachHypothesisAcknowledgement.appliesTo` snapshot guard as the
    //     round-26 row — a memory rebuild that rewrote the hypothesis again
    //     re-prompts).
    //
    // The two acknowledgement predicates (round-26 case-review and round-30
    // revised-read) are mutually exclusive at the chat-shape level: a single
    // user turn can only begin with one opener lead. The body additionally
    // routes ALL post-reply surfaces through the one-per-turn arbiter
    // (`activeContinuationSurface`), so no two continuation rows can ever
    // stack under a single coach reply.
    //
    // Vision alignment:
    //   • Coach-parity stage #4 (Adaptation). Per `docs/VISION.md`, the
    //     case formulation needs a "reason for changing course" AND a way
    //     to confirm a rebuild has landed before the next adaptation
    //     cycle fires. Round 29 closed the seed half (chat thread names
    //     the user's pushback); round 30 closes the verdict half (chat
    //     thread records whether the rebuild stuck, needs refining, or
    //     needs another adaptation).
    //   • Pillar #5 (Personalized coaching). A human coach who rebuilt
    //     their read at the user's pushback would not move on without
    //     asking "does this new read land?" — they'd want the user's
    //     verdict on the revised hypothesis, not just the original one.
    @ViewBuilder
    private var revisedReadFollowUpRow: some View {
        if shouldShowRevisedReadFollowUp {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Where does the new read land?")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Does the revised coaching read match?")
                    .accessibilityAddTraits(.isHeader)

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(revisedReadFollowUpChips, id: \.confidence) { chip in
                        Button {
                            recordHypothesisAck(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ackChipGlyph(for: chip.confidence))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            // 44pt minimum: these chips are the only way to tell Noum a read is
                            // wrong, and they were ~29pt. Correcting a coach is not a minor action.
                            .frame(minHeight: 44)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Land verdict: \(chip.label)")
                        .accessibilityIdentifier("askNoum.revisedReadFollowUp.\(chip.confidence.rawValue)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the revised-read follow-up row. The
    /// predicate from `CoachContextBuilder` covers the chat-shape check;
    /// the store-level check ensures we don't render a row the user has
    /// already answered for the currently-carried (rebuilt) hypothesis.
    /// Same composite shape as `shouldShowHypothesisAck`.
    private var shouldShowRevisedReadFollowUp: Bool {
        guard CoachContextBuilder.shouldShowRevisedReadFollowUp(messages: store.messages) else { return false }
        guard let memory = coachMemoryStore.currentMemory,
              let hypothesis = memory.workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return false }
        // Suppress if the user has already acknowledged THIS rebuilt
        // hypothesis. A subsequent memory rebuild (e.g. another `.rejected`
        // ack folded into a new course change) will rewrite the hypothesis
        // and drop the ack via `appliesTo`, which re-enables the row.
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
            return false
        }
        return true
    }

    private var revisedReadFollowUpChips: [CoachContextBuilder.HypothesisAcknowledgementChip] {
        CoachContextBuilder.revisedReadFollowUpChips(for: voice)
    }

    // MARK: - Goal proposal row (in-chat set / change confirmation card)
    //
    // S3 — the human-in-the-loop affordance that closes the dead-end where the
    // coach could only say "go to Settings." Renders below the coach's reply to
    // a detected set/change request (held on `pendingGoalIntent`). The card
    // states EXACTLY what will change and offers one-tap chips; ONLY a tap here
    // commits a profile write (`recordGoalSet` / `recordGoalChange`). The model
    // never writes — it only proposes in prose.
    //
    // Visual register is identical to `hypothesisAckRow` / `revisedReadFollowUpRow`
    // (left-inset header eyebrow + `FlowLayout` of `AppColor.pro` capsules,
    // `.buttonStyle(.pressable)`, per-chip accessibility) so it lands consistent
    // with the rest of the surface. A short intro line names the change so the
    // user reads what they're confirming before they tap.
    //
    // Eligibility (`shouldShowGoalProposal`): a pending intent exists AND the
    // most-recent message is a non-pending coach reply. Commit/decline clears
    // `pendingGoalIntent`, which collapses the card.
    @ViewBuilder
    private var goalProposalRow: some View {
        if shouldShowGoalProposal, let intent = pendingGoalIntent {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(goalProposalEyebrow(for: intent))
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Confirm a change to your training emphasis")
                    .accessibilityAddTraits(.isHeader)

                if let detail = goalProposalDetail(for: intent) {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let goalSaveError {
                    Text(goalSaveError)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("askNoum.goalProposal.saveError")
                }

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(goalProposalChips) { chip in
                        Button {
                            handleGoalProposalChip(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: goalChipGlyph(for: chip.action))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            // 44pt minimum: these chips are the only way to tell Noum a read is
                            // wrong, and they were ~29pt. Correcting a coach is not a minor action.
                            .frame(minHeight: 44)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(goalChipAccessibilityLabel(for: chip))
                        .accessibilityIdentifier("askNoum.goalProposal.\(chip.id)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the goal-proposal card. The pure predicate from
    /// `CoachContextBuilder` covers the chat-shape + intent-present check; this
    /// thin wrapper passes the view's `pendingGoalIntent` presence so the same
    /// store-driven gate the ack rows use applies here too.
    private var shouldShowGoalProposal: Bool {
        CoachContextBuilder.shouldShowGoalProposal(
            messages: store.messages,
            intentPresent: pendingGoalIntent != nil
        )
    }

    private var goalProposalChips: [CoachContextBuilder.GoalProposalChip] {
        guard let intent = pendingGoalIntent else { return [] }
        return CoachContextBuilder.goalProposalChips(intent: intent, currentVoice: voice)
    }

    /// Card eyebrow — names whether this is a cold-start set or a change.
    private func goalProposalEyebrow(for intent: CoachContextBuilder.GoalIntent) -> String {
        switch intent.kind {
        case .initialSet:
            return intent.requestedVoice == nil ? "Pick a training emphasis" : "Use this training emphasis?"
        case .change:
            return "Change training emphasis?"
        }
    }

    /// One-line detail under the eyebrow that states EXACTLY what the user is
    /// confirming. For a resolved target it surfaces the voice's coaching
    /// description (cold start) or the explicit old→new trade-off (change). For
    /// an unresolved "help me pick" it nudges the user to tap a voice. Returns
    /// nil only when there is genuinely nothing to add beyond the chips.
    private func goalProposalDetail(for intent: CoachContextBuilder.GoalIntent) -> String? {
        switch intent.kind {
        case .initialSet:
            if let target = intent.requestedVoice {
                return "\(target.title) will shape which skills Noum prioritises next. It changes the training plan, not who you are."
            }
            return "Pick the communication style you want to train toward. Your existing evidence and progress stay intact."
        case .change:
            let current = voice?.title ?? "your current emphasis"
            if let target = intent.requestedVoice {
                return "Shift future practice from \(current) toward \(target.title), blend both, or keep \(current). Your reps, evidence and progress remain."
            }
            return "Choose which communication style should guide the next plan. Your reps, evidence and progress remain."
        }
    }

    private func goalChipGlyph(for action: CoachContextBuilder.GoalProposalAction) -> String {
        switch action {
        case .set: return "checkmark.circle"
        case .switchTo: return "arrow.triangle.2.circlepath"
        case .blend: return "circle.grid.2x1"
        case .decline: return "xmark.circle"
        }
    }

    private func goalChipAccessibilityLabel(for chip: CoachContextBuilder.GoalProposalChip) -> String {
        switch chip.action {
        case .set(let v): return "Use \(v.title) as your training emphasis"
        case .switchTo(let v): return "Shift training emphasis to \(v.title)"
        case .blend(let v): return "Blend your current training emphasis with \(v.title)"
        case .decline: return chip.label
        }
    }

    /// Route a goal-proposal chip tap. The durable write happens FIRST (so the
    /// profile change lands even if the chat continuation fails — no provider,
    /// locale block), then the pending intent is cleared (collapsing the card),
    /// then the voice-shaped continuation is dispatched WITHOUT re-detection so
    /// it doesn't re-arm the card. Mirrors `recordHypothesisAck`'s
    /// durable-write-before-chat ordering. The LLM is never in this path —
    /// `CoachingProfileStore.save` is reached ONLY here, from the user's tap.
    private func handleGoalProposalChip(_ chip: CoachContextBuilder.GoalProposalChip) {
        let didCommit: Bool
        switch chip.action {
        case .set(let newVoice):
            didCommit = recordGoalSet(newVoice)
        case .switchTo(let newVoice):
            didCommit = recordGoalChange(to: newVoice, blend: false)
        case .blend(let newVoice):
            didCommit = recordGoalChange(to: newVoice, blend: true)
        case .decline:
            CoachHaptic.selectionTap()
            didCommit = true
        }
        guard didCommit else {
            goalSaveError = "That voice change didn’t save. Try it again."
            CoachHaptic.drillIncomplete()
            return
        }
        goalSaveError = nil
        switch chip.action {
        case .decline:
            break
        default:
            CoachHaptic.drillSuccess()
        }
        // Clear the pending intent BEFORE dispatching the continuation so the
        // card collapses and the continuation turn (which would itself match
        // the detector) does not re-arm it.
        pendingGoalIntent = nil
        send(chip.dispatchText, detectIntent: false)
    }

    /// COLD START commit — the user has no `CoachingProfile` yet. Construct a
    /// full profile from sensible defaults + the chosen voice (mirrors the
    /// canonical `CoachingOnboardingView.saveProfile` construction) and save.
    /// `save()` persists, syncs, and kicks the AI goal-paraphrase. No
    /// `noteVoiceChange` here — cold start has no prior voice and no memory to
    /// record a course change against; the profile write IS the durable record.
    private func recordGoalSet(_ newVoice: SpeakingStyleGoal) -> Bool {
        // Guard against a race where a profile materialised between detection
        // and tap (e.g. onboarding finished in another surface). If a profile
        // now exists, treat this as a change instead of clobbering it.
        if coachingProfileStore.profile != nil {
            return recordGoalChange(to: newVoice, blend: false)
        }
        // Default biggest challenge → its recommended priority; voice → its
        // recommended outcome. Same derivations the onboarding flow uses, so a
        // chat-set profile is shaped identically to an onboarded one.
        let defaultChallenge: SpeakingChallenge = .fillerWords
        let profile = CoachingProfile(
            speakingContext: .work,
            primaryGoal: defaultChallenge.recommendedPriority,
            confidenceLevel: .rebuilding,
            biggestChallenge: defaultChallenge,
            desiredOutcome: newVoice.recommendedOutcome,
            speakingStyleGoal: newVoice,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: newVoice   // explicit user choice → tailored from here
        )
        return coachingProfileStore.save(profile)
    }

    /// CHANGE commit — the user already has a voice. Save the profile first,
    /// then record the course change in coach memory so a failed profile write
    /// cannot leave a false audit event. A full
    /// switch replaces `speakingStyleGoal` and clears any prior blend secondary;
    /// a blend keeps the current primary and sets the new voice as the
    /// secondary. `paraphrasedGoal` is reset to nil so `save()` re-paraphrases
    /// the goal in the new voice. Bounded scope — only voice fields + the
    /// paraphrase reset are touched, never arbitrary profile data.
    private func recordGoalChange(to newVoice: SpeakingStyleGoal, blend: Bool) -> Bool {
        guard var profile = coachingProfileStore.profile else {
            // No profile to change — fall back to cold-start construction. (Only
            // reachable if the profile vanished between detection and tap.)
            return recordGoalSet(newVoice)
        }
        guard let fromVoice = profile.chosenStyleGoal else {
            // A compatibility fallback is not a prior user choice. Treat this
            // confirmation as the first explicit set and preserve the rest of
            // the profile without recording a fictitious course change.
            profile.speakingStyleGoal = newVoice
            profile.chosenStyleGoal = newVoice
            profile.secondaryStyleGoal = nil
            profile.paraphrasedGoal = nil
            return coachingProfileStore.save(profile)
        }
        // No-op guard: a full "switch" to the voice the user already has would
        // record a meaningless course change. Bail before any write.
        if !blend && fromVoice == newVoice { return true }

        if blend {
            // Keep the primary; add the new voice as the secondary. A blend onto
            // the existing primary widens the read without erasing it.
            profile.secondaryStyleGoal = newVoice
            // The primary stays the user's chosen voice; ensure the choice flag
            // is set (covers a legacy profile whose chosenStyleGoal was nil).
            profile.speakingStyleGoal = fromVoice
            profile.chosenStyleGoal = fromVoice
        } else {
            // Full switch — new primary, drop any prior blend secondary.
            profile.speakingStyleGoal = newVoice
            profile.chosenStyleGoal = newVoice
            profile.secondaryStyleGoal = nil
        }
        // Re-paraphrase the goal in the new voice on the next save pass.
        profile.paraphrasedGoal = nil
        guard coachingProfileStore.save(profile) else { return false }

        let kind: CoachCourseChange.VoiceChangeKind = blend ? .blend : .switchVoice
        coachMemoryStore.noteVoiceChange(
            from: fromVoice,
            to: newVoice,
            reason: CoachCourseChange.voiceChangeReason(from: fromVoice, to: newVoice, kind: kind),
            evidenceBasis: "User confirmed a change in training emphasis; prior observed evidence was retained.",
            statedGoalSummary: coachingProfileStore.profile?.personalGoalReference,
            effectiveVoice: blend ? fromVoice : newVoice
        )
        return true
    }

    struct CoachOptionLayout: Equatable {
        let primary: String?
        let overflow: [String]
    }

    static func coachOptionLayout(for options: [String]) -> CoachOptionLayout {
        var seen = Set<String>()
        let cleaned = options.compactMap { option -> String? in
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return trimmed
        }
        return CoachOptionLayout(primary: cleaned.first, overflow: Array(cleaned.dropFirst()))
    }

    static func aiGeneratedSuggestions(cached: [String]?, eligible: Bool) -> [String] {
        guard eligible, let cached, !cached.isEmpty else { return [] }
        return cached
    }

    @ViewBuilder
    private func coachNextMovePanel(
        launch: AskNoumModeSuggestion.LaunchProjection?,
        chips: [String]
    ) -> some View {
        let layout = Self.coachOptionLayout(for: chips)
        if launch != nil || layout.primary != nil {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    NoumSemanticGraphic(
                        role: .practice,
                        tint: AppColor.coachAccent,
                        size: Spacing.xxl
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Next move")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.coachingInkOnQuiet)
                        Text(launch == nil ? "Keep the coaching thread focused." : "Take this read back into one rep.")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let latest = store.messages.last,
                   latest.role == .coach,
                   !latest.isPending,
                   !latest.isOffline {
                    coachDetailDisclosure(message: latest, accent: AppColor.proText)
                }

                Button {
                    CoachHaptic.selectionTap()
                    if let launch {
                        let imAvailable = IMModeAvailability.isAvailable
                        let tapLaunch = launch.resolvingForTap(
                            modeAvailability: NextActionModeAvailability(
                                rating: ratingStore.rating,
                                imConversationAvailable: imAvailable
                            ),
                            imAvailable: imAvailable
                        )
                        PracticeModeQuickStart.arm(for: tapLaunch.quickStartMode)
                        navigationPath.append(tapLaunch.destination)
                    } else if let primary = layout.primary {
                        send(primary)
                    }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: launch == nil ? "arrow.up.right.circle.fill" : "play.circle.fill")
                            .font(Typography.headline)
                            .accessibilityHidden(true)
                        Text(primaryNextMoveLabel(launch: launch, fallback: layout.primary))
                            .font(Typography.cardLabel)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(Typography.caption.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget + Spacing.sm, alignment: .leading)
                    .background(
                        AppColor.coachingInk,
                        in: Capsule(style: .continuous)
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("askNoum.nextMove.primary")
                .accessibilityLabel(primaryNextMoveAccessibilityLabel(launch: launch, fallback: layout.primary))

                if !layout.overflow.isEmpty {
                    Menu {
                        ForEach(layout.overflow, id: \.self) { option in
                            Button(option) {
                                send(option)
                            }
                        }
                    } label: {
                        Label("Other useful directions", systemImage: "ellipsis.circle")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.coachingInkOnQuiet)
                            .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget, alignment: .leading)
                    }
                    .accessibilityIdentifier("askNoum.nextMove.more")
                    .accessibilityLabel("Other directions")
                }
            }
            .padding(Spacing.lg)
            .background(
                AppColor.proQuietSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(AppColor.pro.opacity(0.16), lineWidth: 1)
            )
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            .accessibilityIdentifier("askNoum.nextMovePanel")
        }
    }

    private func primaryNextMoveLabel(
        launch: AskNoumModeSuggestion.LaunchProjection?,
        fallback: String?
    ) -> String {
        if let launch {
            return launch.label
        }
        return fallback ?? "Continue"
    }

    private func primaryNextMoveAccessibilityLabel(
        launch: AskNoumModeSuggestion.LaunchProjection?,
        fallback: String?
    ) -> String {
        if let launch {
            return launch.label
        }
        return "Follow up: \(fallback ?? "Continue")"
    }

    // MARK: - Message rows

    private func responseEvidenceMetadata(for message: CoachMessage) -> String? {
        AskNoumEvidenceMetadata.line(
            responseKind: message.metadata?.responseKind,
            hasCurrentFocus: Self.currentFocusValue(
                caseFile: coachMemoryStore.currentMemory?.caseFile
            ) != nil,
            recentRepCount: sessionStore.progressEligibleSessionCount
        )
    }

    /// Quiet session-ending action at the bottom of the thread. Stops any
    /// speech, then pops the shared NavigationPath to root — a deep chat
    /// thread returns straight Home in one tap. Renders only when a
    /// conversation exists (the empty state has nothing to end).
    private var endChatRow: some View {
        Button {
            CoachHaptic.selectionTap()
            speaker.stop()
            navigationPath = NavigationPath()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.uturn.left")
                    .font(.caption.weight(.semibold))
                Text("Done")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .background(AppColor.tagBackground, in: Capsule())
        }
        .buttonStyle(.pressable)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
        .accessibilityLabel("Done. Return home")
        .accessibilityIdentifier("askNoum.endChat")
    }

    @ViewBuilder
    private func messageRow(message: CoachMessage) -> some View {
        switch message.role {
        case .user:
            userBubble(message: message)
        case .coach:
            coachBubble(message: message)
        case .systemNotice:
            noticeBubble(message: message)
        }
    }

    private func userBubble(message: CoachMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            Text(message.text)
                .font(Typography.manrope(size: 16, weight: .medium, relativeTo: .body))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    AppColor.brandBlue,
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
                .accessibilityLabel("You: \(message.text)")
        }
    }

    private func coachBubble(message: CoachMessage) -> some View {
        // The scope appears only on the current read. Older replies keep a
        // slim leading rule, so a long thread does not become repeated brand
        // chrome; the in-flight row owns the same coach-read semantics until
        // it resolves into the authored current-read card.
        //
        // LEGACY OFFLINE STATE: older builds could persist local fallback copy
        // as `.coach` rows with `isOffline`. New turns no longer create those
        // rows, but saved threads still deserve honest styling: neutral stroke,
        // muted text, and a quiet "Offline — reconnect for a full read" marker.
        let accent = message.isOffline ? AppColor.textSecondary : AppColor.pro
        let provisionalText = message.isPending
            ? message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let showsProvisionalRead = message.isPending && !provisionalText.isEmpty
        let isFeaturedReply = message.isPending || message.id == latestLandedCoachID

        return HStack(alignment: .top, spacing: 12) {
            if !isFeaturedReply && (!message.isPending || showsProvisionalRead) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(message.isOffline ? 0.45 : 0.78))
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if isFeaturedReply && !message.isPending {
                    coachReplyIdentity(accent: accent)
                }

                if message.isPending {
                    if showsProvisionalRead {
                        provisionalCoachRead(message: message, accent: accent)
                    } else {
                        pendingDots
                            .padding(.vertical, 4)
                    }
                } else {
                    if message.isOffline {
                        offlineMarker
                    }
                    // Living-coach-presence: the just-landed reply reveals word
                    // by word (see `revealingMessageID`); every other row shows
                    // its full text. Provider text is normalized before storage,
                    // so the renderer can make plain lead-ins bold without raw
                    // `**` ever reaching the live call or TTS.
                    CoachFormattedMessageText(
                        text: visibleCoachText(for: message),
                        textColor: message.isOffline ? Color.secondary : Color.primary,
                        accent: accent
                    )

                    if !message.isOffline,
                       message.id == latestLandedCoachID,
                       activeContinuationSurface == nil {
                        coachDetailDisclosure(message: message, accent: accent)
                    }
                }
            }
        }
        .padding(isFeaturedReply ? Spacing.lg : Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isFeaturedReply {
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .fill(message.isOffline ? AppColor.innerSurface : AppColor.cardBackground)
            } else if message.isOffline {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(AppColor.innerSurface)
            }
        }
        .overlay {
            if isFeaturedReply {
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(accent.opacity(message.isOffline ? 0.14 : 0.10), lineWidth: 1)
            }
        }
        .shadow(
            color: isFeaturedReply ? AppColor.coachingInk.opacity(0.05) : .clear,
            radius: isFeaturedReply ? Spacing.sm : 0,
            y: isFeaturedReply ? Spacing.xxs : 0
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            message.isOffline
                ? "Noum, offline reply: \(AskNoumCoachVisibleText.displayText(for: message))"
                : message.isPending && !showsProvisionalRead
                    ? "Noum is thinking"
                : showsProvisionalRead
                    ? "Noum is preparing the full reply. Immediate coach read: \(AskNoumCoachVisibleText.displayText(for: message))"
                : "Noum: \(AskNoumCoachVisibleText.displayText(for: message))"
        )
    }

    /// The newest coach response receives one authored coach-read line. Older
    /// replies remain quiet transcript history, so a long thread has a clear
    /// current read rather than a stack of visually identical chat cards.
    private func coachReplyIdentity(accent: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            NoumSemanticGraphic(
                role: .coachRead,
                tint: accent,
                size: Spacing.xxl
            )
            .accessibilityHidden(true)

            Text("Noum · coach read")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(accent)
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    /// Keeps the conversational reply primary. The selected professional move
    /// and bounded evidence receipt are available in one disclosure instead of
    /// stacking a model line, drill, test, metrics, and source as report cards.
    @ViewBuilder
    private func coachDetailDisclosure(message: CoachMessage, accent: Color) -> some View {
        let move = AskNoumPracticeMovePresentation.make(metadata: message.metadata)
        let evidence = responseEvidenceMetadata(for: message)

        if move != nil || evidence != nil {
            let isExpanded = expandedCoachDetailMessageID == message.id
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    withAnimation(
                        NoumMotion.animation(for: .calm, reduceMotion: reduceMotion)
                    ) {
                        expandedCoachDetailMessageID = isExpanded ? nil : message.id
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: move == nil ? "checkmark.seal" : "scope")
                            .font(Typography.captionSmall.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(move == nil ? "Why this read" : "Practice this move")
                            .font(Typography.caption.weight(.semibold))
                        Spacer(minLength: Spacing.xs)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(Typography.captionSmall.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isExpanded
                        ? "Hide coaching move details"
                        : (move == nil ? "Show why this read" : "Show model line, drill, and pass test")
                )
                .accessibilityIdentifier("askNoum.coachMove.disclosure")

                if isExpanded {
                    if let move {
                        Text(move.title)
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        coachMoveDetail(
                            label: "MODEL LINE · EXAMPLE SHAPE",
                            text: "\u{201C}\(move.modelLine)\u{201D}",
                            symbol: "quote.opening"
                        )
                        coachMoveDetail(
                            label: "DRILL",
                            text: move.drill,
                            symbol: "mic"
                        )
                        coachMoveDetail(
                            label: "PASS TEST",
                            text: move.passCondition,
                            symbol: "checkmark.seal"
                        )
                    }

                    if let evidence {
                        Label(evidence, systemImage: "lock.shield")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(evidence)
                            .accessibilityIdentifier("askNoum.responseEvidence")
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
            .padding(.top, Spacing.xs)
        }
    }

    private func coachMoveDetail(
        label: String,
        text: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.proText)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(Typography.micro.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(AppColor.textTertiary)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(text)")
    }

    private func provisionalCoachRead(message: CoachMessage, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                NoumSemanticGraphic(
                    role: .coachRead,
                    tint: AppColor.coachAccent,
                    size: 20
                )
                Text("Coach read")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.72))
            }
            .accessibilityHidden(true)

            CoachFormattedMessageText(
                text: visibleCoachText(for: message),
                textColor: Color.primary,
                accent: accent
            )

            Text("Full answer coming")
                .font(Typography.micro.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach read. \(AskNoumCoachVisibleText.displayText(for: message)). Full answer coming.")
    }

    private func visibleCoachText(for message: CoachMessage) -> String {
        AskNoumCoachVisibleText.text(
            for: message,
            revealingMessageID: revealingMessageID,
            revealedText: revealedText
        )
    }

    /// Quiet "offline" chip shown above legacy offline coach rows. New turns
    /// become system notices instead; this remains for persisted history.
    private var offlineMarker: some View {
        HStack(spacing: 5) {
            Image(systemName: "wifi.slash")
                .font(Typography.micro.weight(.semibold))
            Text("Offline \u{2014} reconnect for a full read")
                .font(Typography.micro.weight(.semibold))
                .tracking(0.3)
        }
        .foregroundStyle(AppColor.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline reply. Reconnect for a full read from your coach.")
    }

    private func noticeBubble(message: CoachMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            Text(message.text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("askNoum.systemNotice")
        .accessibilityLabel("Notice: \(message.text)")
    }

    // MARK: - Pending state
    //
    // One static coach-read mark. Waiting on a text/model response is not a
    // voice state, so this surface must not borrow the live-audio waveform.

    private var pendingDots: some View {
        HStack(spacing: Spacing.sm) {
            NoumSemanticGraphic(
                role: .coachRead,
                tint: AppColor.coachAccent,
                size: 24
            )
            .accessibilityHidden(true)
            Text("Thinking through one useful response…")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityLabel("Noum is thinking")
    }

    // MARK: - Input area (integrated text + voice composer)

    @ViewBuilder
    private var inputArea: some View {
        inputBar
    }

    /// Shared tap action for the single trailing composer control.
    private func performInputAction(for mode: InputControlMode) {
        // Tap-time truth beats a stale SwiftUI button closure: if the user has
        // typed anything, this control is Send even if the action was captured
        // on the previous mic frame.
        if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            trySend()
            return
        }
        switch mode {
        case .send, .sendOnly:
            trySend()
        case .speaking:
            // The control is the Stop affordance while the coach speaks.
            CoachHaptic.selectionTap()
            speaker.stop()
        case .mic, .recording, .processing:
            CoachHaptic.selectionTap()
            // Barge-in: silence any in-flight coach speech the moment the user
            // reaches for the mic, so the synthesizer never fights the recognizer.
            speaker.stop()
            voiceInput.toggle()
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            coachStatusRow
            micNoticeRow
            voiceNoticeRow
            partialTranscriptPreview
            inputBarRow
        }
        .background(.ultraThinMaterial)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: voiceInput.state == .recording)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: voiceInput.partialTranscript)
        // V4.6.1 — the availability banner settles between its states
        // (checking / unavailable / restored) instead of jump-cutting.
        // Reduce Motion keeps the paired plain fade per the V4.6 contract:
        // the banner is a state swap, not an entrance, so it fades rather
        // than appearing instantly.
        .animation(reduceMotion ? .v46ReduceMotionFade : .settle, value: liveCoachAvailability)
        .animation(reduceMotion ? .v46ReduceMotionFade : .settle, value: showsCoachRestoredConfirmation)
    }

    @ViewBuilder
    private var coachStatusRow: some View {
        if let message = store.transientFailureMessage {
            HStack(alignment: .center, spacing: Spacing.xs) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.caution)
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                Button("Try again") { retryLastTurn() }
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("askNoum.transientFailure")
        } else if liveCoachAvailability == .checking {
            HStack(spacing: Spacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting to Noum…")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .transition(.opacity)
            .accessibilityIdentifier("askNoum.availabilityChecking")
        } else if case .unavailable(let reason) = liveCoachAvailability {
            let presentation = AskNoumAvailabilityPresentation.resolve(reason)
            HStack(alignment: .center, spacing: Spacing.xs) {
                Image(systemName: "bolt.slash")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Text(presentation.message)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                if presentation.showsCheckAgain {
                    if AskNoumAvailabilityRecheckPolicy.shouldOfferReport(
                        reason: reason,
                        failedRechecks: availabilityRecheckFailures
                    ) {
                        // Repeated failed re-checks on a reportable reason:
                        // reporting leads, with pre-filled privacy-safe
                        // diagnostics. A quiet re-check stays alongside so
                        // recovery never requires leaving the screen — a
                        // success resets the counter and clears the banner.
                        VStack(alignment: .trailing, spacing: 0) {
                            Button("Report issue") {
                                reportAvailabilityIssue(reason: reason)
                            }
                            .font(Typography.caption.weight(.bold))
                            .foregroundStyle(AppColor.brandBlue)
                            .frame(minHeight: 44)
                            .accessibilityHint("Opens a pre-filled support email, or the support page when no mail app is set up.")
                            .accessibilityIdentifier("askNoum.reportIssue")

                            Button("Check again") {
                                recheckAvailability()
                            }
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("askNoum.checkAgainQuiet")
                        }
                    } else {
                        Button("Check again") {
                            recheckAvailability()
                        }
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44)
                    }
                } else if presentation.connectsLocalGuest {
                    Button("Connect") {
                        Task { @MainActor in
                            liveCoachAvailability = .checking
                            await authManager.connectLocalGuestToCloud(
                                force: true
                            )
                            await refreshAvailability()
                        }
                    }
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Connect live coaching")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("askNoum.availability")
        } else if showsCoachRestoredConfirmation {
            // V4.6.1 — transient confirmation that an unavailable episode
            // just ended. Informative, not a dead footer: it names the
            // recovery once, then auto-fades so the resting bar stays
            // quiet. `bolt` mirrors the unavailable banner's `bolt.slash`.
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bolt")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.positive)
                Text("Back online.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("askNoum.availabilityRestored")
        }
    }

    /// V4.6.1 — transient confirmation after an unavailable episode ends:
    /// "Back online." holds for a short dwell, then fades out (the banner
    /// container's `settle`/RM-fade animation drives both edges). State
    /// change only — the dwell is a display hold, not an animation timing,
    /// so no motion token applies to it. The task is cancelled by teardown
    /// and by any fresh `.checking` probe.
    private func presentRestoredConfirmation() {
        restoredConfirmationTask?.cancel()
        showsCoachRestoredConfirmation = true
        restoredConfirmationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showsCoachRestoredConfirmation = false
        }
    }

    /// Re-probe availability from the banner. Increments the failure count
    /// only when the re-check lands on a reason where reporting is real
    /// remediation — an aborted probe that leaves `.checking` neither counts
    /// nor resets, and a genuine restore resets the counter via the
    /// `liveCoachAvailability` observer (never a spurious reset here).
    private func recheckAvailability() {
        Task { @MainActor in
            await refreshAvailability()
            if case .unavailable(let reason) = liveCoachAvailability,
               AskNoumAvailabilityRecheckPolicy.countsTowardReport(reason) {
                availabilityRecheckFailures += 1
            }
        }
    }

    /// Open the pre-filled support draft. `mailto:` silently no-ops on
    /// devices with no mail client configured, so the completion falls back
    /// to the hosted support page — "Report issue" is never a dead tap.
    /// Diagnostics stay privacy-safe: typed reason code, re-check count,
    /// and version strings only.
    private func reportAvailabilityIssue(reason: CoachChatUnavailableReason) {
        let mail = NoumWebURLs.askNoumUnavailableSupportMail(
            reasonCode: AskNoumAvailabilityRecheckPolicy.reportCode(for: reason),
            failedRecheckCount: availabilityRecheckFailures,
            appVersion: Self.appVersionSummary,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
        openURL(mail) { accepted in
            if !accepted {
                openURL(NoumWebURLs.support)
            }
        }
    }

    /// Marketing version + build, same read Settings' about row uses.
    private static var appVersionSummary: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }

    private func retryLastTurn() {
        guard !isPreparingSend,
              let sendAdmission = store.sendAdmission() else { return }
        isPreparingSend = true
        replyTask?.cancel()
        replyTask = Task { @MainActor in
            defer { isPreparingSend = false }
            liveCoachAvailability = .checking
            guard !Task.isCancelled,
                  store.sendAdmissionIsCurrent(sendAdmission) else { return }
            guard let retry = store.prepareRetry(expected: sendAdmission) else {
                return
            }
            pendingReplyCoachID = retry.coachID
            pendingReplyLease = retry.lease
            await runReply(
                coachID: retry.coachID,
                expected: retry.lease
            )
            clearPendingReplyTracking(coachID: retry.coachID)
        }
    }

    /// A2: surfaces a brief reason when voice can't proceed (permission /
    /// locale / temporary), so the mic never silently "does nothing" — paired
    /// with the mic control hiding itself. Renders only when set.
    @ViewBuilder
    private var micNoticeRow: some View {
        if let notice = voiceInput.notice {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(Typography.captionSmall)
                Text(notice)
                    .font(Typography.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .accessibilityIdentifier("askNoum.micNotice")
        }
    }

    /// C5 — honest spoken-reply state: when the user asked for voice (Aloud
    /// on) but no engine could produce audio, say so quietly instead of
    /// letting the silent bubble read as a muted coach. Gated on the voice
    /// preference so a user who has voice off never sees voice plumbing.
    @ViewBuilder
    private var voiceNoticeRow: some View {
        if voiceSettings.askNoumSpokenRepliesEnabled,
           let notice = speaker.voiceUnavailableNotice {
            HStack(spacing: 6) {
                Image(systemName: "speaker.slash")
                    .font(Typography.captionSmall)
                Text(notice)
                    .font(Typography.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .accessibilityIdentifier("askNoum.voiceNotice")
            .accessibilityLabel(notice)
        }
    }

    private var inputBarRow: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .leading) {
                if draft.isEmpty {
                    // The native multiline placeholder is exposed as an
                    // anonymous, fixed-height text node and fails Dynamic
                    // Type clipping audits. Render the visible prompt with
                    // Noum's readable token; the field below owns its spoken
                    // label, so VoiceOver never hears this twice.
                    Text(textFieldPlaceholder)
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextField("", text: $draft, axis: .vertical)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .focused($inputFocused)
                    // Keep long drafts editable without allowing the composer
                    // to consume the entire screen at accessibility sizes.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 4)
                    .submitLabel(.send)
                    .onSubmit { trySend() }
                    .accessibilityLabel("Message Noum")
                    .accessibilityIdentifier("askNoum.messageField")
            }
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            // One unified 44pt trailing control replaces the old greyed
            // send circle + the oversized separate mic. The glyph swaps by
            // draft state: empty → mic (start dictation), text → arrow.up
            // (send). Recording shows stop.fill, processing shows waveform.
            // When voice can't be served the control stays send-only (the
            // dead-toggle fallback) — it never pretends a mic that isn't
            // there. `.symbolEffect(.replace)` makes the swap a calm
            // morph, gated on reduce-motion.
            unifiedInputControl
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Unified input control (mic / arrow swap)
    //
    // Collapses what used to be three controls (text field + a greyed
    // up-arrow send circle + a larger separate blue mic) into one 44pt
    // trailing button whose meaning follows the draft. The previous
    // layout drew a *dead* greyed send button at all times AND a mic that
    // was visually larger than send — the user flagged both as clutter.
    //
    // Mode resolution (`inputControlMode`):
    //   • text in draft → `.send` (arrow.up, brand-purple, active)
    //   • empty draft + voice available + idle → `.mic` (mic.fill, brand-blue)
    //   • recording → `.recording` (stop.fill, brand-blue) — tap stops + sends
    //   • processing → `.processing` (waveform, brand-blue) — inert, recognizer
    //     is finalising
    //   • empty draft + voice unavailable → `.sendOnly` (arrow.up, greyed,
    //     disabled) — the honest dead-toggle fallback
    //
    // Both accessibility labels survive: the send modes read "Send
    // message" (the string the UI test taps); the voice modes read the
    // state-specific `micAccessibilityLabel`. Awaiting a reply dims +
    // disables the control (mirrors the old per-button gates).
    private var unifiedInputControl: some View {
        let mode = inputControlMode
        return Button {
            performInputAction(for: inputControlMode)
        } label: {
            ZStack {
                Circle()
                    .fill(inputControlFill(for: mode))
                    .frame(width: 44, height: 44)
                // Recording-only ring — keeps the live-capture cue without
                // reintroducing the oversized halo. Sized to hug the 44pt
                // control. The richer "Listening… + your words" affordance
                // already lives in `partialTranscriptPreview` above.
                if mode == .recording {
                    Circle()
                        .stroke(AppColor.brandBlue.opacity(0.35), lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .transition(.opacity)
                }
                Image(systemName: inputControlGlyph(for: mode))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            }
        }
        .disabled(inputControlDisabled(for: mode))
        // Speaking is an active, tappable Stop — it must NOT inherit the
        // awaiting-reply dim (the coach can be speaking turn N while turn N is,
        // by definition, no longer awaiting).
        .opacity((store.isAwaitingReply && mode != .speaking) ? 0.45 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
        .accessibilityLabel(inputControlAccessibilityLabel(for: mode))
        .accessibilityIdentifier("askNoum.inputControl")
    }

    /// The state of the single trailing control. Precedence, top-down:
    /// recording / processing (a live mic interaction wins over everything);
    /// then draft text → send; then a speaking coach → Stop; then the resting
    /// mic (or a disabled send when voice capture can't serve). Speaking sits
    /// BELOW send so typing always dispatches, and BELOW recording/processing
    /// so it never masks an in-progress dictation — but ABOVE the idle mic so
    /// an empty composer surfaces the Stop affordance while audio plays.
    private enum InputControlMode: Equatable {
        case send        // draft has text → dispatch
        case sendOnly    // empty draft, voice unavailable → disabled send
        case mic         // empty draft, voice idle → start dictation
        case recording   // capturing → stop + send
        case processing  // recognizer finalising → inert
        case speaking    // coach reply playing → tap to stop (barge-in)
    }

    private var inputControlMode: InputControlMode {
        if voiceInput.state == .recording { return .recording }
        if voiceInput.state == .processing { return .processing }
        let hasDraft = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasDraft { return .send }
        if speaker.isSpeaking { return .speaking }
        return voiceInput.isAvailable ? .mic : .sendOnly
    }

    private func inputControlGlyph(for mode: InputControlMode) -> String {
        switch mode {
        case .send, .sendOnly: return "arrow.up"
        case .mic: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "waveform"
        case .speaking: return "speaker.wave.2.fill"
        }
    }

    private func inputControlFill(for mode: InputControlMode) -> Color {
        switch mode {
        case .send:
            // Active send — only reachable when `canSend`, but guard anyway
            // so a stray awaiting-reply frame greys instead of inviting a tap.
            return canSend ? AppColor.pro : Color.secondary.opacity(0.20)
        case .sendOnly:
            return Color.secondary.opacity(0.20)
        case .mic, .recording, .processing, .speaking:
            return AppColor.brandBlue
        }
    }

    private func inputControlDisabled(for mode: InputControlMode) -> Bool {
        switch mode {
        case .send: return !canSend
        case .sendOnly: return true
        case .mic:
            return store.isAwaitingReply || !isCoachAvailable
        case .recording:
            return store.isAwaitingReply
        case .processing: return true
        // Always tappable — the whole point is barge-in.
        case .speaking: return false
        }
    }

    private func inputControlAccessibilityLabel(for mode: InputControlMode) -> String {
        switch mode {
        case .send, .sendOnly:
            return "Send message"
        case .speaking:
            return "Coach is speaking, double-tap to stop"
        case .mic, .recording, .processing:
            return micAccessibilityLabel
        }
    }

    /// "I'm hearing…" preview above the input bar while voice capture
    /// is active. Real-device confidence: without it, a long press on
    /// a noisy environment looks like a dead mic — the user can't tell
    /// whether the recognizer caught their first word. Surfaces the
    /// live partial transcript from `AskNoumVoiceInput` so the user
    /// sees their words appearing as they speak.
    ///
    /// Honest empty-state: while recording with no recognized text yet
    /// we show a soft "Listening…" line, NOT a stale stuck preview.
    /// The transcript replaces it as soon as the recognizer lands a
    /// word. After release-to-send the preview hides — the final
    /// transcript lands in the composer as editable draft text and the preview
    /// hides. The user sends it with the same trailing control.
    ///
    /// Visual register: small italic body text, brand-blue tint at
    /// 75% opacity, brand-blue 10% backdrop. Same accent the mic
    /// button uses so the user reads "this is the mic talking" not
    /// "this is a new system message". Hidden via opacity + 0-height
    /// frame collapse when idle so the input bar's resting layout
    /// doesn't shift around when capture starts.
    @ViewBuilder
    private var partialTranscriptPreview: some View {
        let isRecording = voiceInput.state == .recording
        let trimmed = voiceInput.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRecording {
            HStack(alignment: .top, spacing: 8) {
                NoumWaveformMark(
                    state: .listening,
                    level: trimmed.isEmpty ? 0.12 : 0.42,
                    tint: AppColor.brandBlue,
                    size: 20
                )
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(trimmed.isEmpty ? "Listening\u{2026}" : trimmed)
                    .font(Typography.body.italic())
                    .foregroundStyle(AppColor.brandBlue.opacity(trimmed.isEmpty ? 0.55 : 0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(trimmed.isEmpty
                                        ? "Listening for your voice"
                                        : "Hearing: \(trimmed)")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.brandBlue.opacity(0.08))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var textFieldPlaceholder: String {
        "Message Noum..."
    }

    /// State-specific accessibility label for the voice modes of the
    /// unified input control. Replaces the standalone mic button's label
    /// (the big mic was removed in the S4 input-row unification) — read by
    /// `inputControlAccessibilityLabel(for:)` when the control is in a
    /// mic / recording / processing mode.
    private var micAccessibilityLabel: String {
        switch voiceInput.state {
        case .idle:
            return "Tap to record your message"
        case .recording:
            return "Recording — tap to stop"
        case .processing:
            return "Processing your message"
        }
    }

    private var canSend: Bool {
        // Recording is an active stop state; typed text is the send state.
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         || voiceInput.state == .recording)
        && !store.isAwaitingReply
        && !isPreparingSend
        && isCoachAvailable
    }

    // MARK: - Send + scroll

    private func trySend() {
        // If recording is active, finalise it. Voice-first mode dispatches from
        // `onFinalTranscript`; typed fallback receives the transcript as draft
        // for review/edit before the next Send tap.
        if voiceInput.state == .recording {
            voiceInput.stopAndSend()
            return
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.isAwaitingReply else { return }
        inputFocused = false
        send(
            trimmed,
            clearDraftWhenSent: true
        )
    }

    /// Dispatch a user turn into the thread and request the coach reply.
    ///
    /// `detectIntent` is the single funnel for goal set/change detection — every
    /// organic entry point (typed, voice transcript, starter chip, follow-up
    /// chip, cross-surface inject) flows through here with it `true`, so
    /// `CoachContextBuilder.detectGoalIntent` runs once per real user turn and
    /// arms the confirmation card. The goal-card commit handlers dispatch their
    /// voice-shaped continuation with `detectIntent: false` so a continuation
    /// like "Set my voice to Warm." (which would itself match the detector)
    /// does NOT re-arm the card after the user already confirmed.
    ///
    /// Detection runs BEFORE the reply is dispatched and stores the intent on
    /// `pendingGoalIntent`; `runReply` reads it to inject the GOAL context line
    /// so the coach PROPOSES (the model still never writes — only a card tap
    /// commits). A nil result clears any stale pending intent so a non-goal
    /// turn collapses a card the user neither confirmed nor declined.
    private func send(
        _ text: String,
        detectIntent: Bool = true,
        clearDraftWhenSent: Bool = false
    ) {
        // Day-0 invariant: full replies stay gated on rep 1. The UI never
        // offers a dispatch path while `isDayZero` (no composer, no starter
        // chips), so this guard is belt-and-braces — it keeps the invariant
        // true even if a future surface wires a send into the seeded window.
        guard !isDayZero else { return }
        // Single-in-flight: every dispatch path (typed Send, voice transcript,
        // starter/follow-up/goal/next-move chips, cross-surface inject) funnels
        // through here. `trySend` checks isAwaitingReply but the chip/voice/menu
        // paths call send() directly, so a rapid second chip or an already-open
        // menu could mint a second pending row + a second CoachReplyPipeline run
        // (double Gemini spend, racing replies). Guard once at the funnel.
        guard !store.isAwaitingReply,
              !isPreparingSend,
              let sendAdmission = store.sendAdmission() else { return }
        isPreparingSend = true
        replyTask?.cancel()
        replyTask = Task { @MainActor in
            defer { isPreparingSend = false }
            liveCoachAvailability = .checking
            guard !Task.isCancelled,
                  store.sendAdmissionIsCurrent(sendAdmission) else { return }
            guard !store.isAwaitingReply else { return }
            speaker.stop()
            if clearDraftWhenSent { draft = "" }
            if detectIntent {
                let detectedIntent = CoachContextBuilder.detectGoalIntent(text, currentVoice: voice)
                if detectedIntent != nil || !CoachContextBuilder.isBareClarificationTurn(text) {
                    pendingGoalIntent = detectedIntent
                    goalSaveError = nil
                }
            }
            guard let dispatch = store.appendUserTurn(
                text,
                expected: sendAdmission
            ) else { return }
            pendingReplyCoachID = dispatch.coachID
            pendingReplyLease = dispatch.lease
            await runReply(
                coachID: dispatch.coachID,
                expected: dispatch.lease
            )
            clearPendingReplyTracking(coachID: dispatch.coachID)
        }
    }

    @MainActor
    private func refreshAvailability() async {
        guard let sendAdmission = store.sendAdmission() else {
            liveCoachAvailability = .unavailable(.authenticationPending)
            return
        }
        liveCoachAvailability = .checking
        let availability = await AICoachChatService.shared.availability()
        guard !Task.isCancelled,
              store.sendAdmissionIsCurrent(sendAdmission) else { return }
        liveCoachAvailability = availability
    }

    private var isCoachAvailable: Bool {
        liveCoachAvailability == .available
    }

    @MainActor
    private func runInjectedReply(
        coachID: UUID,
        expected replyLease: AskNoumReplyLease
    ) async {
        guard store.replyLeaseIsCurrent(replyLease) else {
            clearPendingReplyTracking(coachID: coachID)
            return
        }
        liveCoachAvailability = .checking
        guard !Task.isCancelled else {
            _ = store.cancelPendingCoachTurn(
                id: coachID,
                expected: replyLease
            )
            clearPendingReplyTracking(coachID: coachID)
            return
        }
        await runReply(coachID: coachID, expected: replyLease)
        clearPendingReplyTracking(coachID: coachID)
    }

    private func runReply(
        coachID: UUID,
        expected replyLease: AskNoumReplyLease
    ) async {
        // Context assembly + model call + row hydration is shared with the live
        // call view via `CoachReplyPipeline` (one brain for both surfaces). The
        // spoken-reply decision stays here because it differs by surface.
        let outcome = await CoachReplyPipeline.generate(
            coachID: coachID,
            pendingGoalIntent: pendingGoalIntent,
            expectedReplyLease: replyLease
        )
        guard store.replyLeaseScopeIsCurrent(replyLease) else { return }
        switch outcome {
        case .reply:
            liveCoachAvailability = .available
        case .failure(.coachUnavailable(let reason)):
            liveCoachAvailability = .unavailable(reason)
        case .failure(.backendVersionMissing):
            liveCoachAvailability = .unavailable(.backendVersionMissing)
        case .failure(.unauthenticated), .failure(.permissionDenied):
            liveCoachAvailability = .unavailable(.authenticationPending)
        case .failure(.noProvider):
            liveCoachAvailability = .unavailable(.debugProviderMissing)
        case .failure(.network):
            liveCoachAvailability = .unavailable(.service)
        case .failure:
            // The callable was reachable; content, policy, rate, locale, or
            // consent failure must not disable the composer as an outage.
            liveCoachAvailability = .available
        }
        let route = AskNoumSpokenMode.spokenRoute(
            outcome: outcome,
            spokenRepliesEnabled: voiceSettings.askNoumSpokenRepliesEnabled,
            localeSupportsAI: LocaleSettingsManager.shared.current.aiSupported
        )
        guard route != .none else {
            Self.speechLog.debug("typed chat speech skipped route=none")
            return
        }
        guard let spokenText = AskNoumSpokenMode.spokenText(for: outcome) else {
            Self.speechLog.notice("typed chat speech skipped after sanitizer emptied reply")
            return
        }
        Self.speechLog.info("typed chat speech starting chars=\(spokenText.count, privacy: .public)")
        speaker.speak(
            spokenText,
            setup: IMConversationSetup(
                scenario: .workUpdate,
                targetTone: AskNoumSpokenMode.coachTone(for: voice)
            ),
            allowOnDeviceFallback: true,
            onDeviceOnly: false
        )
    }

    private func clearPendingReplyTracking(coachID: UUID) {
        guard pendingReplyCoachID == coachID else { return }
        pendingReplyCoachID = nil
        pendingReplyLease = nil
    }

    /// Progressively reveal a just-landed coach reply, word by word, so the
    /// coach reads as *writing to you* rather than the text popping in. The
    /// store already holds the full text; this only drives the visible prefix
    /// (`revealedText`) for `message.id`. Cancellable — a new turn or a view
    /// teardown cancels the task so it never writes state for a superseded row.
    /// Caller guarantees reduce-motion is OFF (the instant path skips this).
    @MainActor
    private func startReveal(of message: CoachMessage, proxy: ScrollViewProxy) {
        revealTask?.cancel()
        revealingMessageID = message.id
        revealedText = ""
        // Reveal from the SAME sanitized string the bubble renders when the
        // reveal completes (`AskNoumCoachVisibleText.displayText`), so no
        // scaffold word ever flashes mid-reveal and the handoff to the full
        // text at the end is seamless (identical characters).
        let words = AskNoumCoachVisibleText.displayText(for: message)
            .split(separator: " ", omittingEmptySubsequences: false)
        revealTask = Task { @MainActor in
            var assembled = ""
            for (i, word) in words.enumerated() {
                if Task.isCancelled { return }
                assembled += i == 0 ? String(word) : " " + word
                revealedText = assembled
                // Keep the growing bubble in view without thrashing the
                // scroller — nudge every few words, not every word.
                if i % 4 == 0 { scrollToBottom(proxy: proxy) }
                try? await Task.sleep(nanoseconds: 30_000_000) // ~30ms/word
            }
            if Task.isCancelled { return }
            // V4.6.1 — the reply has fully landed: one soft ack (selection
            // register — an acknowledgment, not an earned-progress beat)
            // after the final word. This is the motion users' half of the
            // reply-landed pair; RM users get the same
            // ack from the `isAwaitingReply` observer, since no reveal is
            // ever armed for them. Haptic suppressed while the mic records.
            if voiceInput.state != .recording {
                CoachHaptic.selectionTap()
            }
            // Hand back to the store's full `message.text` (identical to the
            // assembled string) so the bubble's source of truth is the store.
            revealingMessageID = nil
            revealedText = ""
            scrollToBottom(proxy: proxy)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .linear(duration: 0.001) : .easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

#endif
