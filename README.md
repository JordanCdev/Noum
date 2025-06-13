# Noum

This app demonstrates speech recognition with filler word highlighting using
the [Deepgram](https://deepgram.com/) streaming API.

Update `SpeechRecognizerViewModel.swift` with your Deepgram API key. The app
connects to Deepgram over WebSockets and streams audio from the microphone to
get real-time transcripts. Filler words are counted and highlighted in the UI.

Common disfluencies such as "umm" or "hmm" are detected using a regex so
variants are matched dynamically.

Each recording session is saved with the total filler count and duration. Use
the **History** button to review previous sessions.

Add your API key and build the Xcode project to run the demo.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI which is only available on Apple platforms.
