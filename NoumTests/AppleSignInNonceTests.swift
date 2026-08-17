import Security
import Testing
@testable import Noum

@Suite("Apple sign-in nonce")
struct AppleSignInNonceTests {
    @Test("Entropy failure is typed instead of terminating the process")
    func entropyFailureIsRecoverable() {
        #expect(throws: AppleSignInNonceError.entropyUnavailable(-50)) {
            try AppleSignInNonceGenerator.generate(length: 32) {
                throw AppleSignInNonceError.entropyUnavailable(-50)
            }
        }
    }

    @Test("Invalid lengths fail closed")
    func invalidLengthFailsClosed() {
        #expect(throws: AppleSignInNonceError.invalidLength) {
            try AppleSignInNonceGenerator.generate(length: 0) { 0 }
        }
    }

    @Test("Rejected bytes do not reduce nonce entropy length")
    func rejectionSamplingPreservesLength() throws {
        var bytes: [UInt8] = [255, 0, 0, 0]
        var calls = 0

        let nonce = try AppleSignInNonceGenerator.generate(length: 3) {
            calls += 1
            return bytes.removeFirst()
        }

        #expect(nonce == "000")
        #expect(calls == 4)
    }
}
