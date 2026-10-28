import Foundation

public enum TextRules {
    public static func unicodeChunks(_ text: String, limit: Int = 20) -> [[UInt16]] {
        var result: [[UInt16]] = [], buffer: [UInt16] = []
        for character in text {
            let units = Array(String(character).utf16)
            guard units.count <= limit else { return [] }
            if buffer.count + units.count > limit { result.append(buffer); buffer = [] }
            buffer.append(contentsOf: units)
        }
        if !buffer.isEmpty { result.append(buffer) }
        return result
    }
    public static func firstWord(_ text: String) -> String {
        guard let range = text.range(of: #"^\s*\S+"#, options: .regularExpression) else { return "" }
        return String(text[range])
    }

    public static func clean(_ text: String, prefix: String, maxWords: Int) -> String {
        var value = text.replacingOccurrences(of: #"<think>[\s\S]*?</think>"#, with: "", options: .regularExpression)
        if value.contains("<think>") { return "" }
        if value.contains("</think>") { value = value.components(separatedBy: "</think>").last ?? "" }
        value = value.components(separatedBy: "\n").first ?? ""
        value = value.replacingOccurrences(of: #"<\|[^>]+\|>"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "**", with: "")
        if value.hasPrefix(prefix), !prefix.isEmpty { value.removeFirst(prefix.count) }
        if prefix.last?.isWhitespace == true { value = value.trimmingCharacters(in: .whitespaces) }
        let words = value.split(whereSeparator: \.isWhitespace)
        if words.count > maxWords, let end = value.range(of: #"^(?:\s*\S+){1,"# + String(maxWords) + "}", options: .regularExpression) {
            value = String(value[end])
        }
        return String(value.prefix(220))
    }

    public static func language(_ text: String) -> String {
        let sample = text.suffix(240)
        if sample.unicodeScalars.contains(where: { (0x0400...0x052F).contains(Int($0.value)) }) { return "ru" }
        if sample.unicodeScalars.contains(where: { [0x010D,0x0159,0x0161,0x017E,0x011B,0x016F,0x010F,0x0165,0x0148].contains(Int($0.value)) }) { return "cs" }
        return "en"
    }

    public static func isSensitive(_ text: String) -> Bool {
        let patterns = [#"(?i)(password|passwd|api[_ -]?key|secret|authorization|bearer|private key)\s*[:=]"#,
                        #"\b(?:sk|ghp|github_pat|AKIA)[-_A-Za-z0-9]{16,}\b"#,
                        #"\b(?:\d[ -]?){13,19}\b"#]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    public static func tokens(_ text: String) -> Set<String> {
        Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 2 }.map(String.init))
    }

    public static func emoji(_ prefix: String) -> String? {
        guard let r = prefix.range(of: #"(?:^|\s):([a-z_]{2,24})$"#, options: .regularExpression) else { return nil }
        let key = prefix[r].trimmingCharacters(in: .whitespaces).dropFirst()
        let entries = ["smile":"😊", "heart":"❤️", "thumbsup":"👍", "thanks":"🙏", "fire":"🔥", "rocket":"🚀", "check":"✅", "warning":"⚠️", "laugh":"😂", "wave":"👋", "party":"🎉"]
        return entries[String(key)]
    }

    public static func emojiTriggerLength(_ prefix: String) -> Int {
        guard let r = prefix.range(of: #":[a-z_]{2,24}$"#, options: .regularExpression) else { return 0 }
        return prefix[r].utf16.count
    }
}

public struct MemoryEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var text: String
    public var app: String
    public var date: Date
    public var uses: Int
    public init(text: String, app: String, date: Date = Date()) {
        self.id = UUID(); self.text = text; self.app = app; self.date = date; self.uses = 1
    }
}

public enum Personalization {
    public static func examples(prefix: String, app: String, entries: [MemoryEntry], limit: Int = 3) -> [String] {
        let query = TextRules.tokens(prefix)
        guard !query.isEmpty else { return [] }
        var scored: [(MemoryEntry, Int)] = []
        for entry in entries where !TextRules.isSensitive(entry.text) {
            let overlap = query.intersection(TextRules.tokens(entry.text)).count
            let score = overlap * 5 + (entry.app == app ? 1 : 0)
            if score > 1 { scored.append((entry, score)) }
        }
        scored.sort { a, b in
            if a.1 == b.1 { return a.0.date > b.0.date }
            return a.1 > b.1
        }
        return scored.prefix(limit).map { String($0.0.text.prefix(280)) }
    }

    public static func continuation(prefix: String, entries: [MemoryEntry]) -> String? {
        let suffix = String(prefix.suffix(160)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard suffix.count >= 12 else { return nil }
        for entry in entries.sorted(by: { $0.uses > $1.uses }) {
            if entry.text.lowercased().hasPrefix(suffix.lowercased()), entry.text.count > suffix.count {
                let result = String(entry.text.dropFirst(suffix.count))
                return prefix.last?.isWhitespace == true ? result.trimmingCharacters(in: .whitespaces) : result
            }
        }
        return nil
    }
}
