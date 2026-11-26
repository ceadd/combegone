import Foundation

/// The detection cues comskip can use (its `detect_method` bitmask).
public enum DetectMethod: Int, CaseIterable, Codable, Sendable, Identifiable {
    case blackFrames = 1
    case logo = 2
    case sceneChange = 4
    case resolutionChange = 8
    case closedCaptions = 16
    case aspectRatio = 32
    case silence = 64
    case cutScenes = 128

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .blackFrames: return "Black frames"
        case .logo: return "Channel logo"
        case .sceneChange: return "Scene changes"
        case .resolutionChange: return "Resolution changes"
        case .closedCaptions: return "Closed captions"
        case .aspectRatio: return "Aspect ratio changes"
        case .silence: return "Silence"
        case .cutScenes: return "Cut scenes"
        }
    }
}

extension Set where Element == DetectMethod {
    public var bitmask: Int { reduce(0) { $0 | $1.rawValue } }
    public init(bitmask: Int) { self = Set(DetectMethod.allCases.filter { bitmask & $0.rawValue != 0 }) }
}

/// User-facing options. The defaults reproduce the original behaviour exactly.
public struct ProcessingOptions: Equatable, Sendable {
    /// Overwrite the original file (same name) instead of saving "<name> (no ads)".
    public var replaceOriginal = false
    /// Prefer ~/.comskip.ini over the built-in settings when it exists (opt-in).
    public var useUserIni = false

    /// Never cut anything in the first / last N seconds (e.g. to protect end credits). 0 = off.
    public var keepFirstSeconds = 0
    public var keepLastSeconds = 0

    /// When false, none of the values below are passed to comskip.
    public var customDetection = false
    public var detectMethods: Set<DetectMethod> = Set(bitmask: 111)
    /// Let the channel logo outweigh comskip's "long stretches are probably show" penalty.
    public var trustLogo = true
    public var minCommercialBreak = 25
    public var maxCommercialBreak = 600
    public var minShowSegment = 125
    public var minCommercialSize = 4
    public var maxCommercialSize = 125
    public var threadCount = 4

    public init() {}

    /// Lines placed before the base ini (comskip uses the first value it reads).
    /// Only used when custom detection is on. (Keep first/last is applied by combegone itself,
    /// because comskip's always_keep_* settings drop the whole break instead of just protecting the end.)
    public var iniOverrides: [String] {
        guard customDetection else { return [] }
        return [
            "detect_method=\(detectMethods.bitmask)",
            "excessive_length_modifier=\(trustLogo ? "1" : "0.01")",
            "min_commercialbreak=\(minCommercialBreak)",
            "max_commercialbreak=\(maxCommercialBreak)",
            "min_show_segment_length=\(minShowSegment)",
            "min_commercial_size=\(minCommercialSize)",
            "max_commercial_size=\(maxCommercialSize)",
            "thread_count=\(threadCount)",
        ]
    }

    // MARK: Persistence (keys are shared with the Settings window's @AppStorage)

    public enum Key {
        public static let replaceOriginal = "replaceOriginal"
        public static let useUserIni = "useUserIni"
        public static let customDetection = "customDetection"
        public static let detectMethod = "detectMethod"
        public static let trustLogo = "trustLogo"
        public static let minCommercialBreak = "minCommercialBreak"
        public static let maxCommercialBreak = "maxCommercialBreak"
        public static let minShowSegment = "minShowSegment"
        public static let minCommercialSize = "minCommercialSize"
        public static let maxCommercialSize = "maxCommercialSize"
        public static let keepFirstSeconds = "keepFirstSeconds"
        public static let keepLastSeconds = "keepLastSeconds"
        public static let threadCount = "threadCount"
    }

    public static func load(from d: UserDefaults = .standard) -> ProcessingOptions {
        var o = ProcessingOptions()
        func int(_ k: String, _ v: inout Int) { if d.object(forKey: k) != nil { v = d.integer(forKey: k) } }
        func bool(_ k: String, _ v: inout Bool) { if d.object(forKey: k) != nil { v = d.bool(forKey: k) } }
        bool(Key.replaceOriginal, &o.replaceOriginal)
        bool(Key.useUserIni, &o.useUserIni)
        bool(Key.customDetection, &o.customDetection)
        var mask = o.detectMethods.bitmask
        int(Key.detectMethod, &mask)
        o.detectMethods = Set(bitmask: mask)
        bool(Key.trustLogo, &o.trustLogo)
        int(Key.minCommercialBreak, &o.minCommercialBreak)
        int(Key.maxCommercialBreak, &o.maxCommercialBreak)
        int(Key.minShowSegment, &o.minShowSegment)
        int(Key.minCommercialSize, &o.minCommercialSize)
        int(Key.maxCommercialSize, &o.maxCommercialSize)
        int(Key.keepFirstSeconds, &o.keepFirstSeconds)
        int(Key.keepLastSeconds, &o.keepLastSeconds)
        int(Key.threadCount, &o.threadCount)
        return o
    }

    public func save(to d: UserDefaults = .standard) {
        d.set(replaceOriginal, forKey: Key.replaceOriginal)
        d.set(useUserIni, forKey: Key.useUserIni)
        d.set(customDetection, forKey: Key.customDetection)
        d.set(detectMethods.bitmask, forKey: Key.detectMethod)
        d.set(trustLogo, forKey: Key.trustLogo)
        d.set(minCommercialBreak, forKey: Key.minCommercialBreak)
        d.set(maxCommercialBreak, forKey: Key.maxCommercialBreak)
        d.set(minShowSegment, forKey: Key.minShowSegment)
        d.set(minCommercialSize, forKey: Key.minCommercialSize)
        d.set(maxCommercialSize, forKey: Key.maxCommercialSize)
        d.set(keepFirstSeconds, forKey: Key.keepFirstSeconds)
        d.set(keepLastSeconds, forKey: Key.keepLastSeconds)
        d.set(threadCount, forKey: Key.threadCount)
    }
}
