//
//  PracticeMicrophonePermissionStateTests.swift
//  NoumTests
//
//  Keeps Timed/Impromptu practice honest when microphone access is not usable.
//

import Foundation
import Testing
@testable import Noum

#if canImport(AVFoundation)
@Suite("PracticeMicrophonePermissionState")
struct PracticeMicrophonePermissionStateTests {
    @Test func deniedBlocksRecordingAndExplainsSettingsRecovery() {
        #expect(PracticeMicrophonePermissionState.denied.blocksRecording)
        #expect(
            PracticeMicrophonePermissionState.denied.userFacingRecoveryMessage?
                .contains("Open iOS Settings") == true
        )
    }

    @Test func unknownBlocksRecordingWithDeviceRecovery() {
        #expect(PracticeMicrophonePermissionState.unknown.blocksRecording)
        #expect(
            PracticeMicrophonePermissionState.unknown.userFacingRecoveryMessage?
                .contains("audio route") == true
        )
    }

    @Test func undeterminedAndGrantedDoNotBlockPreflight() {
        #expect(!PracticeMicrophonePermissionState.undetermined.blocksRecording)
        #expect(!PracticeMicrophonePermissionState.granted.blocksRecording)
        #expect(PracticeMicrophonePermissionState.undetermined.userFacingRecoveryMessage == nil)
        #expect(PracticeMicrophonePermissionState.granted.userFacingRecoveryMessage == nil)
    }
}
#endif
