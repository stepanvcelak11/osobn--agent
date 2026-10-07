import Foundation

/// Deterministický generátor (SplitMix64). Stav se ukládá do hry, takže hody jsou reprodukovatelné.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension GameState {
    /// Náhodné celé číslo v rozsahu (posouvá stav generátoru ve hře).
    public mutating func random(_ range: ClosedRange<Int>) -> Int {
        var g = SplitMix64(seed: rngState)
        let v = Int.random(in: range, using: &g)
        rngState = g.state
        return v
    }

    public mutating func chance(_ percent: Int) -> Bool { random(1...100) <= percent }

    public mutating func d20() -> Int { random(1...20) }

    public mutating func pick<T>(_ items: [T]) -> T { items[random(0...(items.count - 1))] }

    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var g = SplitMix64(seed: rngState)
        let out = items.shuffled(using: &g)
        rngState = g.state
        return out
    }
}
