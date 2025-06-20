# Noum

This app demonstrates speech recognition with filler word highlighting using

Amazon Transcribe for streaming speech recognition.

Configure the app with AWS credentials using the environment variables
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (plus `AWS_SESSION_TOKEN` if
you are using temporary credentials). A `Transcribe.plist` file can also provide
these values when running on Apple platforms. The region defaults to
`eu-west-2` but can be overridden with the `AWS_REGION` variable. The
Settings screen includes a **Refresh** button to reload credentials from these
locations.

Supply AWS credentials either through environment variables or a matching
`Transcribe.plist` file. These credentials are used to sign the WebSocket
request to Amazon Transcribe.

Common disfluencies such as "umm" or "hmm" are detected using a regex so
variants are matched dynamically.

Each recording session is saved with the total filler count and duration. Use
the **History** button to review previous sessions.

After supplying the credentials, build the Xcode project to run the demo.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI which is only available on Apple platforms.
