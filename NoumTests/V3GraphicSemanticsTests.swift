import Foundation
import Testing

@Suite("V3 graphic semantics")
struct V3GraphicSemanticsTests {
    @Test("Waveform rendering is limited to voice state and the Today handoff")
    func waveformCallsitesStayAudioBound() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appRoot = repositoryRoot.appendingPathComponent("Noum")
        let expectedCallsites = [
            "AhCounterView.swift": 2,
            "AskNoumView.swift": 1,
            "CutTheCrutchView.swift": 1,
            "HomeCoachCard.swift": 1,
            "LessonView.swift": 1,
            "LiveCoachCallView.swift": 1,
            "RoleplayView.swift": 1,
            "SuddenDeathPracticeView.swift": 1,
            "TimedPracticeView.swift": 2,
        ]

        let enumerator = try #require(
            FileManager.default.enumerator(
                at: appRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        )
        var foundCallsites: [String: Int] = [:]

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let count = source.components(separatedBy: "NoumWaveformMark(").count - 1
            guard count > 0 else { continue }
            foundCallsites[url.lastPathComponent] = count
        }

        #expect(foundCallsites == expectedCallsites)

        let requiredVoiceContext = [
            "AhCounterView.swift": ["state: .listening", "state: .processing", "speechVM.audioLevel"],
            "AskNoumView.swift": ["state: .listening", "if isRecording"],
            "CutTheCrutchView.swift": ["speechVM.isRecording ? .listening : .idle", "speechVM.audioLevel"],
            "HomeCoachCard.swift": ["one non-live waveform allowed outside capture", "heroHandoff ? .listening : .idle"],
            "LessonView.swift": ["state: .listening", "speech.audioLevel"],
            "LiveCoachCallView.swift": ["voiceInput.state == .recording", "store.isAwaitingReply", "Button(action: micTapped)"],
            "RoleplayView.swift": ["case .recording:", "responseWaveform(state: .listening", "case .connecting, .finalizing:", "responseWaveform(state: .processing"],
            "SuddenDeathPracticeView.swift": ["speechVM.isRecording ? .listening : .idle", "speechVM.audioLevel"],
            "TimedPracticeView.swift": ["speechVM.isRecording ? .listening : .idle", "state: .processing", "speechVM.audioLevel"],
        ]
        for (filename, fragments) in requiredVoiceContext {
            let content = try source("Noum/\(filename)")
            for fragment in fragments {
                #expect(content.contains(fragment), Comment(rawValue: "\(filename) missing \(fragment)"))
            }
            #expect(!content.contains("state: .earned"))
        }
    }

    @Test("High-frequency product surfaces use distinct graphic roles")
    func keySurfacesDoNotReuseWaveformAsChrome() throws {
        let sources = try [
            source("Noum/AppShellView.swift"),
            source("Noum/CoachingMemoryView.swift"),
            source("Noum/CoachingOnboardingView.swift"),
            source("Noum/FastLaneOnboardingView.swift"),
            source("Noum/FirstRepCelebration.swift"),
            source("Noum/PracticeModeSelectionView.swift"),
            source("Noum/SessionHistoryView.swift"),
            source("Noum/SettingsView.swift"),
            source("Noum/SummaryView.swift"),
            source("Noum/TranscriptPracticeLoop.swift"),
            source("ProfileView.swift"),
        ]

        for content in sources {
            #expect(!content.contains("NoumWaveformMark("))
        }

        let firstRep = try source("Noum/FirstRepCelebration.swift")
        #expect(firstRep.contains("role: .milestone"))
        #expect(firstRep.contains("pieceCount: NoumMotionMetric.maximumEarnedParticles"))
        #expect(!firstRep.contains("NoumCharacter("))
        #expect(!firstRep.contains("repeatForever"))
        #expect(firstRep.contains("@State private var sequenceTask: Task<Void, Never>?"))
        #expect(firstRep.contains("sequenceTask?.cancel()"))
        #expect(firstRep.contains("settleSequenceWithoutFeedback()"))
        #expect(firstRep.contains("guard scenePhase == .active else"))
        #expect(firstRep.contains("if newPhase == .active"))
        #expect(!firstRep.contains("DispatchQueue.main.asyncAfter"))

        let askNoum = try source("Noum/AskNoumView.swift")
        #expect(askNoum.contains("private func provisionalCoachRead"))
        #expect(askNoum.contains("private var pendingDots"))
        #expect(askNoum.contains("role: .coachRead"))

        let coachRead = try source("Noum/CoachReadCard.swift")
        #expect(!coachRead.contains("NoumWaveformMark("))
        #expect(coachRead.contains("private var insightLoadingState"))
        #expect(coachRead.contains("role: .progressTrajectory"))
    }

    private func source(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
