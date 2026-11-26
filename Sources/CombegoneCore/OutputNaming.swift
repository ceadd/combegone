import Foundation

public enum OutputNaming {
    /// `<name> (no ads).<ext>` next to the input, adding a number instead of overwriting.
    public static func outputURL(for input: URL,
                                 fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let dir = input.deletingLastPathComponent()
        let ext = input.pathExtension
        let base = input.deletingPathExtension().lastPathComponent
        var n = 1
        while true {
            let tag = n == 1 ? "(no ads)" : "(no ads \(n))"
            var url = dir.appendingPathComponent("\(base) \(tag)")
            if !ext.isEmpty { url = url.appendingPathExtension(ext) }
            if !fileExists(url) { return url }
            n += 1
        }
    }
}
