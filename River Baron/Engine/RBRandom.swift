import Foundation

/// Deterministic seeded RNG (SplitMix64). Used for ALL combat rolls, AI mistake
/// rolls and tiebreaks so a match is resume-safe and replayable from its seed.
struct RBRandom: Codable, Equatable {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    init() {
        self.state = 0x9E3779B97F4A7C15
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.state = try c.decodeIfPresent(UInt64.self, forKey: .state) ?? 0x9E3779B97F4A7C15
    }

    private enum CodingKeys: String, CodingKey { case state }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform integer in a closed range (range must be non-empty).
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        if span == 0 { return range.lowerBound }
        return range.lowerBound + Int(next() % span)
    }

    /// True with probability p (0...1).
    mutating func chance(_ p: Double) -> Bool {
        if p <= 0 { return false }
        if p >= 1 { return true }
        let v = Double(next() % 1_000_000) / 1_000_000.0
        return v < p
    }

    /// Deterministic pick of one element (nil for an empty array).
    mutating func pick<T>(_ array: [T]) -> T? {
        if array.isEmpty { return nil }
        return array[int(in: 0...(array.count - 1))]
    }
}
