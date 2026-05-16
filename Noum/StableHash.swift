import Foundation

// MARK: - StableHash
//
// Swift's `Hasher` is intentionally seeded with a random per-process value
// so that hash-based collections resist algorithmic complexity attacks.
// That's the right default for `Dictionary` / `Set`, but it makes
// `Hasher().finalize()` useless as a stable identifier:
//
//   • Word-of-the-Day picks today's word by hashing the ISO date — every
//     app launch would otherwise show a *different* "today's word".
//   • DailyChallengeGenerator picks today's three challenges by hashing
//     the same date — same launch-to-launch instability.
//   • PracticeTopics.seeded(by:) is used for async-challenge prompt
//     sharing. Both participants must land on the same prompt; if the
//     hash is process-random, fairness breaks across devices.
//   • PromptHistoryStore.hash(of:) keys persistent prompt-history state —
//     across-launch instability means recently-shown prompts get re-shown
//     because their cached hash no longer matches.
//   • AIInsightsService.cacheKey persists generated insights — process-
//     random keys mean every launch starts a cold cache.
//
// StableHash provides a small, dependency-free, cross-launch-stable
// 64-bit hash (FNV-1a). The values it produces are stable across:
//   • The same process on different launches.
//   • Different devices and different OS versions.
//   • Different Swift toolchain versions.
//
// FNV-1a is not cryptographically strong; we don't need it to be.
// All uses are for indexing into small curated pools or building cache
// keys — not authentication.

enum StableHash {
    /// FNV-1a 64 offset basis.
    private static let offsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    /// FNV-1a 64 prime.
    private static let prime: UInt64 = 0x0000_0100_0000_01B3

    /// Stable 64-bit hash of the input string, encoded as UTF-8.
    /// Equal strings produce equal hashes across processes and devices.
    static func hash(_ string: String) -> UInt64 {
        var h = offsetBasis
        for byte in string.utf8 {
            h ^= UInt64(byte)
            h &*= prime
        }
        return h
    }

    /// Convenience: stable, positive index into a non-empty collection.
    /// Returns `nil` for empty collections rather than crashing on % 0.
    static func index<C: Collection>(in collection: C, seed: String) -> C.Index? {
        guard !collection.isEmpty else { return nil }
        let offset = Int(hash(seed) % UInt64(collection.count))
        return collection.index(collection.startIndex, offsetBy: offset)
    }
}
