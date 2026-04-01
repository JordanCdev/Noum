import Foundation
import Combine
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

public final class AINPCChatService: ObservableObject {
    public enum Role: String {
        case user, assistant, system
    }

    public struct Message {
        public let role: Role
        public let text: String
    }

    @Published public private(set) var history: [Message] = []

    private var streamURL: URL? {
        #if canImport(FirebaseRemoteConfig)
        if let s = RemoteConfig.remoteConfig()["ai_stream_url"].stringValue, !s.isEmpty {
            return URL(string: s)
        }
        #endif
        return nil
    }

    public init() {}

    private let systemPrompt = "You are a helpful AI assistant."
    private let modelName = "default-model"
    @Published public private(set) var streamedText: String = ""

    public func sendStreaming(_ userText: String) async {
        // Prefer SSE fallback if a stream URL is provided via Remote Config
        if let _ = streamURL {
            await streamViaSSE(userText)
            return
        }

        // PSEUDOCODE – replace with actual AI Logic SDK usage when added to the project
        // let provider = AILogic.vertex(projectID: <#ProjectID#>, location: "us-central1")
        // let model = provider.model(named: modelName)
        // let chat = model.startChat(systemPrompt: systemPrompt, history: history.map { .init(role: $0.role.rawValue, text: $0.text) })
        // do {
        //     for try await chunk in chat.sendMessageStream(userText) {
        //         if let t = chunk.text { await MainActor.run { self.streamedText += t } }
        //     }
        // } catch { print("[AINPCChatService] stream error: \(error)") }

        // Update local history with whatever we streamed
        await MainActor.run {
            self.history.append(.init(role: .user, text: userText))
            self.history.append(.init(role: .assistant, text: self.streamedText))
            if self.history.count > 8 { self.history.removeFirst(self.history.count - 8) }
        }
    }

    private func streamViaSSE(_ userText: String) async {
        guard let url = streamURL else { return }

        // Build messages: include system prompt and recent history
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

            // Update history with streamed result
            await MainActor.run {
                self.history.append(.init(role: .user, text: userText))
                self.history.append(.init(role: .assistant, text: self.streamedText))
                if self.history.count > 8 { self.history.removeFirst(self.history.count - 8) }
            }
        } catch {
            print("[AINPCChatService] SSE stream error: \(error)")
        }
    }

    #if canImport(FirebaseAuth)
    private func currentIDToken() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
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
