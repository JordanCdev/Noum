import Foundation
import Testing

@Suite("V3 secondary-mode presentation")
struct V3SecondaryModesPresentationTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    @Test("Secondary modes use semantic identities and reserve waveforms for live audio")
    func graphicSemanticsMatchVisibleState() throws {
        let lessonsHome = try source("Noum/LessonsHomeView.swift")
        #expect(lessonsHome.contains("NoumSemanticGraphic(role: .learning"))
        #expect(lessonsHome.contains("graphicRole: .learning"))
        #expect(!lessonsHome.contains("NoumWaveformMark("))

        let roleplaySetup = try source("Noum/RoleplaySetupView.swift")
        #expect(roleplaySetup.contains("NoumSemanticGraphic(role: .roleplay"))
        #expect(roleplaySetup.contains("Image(systemName: \"person.2.fill\")"))
        #expect(!roleplaySetup.contains("NoumWaveformMark("))

        let imPractice = try source("Noum/IMPracticeView.swift")
        #expect(imPractice.contains("role: .roleplay"))
        #expect(imPractice.contains("NoumSemanticGraphicRole.roleplay.systemName"))
        #expect(!imPractice.contains("NoumWaveformMark("))
        #expect(!imPractice.contains("message.badge.waveform"))

        let lesson = try source("Noum/LessonView.swift")
        #expect(lesson.contains("NoumSemanticGraphic(role: .learning"))
        #expect(lesson.contains("NoumWaveformMark("))
        #expect(lesson.contains("state: .listening"))
        #expect(!lesson.contains("state: .earned"))

        let roleplay = try source("Noum/RoleplayView.swift")
        #expect(roleplay.contains("role: .roleplay"))
        #expect(roleplay.contains("NoumSemanticGraphic(role: .practice"))
        #expect(roleplay.contains("NoumWaveformMark("))
        #expect(roleplay.contains("state: .listening"))
        #expect(roleplay.contains("case .completed(let transcript):"))
        #expect(roleplay.contains("if transcript.hasUsableSpeech"))
        #expect(roleplay.contains("role: .evidenceSaved"))
        #expect(roleplay.contains("role: .needsAttention"))
        #expect(!roleplay.contains("state: .earned"))

        let fillerControl = try source("Noum/AhCounterView.swift")
        #expect(fillerControl.contains("NoumSemanticGraphic(role: .practice"))
        #expect(fillerControl.contains("NoumWaveformMark("))
        #expect(fillerControl.contains("state: .listening"))
        #expect(fillerControl.contains("state: .processing"))
        #expect(!fillerControl.contains("NoumWaveformMark(state: .idle"))
        #expect(!fillerControl.contains("ear.and.waveform"))

        let pathsWithoutMascotsOrAmbientLoops = [
            "Noum/LessonsHomeView.swift",
            "Noum/LessonView.swift",
            "Noum/RoleplaySetupView.swift",
            "Noum/RoleplayView.swift",
            "Noum/AhCounterView.swift",
            "Noum/IMPracticeView.swift",
            "Noum/SuddenDeathPracticeView.swift",
            "Noum/CutTheCrutchView.swift",
        ]

        for path in pathsWithoutMascotsOrAmbientLoops {
            let body = try source(path)
            #expect(!body.contains("NoumCharacter("), Comment(rawValue: path))
            #expect(!body.contains("repeatForever"), Comment(rawValue: path))
        }
    }

    @Test("Lesson progress remains downstream of accepted spoken evidence")
    func lessonTruthGatePrecedesProgress() throws {
        let body = try source("Noum/LessonView.swift")
        let finalization = try #require(body.range(of: "await speech.stopRecordingAwaitingFinalization()"))
        let disposition = try #require(body.range(of: "LessonApplyCompletionDisposition.resolve("))
        let evidence = try #require(body.range(of: "applyEvidence = evidence"))
        let progress = try #require(body.range(of: "lessonStore.apply(outcome: final)"))

        #expect(finalization.lowerBound < disposition.lowerBound)
        #expect(disposition.lowerBound < evidence.lowerBound)
        #expect(evidence.lowerBound < progress.lowerBound)
        #expect(body.contains("No practice pass added"))
    }

    @Test("Roleplay only evaluates a finalized recording")
    func roleplayTruthGatePrecedesEvaluation() throws {
        let body = try source("Noum/RoleplayView.swift")
        let finalization = try #require(body.range(of: "await speechVM.stopRecordingAwaitingFinalization()"))
        let gate = try #require(body.range(of: "RecordingCompletionGate.allowsScoringAndProgress(completion)"))
        let evaluation = try #require(body.range(of: "submitTurn()", range: gate.upperBound..<body.endIndex))
        let durableRecord = try #require(body.range(of: "RoleplayStore.shared.record("))

        #expect(finalization.lowerBound < gate.lowerBound)
        #expect(gate.lowerBound < evaluation.lowerBound)
        #expect(evaluation.lowerBound < durableRecord.lowerBound)
    }

    @Test("Filler Control keeps scoring behind finalization and exposes typed recovery")
    func fillerControlTruthAndRecoveryStayVisible() throws {
        let body = try source("Noum/AhCounterView.swift")
        let finalization = try #require(body.range(of: "await speechVM.stopRecordingAwaitingFinalization()"))
        let gate = try #require(body.range(of: "RecordingCompletionGate.allowsScoringAndProgress(completion)"))
        let evaluation = try #require(body.range(of: "PracticeEvaluator.evaluateAhCounterPractice("))
        let annotation = try #require(body.range(of: "speechVM.annotateLatestSession("))

        #expect(finalization.lowerBound < gate.lowerBound)
        #expect(gate.lowerBound < evaluation.lowerBound)
        #expect(evaluation.lowerBound < annotation.lowerBound)
        #expect(body.contains("case .openSettings:"))
        #expect(body.contains("case .grantCloudConsent:"))
        #expect(body.contains("case .leaveRep:"))
        #expect(body.contains("No score or XP is created until a usable recording finishes."))
    }
}
