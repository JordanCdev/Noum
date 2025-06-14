# Noum

This app demonstrates speech recognition with filler word highlighting using

Amazon Transcribe for streaming speech recognition.

Configure the app with a Cognito Identity Pool using the
`COGNITO_IDENTITY_POOL_ID` environment variable (or a matching value in a
`Transcribe.plist` file) and optionally `AWS_REGION` to override the default
`eu-west-2` region. The app authenticates via Cognito and supports Google or
Apple sign‑in. Temporary credentials retrieved from Cognito are used to sign the
WebSocket request to Amazon Transcribe.

To use Amazon Transcribe you must configure an Amazon Cognito Identity Pool.
Provide its ID using the `COGNITO_IDENTITY_POOL_ID` variable or
`Transcribe.plist` file. Authentication is performed via Google or Apple login
and the retrieved temporary credentials are used to sign the WebSocket request.

Common disfluencies such as "umm" or "hmm" are detected using a regex so
variants are matched dynamically.

Each recording session is saved with the total filler count and duration. Use
the **History** button to review previous sessions.

After supplying the credentials, build the Xcode project to run the demo.

## Requirements

Building Noum requires Xcode 15 or later with Swift 6.1 or newer. The package
manifest uses tools version 6.0 for compatibility, but the app depends on
SwiftUI which is only available on Apple platforms.
