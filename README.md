# Noum

This app demonstrates speech recognition with filler word highlighting.
It supports Apple's `Speech` framework and optional transcription using the
[WhisperKit](https://github.com/argmaxinc/WhisperKit) library for on-device
Whisper models.

## WhisperKit

To enable Whisper-based recognition, toggle **Use Whisper** in the UI. The first
recording initializes `WhisperKit`, which will automatically download a
compatible model for the device. The toggle remains disabled until initialization
finishes, and any failure is printed to the console.

Add `https://github.com/argmaxinc/WhisperKit.git` as a Swift Package dependency
in Xcode to build with Whisper support.
