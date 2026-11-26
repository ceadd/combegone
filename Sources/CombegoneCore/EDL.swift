import Foundation

public struct TimeRange: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) { self.start = start; self.end = end }
    public var length: Double { end - start }
}

/// Reads the `.edl` files comskip writes: one `start<TAB>end<TAB>type` per line, in seconds.
public enum EDL {
    public static func parse(_ text: String) -> [TimeRange] {
        let ranges = text.split(whereSeparator: \.isNewline).compactMap { line -> TimeRange? in
            let parts = line.split(whereSeparator: { $0 == "\t" || $0 == " " })
            guard parts.count >= 2, let s = Double(parts[0]), let e = Double(parts[1]), e > s, s >= 0 else { return nil }
            return TimeRange(start: s, end: e)
        }.sorted { $0.start < $1.start }

        var merged: [TimeRange] = []
        for r in ranges {
            if let last = merged.last, r.start <= last.end {
                merged[merged.count - 1].end = max(last.end, r.end)
            } else {
                merged.append(r)
            }
        }
        return merged
    }
}

public enum Segments {
    /// The parts of the recording to keep, given the commercial breaks to cut.
    /// Pieces shorter than `minLength` seconds are dropped so we never emit slivers.
    public static func keep(cuts: [TimeRange], duration: Double, minLength: Double = 0.5) -> [TimeRange] {
        var keep: [TimeRange] = []
        var cursor = 0.0
        for cut in cuts {
            let end = min(cut.start, duration)
            if end - cursor >= minLength { keep.append(TimeRange(start: cursor, end: end)) }
            cursor = max(cursor, cut.end)
            if cursor >= duration { break }
        }
        if duration - cursor >= minLength { keep.append(TimeRange(start: cursor, end: duration)) }
        return keep
    }

    /// Trims the cuts so nothing in the first `keepFirst` or last `keepLast` seconds is removed
    /// (e.g. end credits that comskip lumped into the final break).
    public static func protect(cuts: [TimeRange], duration: Double, keepFirst: Double, keepLast: Double) -> [TimeRange] {
        let lo = max(0, keepFirst), hi = keepLast > 0 ? duration - keepLast : .infinity
        return cuts.compactMap { c in
            let r = TimeRange(start: max(c.start, lo), end: min(c.end, hi))
            return r.end > r.start ? r : nil
        }
    }

    public static func removedSeconds(keep: [TimeRange], duration: Double) -> Double {
        duration - keep.reduce(0) { $0 + $1.length }
    }
}
