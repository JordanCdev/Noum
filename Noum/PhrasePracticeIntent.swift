import Foundation

/// A transient bridge from one explicitly saved phrase into the existing
/// Timed Practice prompt handoff. This value owns no persistence and carries
/// no source transcript or session metadata.
@available(iOS 17.0, macOS 12.0, *)
struct PhrasePracticeIntent: Equatable {
    static let promptPrefix = "Say this line in your own voice: "
    static let maximumSuggestedPromptCharacters =
        promptPrefix.count + PhraseBankStore.maximumTextCharacters

    let sourceEntryID: UUID
    let suggestedPrompt: String

    init?(entry: PhraseBankEntry) {
        guard let phrase = PhraseBankStore.sanitizedText(entry.text) else {
            return nil
        }

        let prompt = Self.promptPrefix + phrase
        guard prompt.count <= Self.maximumSuggestedPromptCharacters else {
            return nil
        }

        sourceEntryID = entry.id
        suggestedPrompt = prompt
    }
}
