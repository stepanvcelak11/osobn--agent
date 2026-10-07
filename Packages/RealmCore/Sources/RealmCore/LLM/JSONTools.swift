import Foundation

public enum JSONTools {
    /// První vyvážený JSON objekt v textu (model občas přidá text okolo).
    public static func firstObject(_ s: String) -> String? {
        guard let start = s.firstIndex(of: "{") else { return nil }
        var depth = 0, inString = false, escape = false
        var i = start
        while i < s.endIndex {
            let c = s[i]
            if inString {
                if escape { escape = false }
                else if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return String(s[start...i]) }
                }
            }
            i = s.index(after: i)
        }
        return nil
    }

    public static func parseObject(_ s: String) -> JSONValue? {
        firstObject(s).flatMap(JSONValue.parse)
    }

    /// Dekóduje rozepsaný JSON řetězec (bez koncové uvozovky) – pro průběžné zobrazení textu.
    public static func decodePartialString(_ s: String) -> String {
        var out = ""
        var it = s.makeIterator()
        while let c = it.next() {
            if c == "\"" { break }
            if c == "\\" {
                guard let n = it.next() else { break }
                switch n {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "u":
                    var hex = ""
                    for _ in 0..<4 { if let h = it.next() { hex.append(h) } }
                    if let v = UInt32(hex, radix: 16), let sc = Unicode.Scalar(v) { out.append(Character(sc)) }
                default: out.append(n)
                }
            } else { out.append(c) }
        }
        return out
    }
}

/// Z průběžného výstupu `{"narration":"…` vytahuje čitelný text vyprávění pro UI.
public final class FieldStreamer: @unchecked Sendable {
    private var buffer = ""
    private let prefix: String
    private let onText: (String) -> Void
    private let lock = NSLock()

    public init(field: String, onText: @escaping (String) -> Void) {
        self.prefix = "{\"\(field)\":\""
        self.onText = onText
    }

    public func feed(_ piece: String) {
        lock.lock()
        buffer += piece
        let b = buffer
        lock.unlock()
        guard b.hasPrefix(prefix) else { return }
        onText(JSONTools.decodePartialString(String(b.dropFirst(prefix.count))))
    }
}
