import Foundation

public struct AppRule: Codable, Identifiable {
    public var id: String
    public var enabled: Bool
    public var instructions: String
    public init(id: String, enabled: Bool = true, instructions: String = "") { self.id = id; self.enabled = enabled; self.instructions = instructions }
}

public struct Preferences: Codable {
    public var modelID = "balanced"
    public var enabled = true
    public var learnAccepted = true
    public var learnSentences = false
    public var useFacts = true
    public var useEmoji = true
    public var autocorrect = true
    public var onDemandOnBattery = false
    public var shortOnBattery = true
    public var maxWords = 4
    public var delay = 0.5
    public var retentionDays = 180
    public var maxEntries = 10000
    public var instructions = "Continue the user's own writing. Match its language, tone and spelling. Be concise. Do not invent facts."
    public var personalDictionary = ""
    public var appRules: [AppRule] = []
    public var deniedApps = ["com.apple.keychainaccess", "com.apple.Passwords", "com.apple.Terminal", "com.googlecode.iterm2", "com.agilebits.onepassword7", "com.1password.1password", "com.bitwarden.desktop", "com.apple.dt.Xcode", "com.jetbrains.CLion", "com.jetbrains.intellij", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"]
    public init() {}
    public func allows(_ bundle: String) -> Bool {
        if deniedApps.contains(bundle) { return false }
        return appRules.first(where: { $0.id == bundle })?.enabled ?? true
    }
}

public struct Statistics: Codable {
    public var words = 0
    public var characters = 0
    public var completions = 0
    public var totalLatencyMS: Double = 0
    public var generations = 0
    public var byDay: [String: Int] = [:]
    public init() {}
}

public struct LocalData: Codable {
    public var schema = 1
    public var preferences = Preferences()
    public var memories: [MemoryEntry] = []
    public var customFacts: [SourceFact] = []
    public var documents: [ReferenceDocument] = []
    public var statistics = Statistics()
    public init() {}
    enum CodingKeys: String, CodingKey { case schema, preferences, memories, customFacts, documents, statistics }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 1
        preferences = try c.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        memories = try c.decodeIfPresent([MemoryEntry].self, forKey: .memories) ?? []
        customFacts = try c.decodeIfPresent([SourceFact].self, forKey: .customFacts) ?? []
        documents = try c.decodeIfPresent([ReferenceDocument].self, forKey: .documents) ?? []
        statistics = try c.decodeIfPresent(Statistics.self, forKey: .statistics) ?? Statistics()
    }
}
