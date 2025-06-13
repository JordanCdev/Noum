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
        let vm = await SpeechRecognizerViewModel()
        await vm.highlightAndCountFillerWords(in: "errr well uhhhh")
        // Allow the asynchronous update on the main queue to complete.
        try await Task.sleep(nanoseconds: 50_000_000)
        let count1 = await vm.fillerWordCount
        #expect(count1 == 2)
    }

    /// Verify that a mix of base filler words and dynamic variants are all
    /// counted in the transcript.
    @Test func mixedFillerWordsCount() async throws {
        let vm = await SpeechRecognizerViewModel()
        await vm.highlightAndCountFillerWords(in: "like so you know errr uhhhh")
        try await Task.sleep(nanoseconds: 50_000_000)
        let count2 = await vm.fillerWordCount
        #expect(count2 == 5)
    }
}
