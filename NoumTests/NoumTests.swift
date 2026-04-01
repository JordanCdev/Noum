//
//  NoumTests.swift
//  NoumTests
//
//  Created by Jordan Coaten on 25/01/2025.
//

import Testing
@testable import Noum

struct NoumTests {

    /// Ensure that dynamic filler word variants like "errr" and "uhhhh" are
    /// detected by ``SpeechRecognizerViewModel``.
    @Test func dynamicVariantsAreCounted() async throws {
        let count1 = FillerWordDetector.count(in: "errr well uhhhh")
        #expect(count1 == 2)
    }

    /// Verify that a mix of base filler words and dynamic variants are all
    /// counted in the transcript.
    @Test func mixedFillerWordsCount() async throws {
        let count2 = FillerWordDetector.count(in: "like so you know errr uhhhh")
        #expect(count2 == 5)
    }

    /// Ensure newer filler words such as "hmm" and "erm" are detected.
    @Test func additionalFillerWords() async throws {
        let count3 = FillerWordDetector.count(in: "hmm erm mm")
        #expect(count3 == 3)
    }
}
