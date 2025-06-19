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
        #if canImport(AVFoundation)
        let vm = await SpeechRecognizerViewModel()
        await vm.highlightAndCountFillerWords(in: "errr well uhhhh")
        try await Task.sleep(nanoseconds: 50_000_000)
        let count1 = await vm.fillerWordCount
        #else
        let count1 = FillerWordDetector.count(in: "errr well uhhhh")
        #endif
        #expect(count1 == 2)
    }

    /// Verify that a mix of base filler words and dynamic variants are all
    /// counted in the transcript.
    @Test func mixedFillerWordsCount() async throws {
        #if canImport(AVFoundation)
        let vm = await SpeechRecognizerViewModel()
        await vm.highlightAndCountFillerWords(in: "like so you know errr uhhhh")
        try await Task.sleep(nanoseconds: 50_000_000)
        let count2 = await vm.fillerWordCount
        #else
        let count2 = FillerWordDetector.count(in: "like so you know errr uhhhh")
        #endif
        #expect(count2 == 5)
    }

    /// Ensure newer filler words such as "hmm" and "erm" are detected.
    @Test func additionalFillerWords() async throws {
        #if canImport(AVFoundation)
        let vm = await SpeechRecognizerViewModel()
        await vm.highlightAndCountFillerWords(in: "hmm erm mm")
        try await Task.sleep(nanoseconds: 50_000_000)
        let count3 = await vm.fillerWordCount
        #else
        let count3 = FillerWordDetector.count(in: "hmm erm mm")
        #endif
        #expect(count3 == 3)
    }
}
