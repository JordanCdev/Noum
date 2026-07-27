import Foundation
import Testing

/// A ratchet on hardcoded text ink.
///
/// `ColorContrastGuardTests` validates the token system. It would NOT have
/// caught the bug that motivated both files: `CoachingOnboardingView` used a
/// hardcoded `Color(red: 0.14, green: 0.16, blue: 0.21)` as text ink on
/// `AppColor.innerSurface`, and a literal is invisible to a token audit by
/// definition. 1.01:1 in Dark appearance, on the first interactive screen in the
/// product. Eighteen such literals accumulated in one file over time, one commit
/// at a time, with nothing objecting.
///
/// The rule is narrow on purpose. A hardcoded FILL is usually fine — the Path
/// landscape's sky gradients, achievement badge tints and the immersive backdrop
/// tints are deliberate, fixed, decorative surfaces, and there are ~120 of them.
/// A hardcoded FOREGROUND is the dangerous case, because text has to contrast
/// with whatever sits behind it, and an adaptive surface moves in Dark mode while
/// a literal does not.
///
/// Existing sites are allowlisted with a reason rather than silently tolerated.
/// The allowlist records that they were reviewed — each is ink on a FIXED
/// surface (a white capsule, an always-dark focused practice backdrop), where a
/// literal is correct and a semantic token would be wrong. Adding a new
/// hardcoded ink fails this test; if it is genuinely ink on a fixed surface, add
/// it here with its reason.
@Suite("Hardcoded ink lint")
struct HardcodedInkLintTests {

    /// Reviewed exceptions: file basename -> why a literal is correct there.
    static let allowed: [String: String] = [
        // Error-status glyph on the always-dark focused practice surface. The
        // scaffold sets `.preferredColorScheme(.dark)`, so this never meets a
        // light background.
        "FocusedPracticeScaffold.swift": "coral glyph on the fixed dark focused-practice surface",
        // Two button labels that sit on fixed WHITE capsules (the recording
        // issue card's primary action and the immersive Start Now pill). The
        // capsule is `.white` regardless of appearance, so the ink must be dark
        // in both modes — an adaptive token would invert and disappear.
        "TimedPracticeView.swift": "ink labels on fixed white capsules",
    ]

    /// Locates the repository from this file's compile-time path.
    static var repoRoot: URL? {
        URL(fileURLWithPath: #filePath)          // …/NoumTests/HardcodedInkLintTests.swift
            .deletingLastPathComponent()          // …/NoumTests
            .deletingLastPathComponent()          // repo root
            .standardizedFileURL as URL?
    }

    static func swiftSources(in root: URL) -> [URL] {
        let skipped = [".Codex", ".claude", "NoumTests", "NoumUITests", "functions", "DerivedData", "artifacts"]
        var found: [URL] = []
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            let path = url.path
            if skipped.contains(where: { path.contains("/\($0)/") || path.hasSuffix("/\($0)") }) {
                enumerator?.skipDescendants()
                continue
            }
            // Sibling worktrees (Noum-arena-agent, Noum-wt2, …) are other checkouts.
            if path.contains("/Noum-") { continue }
            if url.pathExtension == "swift" { found.append(url) }
        }
        return found
    }

    @Test("No new hardcoded colour is used as text ink")
    func noUnreviewedHardcodedInk() throws {
        let root = try #require(Self.repoRoot, "Could not derive the repo root from #filePath")
        let sources = Self.swiftSources(in: root)

        // Guard against a silent no-op: if the scan finds no Swift files the
        // rule would pass vacuously, which is the false-green this repo keeps
        // producing. A real checkout has hundreds.
        #expect(
            sources.count > 100,
            Comment(rawValue: "Only \(sources.count) Swift files scanned from \(root.path) — the lint is not actually reading the source tree, so a pass here proves nothing.")
        )

        var offenders: [String] = []
        for url in sources {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let name = url.lastPathComponent
            for (offset, line) in text.components(separatedBy: .newlines).enumerated() {
                guard line.contains("foregroundStyle(Color(red:")
                        || line.contains("foregroundColor(Color(red:") else { continue }
                if Self.allowed[name] != nil { continue }
                offenders.append("\(name):\(offset + 1) — \(line.trimmingCharacters(in: .whitespaces))")
            }
        }

        #expect(
            offenders.isEmpty,
            Comment(rawValue: """
            Hardcoded colour used as text ink. Text must contrast with an adaptive \
            surface, and a literal does not move between appearances — this is how \
            the onboarding screen reached 1.01:1 in Dark mode. Use an AppColor role, \
            or add the file to `allowed` with the reason the surface behind it is fixed:
            \(offenders.joined(separator: "\n"))
            """)
        )
    }

    /// The allowlist must not outlive its entries. If a file stops containing a
    /// hardcoded ink, its exemption should go too, so the list cannot quietly
    /// become a blanket permission for whole files.
    @Test("Allowlist entries still correspond to real sites")
    func allowlistHasNoStaleEntries() throws {
        let root = try #require(Self.repoRoot)
        let sources = Self.swiftSources(in: root)
        var stale: [String] = []
        for (name, reason) in Self.allowed {
            let matching = sources.filter { $0.lastPathComponent == name }
            let stillHasInk = matching.contains { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
                return text.contains("foregroundStyle(Color(red:")
                    || text.contains("foregroundColor(Color(red:")
            }
            if !stillHasInk {
                stale.append("\(name) — exemption no longer needed (\(reason))")
            }
        }
        #expect(
            stale.isEmpty,
            Comment(rawValue: "Stale allowlist entries:\n" + stale.joined(separator: "\n"))
        )
    }
}
