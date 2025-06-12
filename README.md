# Noum

Noum is a simple iOS app that highlights filler words in live speech. It uses
`SpeechRecognizerViewModel` to transcribe audio and mark filler words in red so
you can see and count them while practicing.

## Building the App

1. Install Xcode 15 or later.
2. Clone this repository and open `Noum.xcodeproj` in Xcode.
3. Choose a simulator or your iOS device and press **Run** (⌘R).

No additional dependencies are required.

## How Filler‑Word Detection Works

`SpeechRecognizerViewModel` listens to the microphone with `AVAudioEngine` and
transcribes the audio using the `Speech` framework. After every update the
method `highlightAndCountFillerWords(in:)` searches the transcript for any word
in `fillerWords` and colors the matches red. The total number of matches is
stored in `fillerWordCount`.

## Modifying the `fillerWords` List

Open `SpeechRecognizerViewModel.swift` and edit the array defined near the top
of the file:

```swift
private let fillerWords = ["um", "uh", "er", "eh", "ah", "like", "so", "you know"]
```

Add or remove strings to customize which words are flagged as fillers.

## Contextual Strings

If you add support for `contextualStrings` on `SFSpeechAudioBufferRecognitionRequest`,
you can supply additional hints to improve recognition accuracy. Insert your own
strings when creating the request in `startRecording()`.
