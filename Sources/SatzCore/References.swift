import Foundation

public struct ReferenceDocument: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var source: String
    public var text: String
    public var fetched: Date
    public init(title: String, source: String, text: String) {
        id = UUID(); self.title = title; self.source = source; self.text = text; fetched = Date()
    }
}

public struct EvidencePassage {
    public let text: String
    public let source: String
    public let title: String
}

public enum ReferenceIndex {
    public static func passages(query: String, documents: [ReferenceDocument], limit: Int = 3) -> [EvidencePassage] {
        let tokens = TextRules.tokens(query)
        guard !tokens.isEmpty else { return [] }
        var candidates: [(EvidencePassage, Int)] = []
        for document in documents {
            let characters = Array(document.text)
            var offset = 0
            while offset < characters.count {
                let end = min(characters.count, offset + 1400)
                let passage = String(characters[offset..<end])
                let score = tokens.intersection(TextRules.tokens(passage + " " + document.title)).count
                if score > 0 { candidates.append((EvidencePassage(text: passage, source: document.source, title: document.title), score)) }
                offset += 1100
            }
        }
        candidates.sort { $0.1 > $1.1 }
        return candidates.prefix(limit).map(\.0)
    }

    public static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func containsVerbatim(_ answer: String, evidence: String) -> Bool {
        let answer = normalized(answer)
        return answer.count >= 2 && answer.count <= 160 && normalized(evidence).contains(answer)
    }
}
