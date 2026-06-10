//
//  LiveTranscriptStyleTests.swift
//  NoumTests
//
//  A3-in-rep-presence: pins the calm in-rep transcript transform —
//  red filler marks become dim neutral marks on live surfaces, the
//  source value (the summary's red ledger) is never mutated, and the
//  text content survives the transform byte-for-byte.
//

import Foundation
import Testing
import SwiftUI
import UIKit
@testable import Noum

@Suite("LiveTranscriptStyle calm in-rep marking")
struct LiveTranscriptStyleTests {

    /// Builds a transcript the way the VM does: NSMutableAttributedString
    /// with `.foregroundColor: UIColor.red` on the filler range, bridged
    /// into AttributedString.
    private func vmStyleTranscript(_ text: String, redRange: NSRange) -> AttributedString {
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: redRange)
        return AttributedString(attributed)
    }

    @Test func textContentIsPreserved() {
        let source = vmStyleTranscript("so um I think we should ship", redRange: NSRange(location: 3, length: 2))
        let calmed = LiveTranscriptStyle.calmed(source)
        #expect(String(calmed.characters) == "so um I think we should ship")
    }

    @Test func redMarksAreReplacedWithDimMarks() {
        let source = vmStyleTranscript("so um I think", redRange: NSRange(location: 3, length: 2))
        let calmed = LiveTranscriptStyle.calmed(source)

        var foundDimMark = false
        for run in calmed.runs {
            // No UIKit red may survive on the live surface.
            #expect(run.uiKit.foregroundColor == nil)
            if run.swiftUI.foregroundColor != nil {
                foundDimMark = true
                // The mark must be the dim neutral token, not red.
                #expect(run.swiftUI.foregroundColor == LiveTranscriptStyle.liveFillerColor)
                #expect(String(calmed[run.range].characters) == "um")
            }
        }
        #expect(foundDimMark, "the filler must stay visibly marked — dimmed, not hidden")
    }

    @Test func unmarkedRunsStayUntouched() {
        let source = vmStyleTranscript("so um I think", redRange: NSRange(location: 3, length: 2))
        let calmed = LiveTranscriptStyle.calmed(source)
        for run in calmed.runs where String(calmed[run.range].characters) != "um" {
            #expect(run.swiftUI.foregroundColor == nil)
            #expect(run.uiKit.foregroundColor == nil)
        }
    }

    @Test func sourceLedgerIsNeverMutated() {
        let source = vmStyleTranscript("so um I think", redRange: NSRange(location: 3, length: 2))
        _ = LiveTranscriptStyle.calmed(source)

        // The summary's red ledger must keep its red mark.
        let stillRed = source.runs.contains { run in
            run.uiKit.foregroundColor == UIColor.red
        }
        #expect(stillRed, "calming must be a copy-side transform — the persisted artifact keeps the red read")
    }

    @Test func plainTranscriptPassesThroughUnchanged() {
        let source = AttributedString("clean take with zero fillers")
        let calmed = LiveTranscriptStyle.calmed(source)
        #expect(String(calmed.characters) == "clean take with zero fillers")
        for run in calmed.runs {
            #expect(run.swiftUI.foregroundColor == nil)
            #expect(run.uiKit.foregroundColor == nil)
        }
    }

    @Test func multipleFillerMarksAllCalm() {
        let text = "um so like I mean"
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: 2))   // "um"
        attributed.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 6, length: 4))   // "like"
        let calmed = LiveTranscriptStyle.calmed(AttributedString(attributed))

        var dimMarkCount = 0
        for run in calmed.runs {
            #expect(run.uiKit.foregroundColor == nil)
            if run.swiftUI.foregroundColor == LiveTranscriptStyle.liveFillerColor {
                dimMarkCount += 1
            }
        }
        #expect(dimMarkCount == 2)
        #expect(String(calmed.characters) == text)
    }
}
