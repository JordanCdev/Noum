import Foundation
import Combine
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// IM Mode's NPC chat service. The NPC persona is scenario-locked
/// (Maya/Jordan/Sam/Alex) but the tonal calibration shifts with the user's
/// trained voice — fewer interruptions for an authoritative trainee, more
/// curiosity for a warm one, closed questions for a concise one, etc.
///
/// Before M25 the system prompt here was the literal string
/// `"You are a helpful AI assistant."` — see `docs/M19_audit_personalization.md`
/// for the audit that surfaced the gap. This service now reads the user's
/// `CoachingProfile`, any active `BigMoment`, and the same
/// `CoachContextBuilder.userContext` block the AICoachChatService receives,
/// so the NPC behaves as a coach in costume rather than a generic chatbot.
public final class AINPCChatService: ObservableObject {
    public enum Role: String {
        case user, assistant, system
    }

    public struct Message {
        public let role: Role
        public let text: String

        public init(role: Role, text: String) {
            self.role = role
            self.text = text
        }
    }

    @Published public private(set) var history: [Message] = []
    @Published public private(set) var streamedText: String = ""

    private var streamURL: URL? {
        #if canImport(FirebaseRemoteConfig) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        if let s = RemoteConfig.remoteConfig()["ai_stream_url"].stringValue, !s.isEmpty {
            return URL(string: s)
        }
        #endif
        return nil
    }

    private let modelName = "default-model"

    public init() {}

    // MARK: - Send

    /// Drive a single user turn through the NPC. The system prompt is rebuilt
    /// from the live coaching profile + scenario + voice every send so a voice
    /// change mid-thread takes effect on the next turn.
    func sendStreaming(
        _ userText: String,
        setup: IMConversationSetup,
        profile: CoachingProfile?,
        bigMoment: BigMoment?,
        userContextBlock: String?
    ) async {
        let prompt = Self.buildSystemPrompt(
            setup: setup,
            profile: profile,
            bigMoment: bigMoment,
            userContextBlock: userContextBlock
        )

        if streamURL != nil {
            await streamViaSSE(userText, systemPrompt: prompt)
            return
        }

        // No stream URL configured. Record the turn so callers can still
        // exercise the history surface without a live provider; UI is
        // responsible for surfacing the absence of a model response.
        await MainActor.run {
            self.history.append(.init(role: .user, text: userText))
            self.trimHistoryIfNeeded()
        }
    }

    /// Back-compat overload that builds a default setup. Kept so the
    /// `ChatDemoView` demo surface continues to compile without churn.
    public func sendStreaming(_ userText: String) async {
        let defaultSetup = IMConversationSetup(scenario: .workUpdate, targetTone: .confident)
        await sendStreaming(
            userText,
            setup: defaultSetup,
            profile: nil,
            bigMoment: nil,
            userContextBlock: nil
        )
    }

    // MARK: - System prompt

    /// Pure-function system-prompt builder. Exposed `internal` so tests can
    /// assert that each voice variant produces a prompt containing the
    /// voice-specific testing-for clause — without standing up a network
    /// provider.
    static func buildSystemPrompt(
        setup: IMConversationSetup,
        profile: CoachingProfile?,
        bigMoment: BigMoment?,
        userContextBlock: String?
    ) -> String {
        let scenario = setup.scenario
        var lines: [String] = []

        lines.append("You are \(scenario.personaName), a \(scenario.personaRole) in a short instant-message exchange with the user.")
        lines.append("Scenario: \(scenario.title). Stakes: \(scenario.stakes). Your current mood: \(scenario.currentMood).")
        lines.append("Your conversation goal: \(scenario.conversationGoal).")
        lines.append("Friction style: \(scenario.frictionStyle).")
        lines.append("Coaching focus the user is training: \(scenario.coachingFocus).")
        lines.append("Keep replies short — one or two sentences, like a real IM. No exclamation marks. No emoji. Direct, second person.")
        lines.append("")
        lines.append("STAY IN PERSONA. You are \(scenario.personaName) — not a coach, not an AI. Do not break character. Do not narrate the exercise.")

        // Voice-shaped tonal calibration. The persona stays the same; the
        // way the persona LEAVES ROOM, ASKS, and PRESSURES shifts to align
        // with what the user is training. This is the "coaching wrapper"
        // bit the IM Mode advertises but did not actually do before M25.
        lines.append("")
        lines.append("HOW THE USER WANTS TO SOUND (calibrate your turns accordingly)")
        let voice = profile?.speakingStyleGoal
        lines.append(contentsOf: tonalCalibrationLines(for: voice))

        // Per-voice testing clause — gives the NPC something to subtly
        // create pressure on, aligned with the user's growth direction
        // rather than generic conversational pressure.
        lines.append("")
        lines.append("WHAT TO SUBTLY TEST FOR")
        lines.append("- \(testingClause(for: voice))")

        // User goal block — short, structured, kept above the dense
        // userContext payload so the NPC always sees the headline goal
        // even if the full context is omitted.
        if let profile {
            lines.append("")
            lines.append("USER GOAL HEADLINES")
            lines.append("- Voice target: \(profile.speakingStyleGoal.title) — \(profile.speakingStyleGoal.coachingDescription).")
            if let paraphrase = profile.paraphrasedGoal?.trimmingCharacters(in: .whitespacesAndNewlines),
               !paraphrase.isEmpty {
                lines.append("- In their words: \(paraphrase)")
            }
            let challenge = challengeDisplayLabel(profile.biggestChallenge)
            lines.append("- Their stated biggest challenge: \(challenge)")
            let vision = profile.successVisionReference
            if !vision.isEmpty {
                lines.append("- Their vision of success: \(vision)")
            }
        }

        // Big Moment — only when the user has an active upcoming event.
        // The NPC doesn't break persona to coach about it, but knowing it
        // exists shapes pressure (a user with a board pitch in 3 days
        // deserves slightly sharper friction in workUpdate / networking).
        if let moment = bigMoment,
           let days = BigMomentStore.daysUntil(moment),
           days >= 0 && days <= 60 {
            lines.append("")
            lines.append("UPCOMING REAL-LIFE STAKE (do not mention directly unless the user brings it up)")
            lines.append("- They are preparing for: \(moment.title) (\(moment.category.displayName)) — \(days) day\(days == 1 ? "" : "s") away.")
        }

        // Full userContext block — the same one AICoachChatService
        // receives. Kept verbatim so the NPC can be "a coach in costume"
        // without re-deriving anything.
        if let block = userContextBlock?.trimmingCharacters(in: .whitespacesAndNewlines),
           !block.isEmpty {
            lines.append("")
            lines.append(block)
        }

        lines.append("")
        lines.append("OUTPUT RULES")
        lines.append("- Reply as \(scenario.personaName). Stay in IM register.")
        lines.append("- Never list the user's metrics back to them. You are the persona, not their coach.")
        lines.append("- Keep replies to ≤2 sentences. No exclamation marks. No emoji. No bullet lists.")

        return lines.joined(separator: "\n")
    }

    /// Per-voice tonal calibration. Phrased as instructions to the NPC,
    /// not feedback to the user — the NPC stays in character; only their
    /// rhythm, curiosity, and pressure dial moves with the user's voice.
    static func tonalCalibrationLines(for voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return [
                "- The user is training an authoritative register. Leave slightly more space between your turns. Avoid filler words yourself. Do not interrupt or pile on follow-ups."
            ]
        case .warm:
            return [
                "- The user is training a warm register. Respond with curiosity. Ask one genuine follow-up question per turn. Reward openness rather than efficiency."
            ]
        case .concise:
            return [
                "- The user is training a concise register. Ask cleaner closed questions. Reward brevity. Do not invite long rambles."
            ]
        case .persuasive:
            return [
                "- The user is training a persuasive register. Push back gently on claims that lack support. Require a piece of evidence or specifics before fully accepting a point."
            ]
        case .executive:
            return [
                "- The user is training executive presence. Frame turns as briefings. Skip small talk. Expect headlines first."
            ]
        case .storytelling:
            return [
                "- The user is training storytelling. Ask for context. Give them room to set the scene. Do not interrupt a thread before it lands."
            ]
        case .none:
            return [
                "- The user has not yet declared a voice. Stay neutral and steady — neither rush them nor over-soften."
            ]
        }
    }

    /// Voice-aligned subtle pressure point. The NPC will not say this out
    /// loud, but it shapes which user habits they reward and which they
    /// lightly stress-test inside the persona's natural turns.
    static func testingClause(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative:
            return "Watch for hedging. If the user hedges (kind of, sort of, I think, maybe), keep your reply factual rather than rewarding it."
        case .warm:
            return "Watch for emotional dryness. If the user lands a clean factual answer but no warmth, your reply should make room for a more human one without lecturing."
        case .concise:
            return "Watch for drift. If the user pads or rambles, your follow-up tightens — shorter, sharper question, not more permission."
        case .persuasive:
            return "Watch for unsupported claims. If the user asserts without evidence, ask for the specific that backs it up."
        case .executive:
            return "Watch for warmth-filler in place of substance. If the user opens with rapport instead of the headline, your reply moves them toward the headline."
        case .storytelling:
            return "Watch for thin scenes. If the user delivers a beat without context, ask for the moment it came from."
        case .none:
            return "Watch for whichever pattern surfaces first. Stay even-handed until the user shows you what they are working on."
        }
    }

    private static func challengeDisplayLabel(_ challenge: SpeakingChallenge) -> String {
        switch challenge {
        case .fillerWords: return "filler words"
        case .rambling: return "rambling"
        case .freezing: return "freezing under pressure"
        case .rushing: return "rushing"
        }
    }

    // MARK: - Streaming

    private func streamViaSSE(_ userText: String, systemPrompt: String) async {
        guard let url = streamURL else { return }

        var msgs: [[String: String]] = []
        msgs.append(["role": "system", "text": systemPrompt])
        for m in history { msgs.append(["role": m.role.rawValue, "text": m.text]) }
        msgs.append(["role": "user", "text": userText])

        do {
            #if canImport(FirebaseAuth)
            let token = try await currentIDToken()
            #else
            let token = ""
            #endif

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            req.addValue("text/event-stream", forHTTPHeaderField: "Accept")
            if !token.isEmpty { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            req.httpBody = try JSONSerialization.data(withJSONObject: ["messages": msgs])

            let (bytes, _) = try await URLSession.shared.bytes(for: req)

            await MainActor.run { self.streamedText = "" }
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                if json.isEmpty { continue }
                if let data = json.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let delta = dict["textDelta"] as? String {
                    await MainActor.run { self.streamedText += delta }
                }
            }

            await MainActor.run {
                self.history.append(.init(role: .user, text: userText))
                self.history.append(.init(role: .assistant, text: self.streamedText))
                self.trimHistoryIfNeeded()
            }
        } catch {
            print("[AINPCChatService] SSE stream error: \(error)")
        }
    }

    @MainActor
    private func trimHistoryIfNeeded() {
        if history.count > 8 {
            history.removeFirst(history.count - 8)
        }
    }

    #if canImport(FirebaseAuth)
    private func currentIDToken() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            #if canImport(FirebaseCore)
            guard FirebaseApp.app() != nil else {
                cont.resume(throwing: NSError(domain: "AINPCChatService", code: 503, userInfo: [NSLocalizedDescriptionKey: "Firebase is not configured"]))
                return
            }
            #endif
            guard let user = Auth.auth().currentUser else {
                cont.resume(throwing: NSError(domain: "AINPCChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No signed-in user"]))
                return
            }
            user.getIDToken { token, error in
                if let error = error { cont.resume(throwing: error) }
                else if let token = token { cont.resume(returning: token) }
                else {
                    cont.resume(throwing: NSError(domain: "AINPCChatService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No token"]))
                }
            }
        }
    }
    #endif
}
