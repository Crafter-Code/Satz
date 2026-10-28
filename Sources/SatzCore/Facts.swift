import Foundation

public struct SourceFact: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var topics: [String]
    public var attributes: [String]
    public var answer: String
    public var source: String
    public var checked: String
    public init(id: String = UUID().uuidString, title: String, topics: [String], attributes: [String], answer: String, source: String, checked: String) {
        self.id = id; self.title = title; self.topics = topics; self.attributes = attributes
        self.answer = answer; self.source = source; self.checked = checked
    }
}

public enum FactLibrary {
    public static func isSourceRequest(_ prefix: String) -> Bool {
        let line = String(prefix.components(separatedBy: "\n").last?.suffix(240) ?? "").lowercased()
        guard line.range(of: #"[-=:\u2013\u2014]\s*$"#, options: .regularExpression) != nil else { return false }
        let terms = ["height", "elevation", "population", "founded", "released", "first", "born", "distance", "year", "v\u{FD}\u{161}ka", "po\u{10D}et", "\u{432}\u{44B}\u{441}\u{43E}\u{442}", "\u{43F}\u{435}\u{440}\u{432}", "\u{433}\u{43E}\u{434}", "\u{43D}\u{430}\u{441}\u{435}\u{43B}\u{435}\u{43D}"]
        return terms.contains(where: line.contains)
    }
    public static let builtIn: [SourceFact] = [
        SourceFact(id: "everest-height", title: "Mount Everest: official elevation", topics: ["everest", "\u{44D}\u{432}\u{435}\u{440}\u{435}\u{441}\u{442}"], attributes: ["height", "elevation", "v\u{FD}\u{161}ka", "\u{432}\u{44B}\u{441}\u{43E}\u{442}"], answer: "8,848.86 m", source: "https://www.tourismdepartment.gov.np/files/statistics/45.pdf", checked: "2026-10-28"),
        SourceFact(id: "macbook-introduction", title: "Original MacBook: introduction date", topics: ["macbook", "\u{43C}\u{430}\u{43A}\u{431}\u{443}\u{43A}"], attributes: ["first", "introduc", "released", "prvn", "\u{43F}\u{435}\u{440}\u{432}", "\u{441}\u{43E}\u{437}\u{434}\u{430}"], answer: "2006", source: "https://www.apple.com/newsroom/2006/05/16Apple-Unveils-New-MacBook-Featuring-Intel-Core-Duo-Processors/", checked: "2026-10-28")
    ]

    public static func match(_ prefix: String, facts: [SourceFact]) -> SourceFact? {
        let line = String(prefix.components(separatedBy: "\n").last?.suffix(240) ?? "").lowercased()
        guard line.range(of: #"[-=:\u2013\u2014]\s*$"#, options: .regularExpression) != nil else { return nil }
        // MacBook Pro and Air have different histories; never apply the original MacBook date to them.
        return facts.first { fact in
            if fact.id == "macbook-introduction" && (line.contains(" pro") || line.contains(" air")) { return false }
            return fact.topics.contains(where: line.contains) && fact.attributes.contains(where: line.contains)
        }
    }

    public static func answer(_ fact: SourceFact, language: String) -> String {
        if fact.id == "everest-height", language == "ru" || language == "cs" { return "8 848,86 \(language == "ru" ? "\u{43C}" : "m")" }
        return fact.answer
    }

    public static func validSource(_ value: String) -> Bool {
        guard let url = URL(string: value), url.scheme == "https", let host = url.host,
              url.user == nil, url.password == nil, url.port == nil, url.query == nil,
              host.contains("."), !host.contains(":"), !host.hasSuffix(".local"),
              !host.hasSuffix(".internal"), host != "localhost",
              host.range(of: #"^[0-9.]+$"#, options: .regularExpression) == nil else { return false }
        return true
    }
}
