# Noum

This app demonstrates speech recognition with filler word highlighting using
the [Deepgram](https://deepgram.com/) streaming API.

Provide your Deepgram API key via the `DEEPGRAM_API_KEY` environment variable
or by creating a `Deepgram.plist` file (see `Deepgram.plist.example`) in the
`Noum` folder. The app connects to Deepgram over WebSockets and streams audio
from the microphone to get real-time transcripts. Filler words are counted and
highlighted in the UI.

Common disfluencies such as "umm" or "hmm" are detected using a regex so
variants are matched dynamically.

Each recording session is saved with the total filler count and duration. Use
the **History** button to review previous sessions.

Set the environment variable or add the plist file, then build the Xcode
project to run the demo.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI which is only available on Apple platforms.
