import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

struct CoachChatWireMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

struct CoachChatRequest: Codable, Sendable, Equatable {
    static let schemaVersion = 1
    static let maxContextCharacters = 12_000
    static let maxMessageCharacters = 4_000
    static let totalMessageCharacterBudget = 19_000

    let schemaVersion: Int
    let requestID: String
    let surface: String
    let qualityTier: String
    let coachingContext: String
    let messages: [CoachChatWireMessage]

    init(
        requestID: UUID = UUID(),
        surface: String,
        qualityTier: String,
        coachingContext: String,
        messages: [CoachChatWireMessage]
    ) {
        self.schemaVersion = Self.schemaVersion
        self.requestID = requestID.uuidString
        self.surface = surface
        self.qualityTier = qualityTier
        self.coachingContext = Self.boundedContext(coachingContext)
        self.messages = Self.boundedMessages(messages)
    }

    private static func boundedContext(_ value: String) -> String {
        guard value.count > maxContextCharacters else { return value }
        let separator = "\n…\n"
        let remaining = maxContextCharacters - separator.count
        let headCount = remaining / 2
        let tailCount = remaining - headCount
        return String(value.prefix(headCount)) + separator + String(value.suffix(tailCount))
    }

    private static func boundedMessages(_ values: [CoachChatWireMessage]) -> [CoachChatWireMessage] {
        var budget = totalMessageCharacterBudget
        var newestFirst: [CoachChatWireMessage] = []

        for message in values.suffix(12).reversed() {
            guard budget > 0 else { break }
            let clean = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let limit = min(maxMessageCharacters, budget)
            let content = clean.count <= limit
                ? clean
                : String(clean.prefix(max(1, limit - 1))) + "…"
            newestFirst.append(CoachChatWireMessage(role: message.role, content: content))
            budget -= content.count
        }
        return newestFirst.reversed()
    }
}

struct CoachChatDelta: Codable, Sendable, Equatable {
    let type: String
    let requestID: String
    let text: String
}

struct CoachChatCompletion: Codable, Sendable, Equatable {
    let requestID: String
    let text: String
    let model: String
    let qualityTier: String
    let finishReason: String
    let inputTokens: Int?
    let outputTokens: Int?
}

enum CoachChatEvent: Sendable, Equatable {
    case delta(String)
    case completion(CoachChatCompletion)
}

enum CoachChatUnavailableReason: Sendable, Equatable {
    case authenticationPending
    case debugProviderMissing
    case service
}

enum CoachChatTransportAvailability: Sendable, Equatable {
    case checking
    case available
    case unavailable(CoachChatUnavailableReason)
}

enum CoachChatTransportError: Error, Sendable, Equatable {
    case serviceUnavailable
    case unauthenticated
    case rateLimited
    case cancelled
    case invalidResponse
    case network
}

protocol CoachChatTransport: Sendable {
    func availability() async -> CoachChatTransportAvailability
    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error>
}

struct FirebaseCoachChatTransport: CoachChatTransport {
    static let region = "europe-west2"
    static let functionName = "coachChat"
    static let availabilityFunctionName = "coachChatAvailability"

    private struct AvailabilityRequest: Encodable {
        let schemaVersion = CoachChatRequest.schemaVersion
        let requestID = UUID().uuidString
    }

    private struct AvailabilityResponse: Decodable {
        let available: Bool
    }

    func availability() async -> CoachChatTransportAvailability {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        guard FirebaseApp.app() != nil, Auth.auth().currentUser != nil else {
            return .unavailable(.authenticationPending)
        }
        do {
            let functions = Functions.functions(region: Self.region)
            let callable: Callable<AvailabilityRequest, AvailabilityResponse> = functions
                .httpsCallable(Self.availabilityFunctionName)
            let response = try await callable.call(AvailabilityRequest())
            return response.available ? .available : .unavailable(.service)
        } catch {
            return .unavailable(.service)
        }
        #else
        return .unavailable(.service)
        #endif
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        #if canImport(FirebaseFunctions)
        typealias Response = StreamResponse<CoachChatDelta, CoachChatCompletion>
        let functions = Functions.functions(region: Self.region)
        let callable: Callable<CoachChatRequest, Response> = functions.httpsCallable(Self.functionName)
        let upstream = try callable.stream(request)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await response in upstream {
                        switch response {
                        case .message(let message):
                            guard message.type == "delta", message.requestID == request.requestID else {
                                continue
                            }
                            continuation.yield(.delta(message.text))
                        case .result(let result):
                            guard result.requestID == request.requestID else {
                                throw CoachChatTransportError.invalidResponse
                            }
                            continuation.yield(.completion(result))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CoachChatTransportError.cancelled)
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        throw CoachChatTransportError.serviceUnavailable
        #endif
    }

    #if canImport(FirebaseFunctions)
    private static func map(_ error: Error) -> CoachChatTransportError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .network
        }
        switch code {
        case .unauthenticated: return .unauthenticated
        case .resourceExhausted: return .rateLimited
        case .cancelled: return .cancelled
        case .unavailable, .deadlineExceeded: return .serviceUnavailable
        default: return .network
        }
    }
    #endif
}

#if DEBUG
/// Debug-only adapter used by the existing direct-provider chain. It accepts
/// an injected operation so no provider key or vendor SDK leaks into the
/// production transport surface.
struct DirectProviderDebugTransport: CoachChatTransport {
    typealias Operation = @Sendable (CoachChatRequest) async throws -> CoachChatCompletion

    let isConfigured: @Sendable () -> Bool
    let operation: Operation

    func availability() async -> CoachChatTransportAvailability {
        isConfigured() ? .available : .unavailable(.debugProviderMissing)
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.completion(try await operation(request)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
