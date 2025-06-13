# Noum

This app demonstrates speech recognition with filler word highlighting using
Amazon Transcribe for streaming speech recognition.

Supply your AWS credentials via the `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, and optional `AWS_SESSION_TOKEN` environment variables
or a `Transcribe.plist` file (see `Transcribe.plist.example`). The region
defaults to `us-east-1` but can be overridden with an `AWS_REGION` key. The app
will construct a SigV4-signed WebSocket request and stream audio to Transcribe.

Common disfluencies such as "umm" or "hmm" are detected using a regex so
variants are matched dynamically.

Each recording session is saved with the total filler count and duration. Use
the **History** button to review previous sessions.

After supplying the credentials, build the Xcode project to run the demo.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI which is only available on Apple platforms.
