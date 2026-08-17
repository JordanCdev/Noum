from pathlib import Path
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class VideoAnalysisReleaseContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.premium = (REPOSITORY_ROOT / "Noum/PremiumManager.swift").read_text(
            encoding="utf-8"
        )
        cls.summary = (REPOSITORY_ROOT / "Noum/SummaryView.swift").read_text(
            encoding="utf-8"
        )
        practice = (REPOSITORY_ROOT / "Noum/PracticeSupport.swift").read_text(
            encoding="utf-8"
        )
        cls.service = practice.split(
            "final class VideoAnalysisService {", 1
        )[1].split("\n#endif", 1)[0]

    def test_release_surface_fails_closed_without_secure_authority(self) -> None:
        self.assertIn(
            "nonisolated static let secureVideoAnalysisAuthorityAvailable = false",
            self.premium,
        )
        self.assertIn(
            "isPremium && Self.videoAnalysisAvailableInCurrentBuild",
            self.premium,
        )
        self.assertIn(
            "if PremiumManager.videoAnalysisAvailableInCurrentBuild {",
            self.premium,
        )
        self.assertIn("if premium.canUseVideoAnalysis {", self.summary)
        self.assertNotIn("if premium.isPremium {\n                            videoAnalysisSection", self.summary)

    def test_retired_device_credit_ledger_cannot_authorize_or_charge(self) -> None:
        banned_runtime_symbols = (
            "videoAnalysisCreditsRemaining",
            "monthlyVideoAnalysisLimit",
            "consumeVideoAnalysisCredit",
            "resetCreditsIfNeeded",
        )
        for symbol in banned_runtime_symbols:
            self.assertNotIn(symbol, self.premium)

        self.assertIn("retiredVideoAnalysisCreditKeys", self.premium)
        self.assertIn("purgeRetiredVideoAnalysisCreditState", self.premium)

    def test_service_coalesces_duplicates_and_caches_only_accepted_result(self) -> None:
        self.assertIn("inFlightAnalyses", self.service)
        self.assertIn("completedAnalyses", self.service)
        self.assertGreaterEqual(
            self.service.count("usageAccounting: .informational"), 2
        )
        self.assertIn("return try await inFlight.value", self.service)
        self.assertIn("cacheAccepted(result, for: recordingKey)", self.service)
        self.assertIn("inFlightAnalyses[recordingKey] = nil", self.service)

        normalized = self.service.index(
            "guard let normalized = VideoAnalysisContract.normalized(result)"
        )
        charged = self.service.index("settings.recordAnalysis()")
        cached = self.service.index("cacheAccepted(result, for: recordingKey)")
        self.assertLess(normalized, charged)
        self.assertEqual(self.service.count("settings.recordAnalysis()"), 1)
        self.assertLess(charged, self.service.index("return normalized", charged))
        self.assertLess(cached, self.service.index("return result", cached))

    def test_summary_single_flight_gate_preserves_failure_retry(self) -> None:
        self.assertGreaterEqual(
            self.summary.count("VideoAnalysisRequestGate.canStart("), 2
        )
        self.assertIn("isInFlight: isAnalyzingVideo", self.summary)
        self.assertIn("hasAcceptedResult: videoAnalysisResult != nil", self.summary)
        self.assertIn("isAnalyzingVideo = false", self.summary)
        self.assertIn("if videoAnalysisResult == nil {", self.summary)


if __name__ == "__main__":
    unittest.main()
