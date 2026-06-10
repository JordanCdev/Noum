//
//  LiveTranscriptStyle.swift
//  Noum
//
//  A3-in-rep-presence: calm in-rep transcript treatment.
//
//  `SpeechRecognizerViewModel.highlightedText` marks confirmed fillers in
//  red — the honest ledger the post-rep summary is built on, and it must
//  stay untouched (it is persisted into `SummaryDataStore.Entry.transcript`).
//
//  Painting that same red WHILE the user is mid-rep is live mistake-marking
//  during performance: it invites mid-flight self-monitoring — the exact
//  habit the coaching is trying to train away — and it is the one moment
//  the never-punish-shame rule matters most. So live in-rep surfaces render
//  through `calmed(_:)`: fillers stay *marked* (dimmed, visibly different
//  from the surrounding line — no information is hidden) but neutral.
//  The red read belongs to the summary, reviewed after the performance.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
enum LiveTranscriptStyle {

    /// Quiet in-rep marking for confirmed fillers: dimmed, never alarmed.
    /// `Color.secondary` keeps the mark legible on both the light card
    /// transcript layout and any future dark surface.
    static let liveFillerColor = Color.secondary.opacity(0.55)

    /// Returns a copy of the VM's red-marked transcript with every colored
    /// run re-marked as a dim, neutral acknowledgment. Pure attribute
    /// transform — the text content is never changed, and the source
    /// value (the summary's red ledger) is left untouched.
    static func calmed(_ text: AttributedString) -> AttributedString {
        var calmed = text

        // Collect marked ranges first, then rewrite. The VM applies its
        // highlight via NSAttributedString's `.foregroundColor` (UIKit
        // scope after bridging); check the SwiftUI scope too so the
        // transform stays correct if the VM ever migrates.
        let markedRanges = calmed.runs.compactMap { run -> Range<AttributedString.Index>? in
            var isMarked = run.swiftUI.foregroundColor != nil
            #if canImport(UIKit)
            isMarked = isMarked || run.uiKit.foregroundColor != nil
            #endif
            return isMarked ? run.range : nil
        }

        for range in markedRanges {
            #if canImport(UIKit)
            calmed[range].uiKit.foregroundColor = nil
            #endif
            calmed[range].swiftUI.foregroundColor = liveFillerColor
        }
        return calmed
    }
}
#endif
