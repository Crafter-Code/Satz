import XCTest
@testable import SatzCore

final class CoreTests: XCTestCase {
    func testUnicodeWordAndWhitespace() {
        XCTAssertEqual(TextRules.firstWord(" hello world"), " hello")
        XCTAssertEqual(TextRules.firstWord("\u{43C}\u{438}\u{440} next"), "\u{43C}\u{438}\u{440}")
        XCTAssertEqual(TextRules.firstWord("😊 hello"), "😊")
    }
    func testNativeTextChunksPreserveUnicode() {
        let value = "A long continuation with an emoji 👨‍👩‍👧‍👦 and Czech diacritics: příští schůzka."
        let chunks = TextRules.unicodeChunks(value)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 20 })
        XCTAssertEqual(String(decoding: chunks.flatMap { $0 }, as: UTF16.self), value)
        XCTAssertEqual(TextRules.unicodeChunks(""), [])
    }
    func testThinkingIsNeverInserted() {
        XCTAssertEqual(TextRules.clean("<think>secret reasoning</think> hello there", prefix: "", maxWords: 4), " hello there")
        XCTAssertEqual(TextRules.clean("<think>unfinished", prefix: "", maxWords: 4), "")
        XCTAssertEqual(TextRules.clean("one two three four", prefix: "", maxWords: 2), "one two")
    }
    func testSensitiveDataNotLearned() {
        XCTAssertTrue(TextRules.isSensitive("api_key: abc"))
        XCTAssertTrue(TextRules.isSensitive("4111 1111 1111 1111"))
        XCTAssertFalse(TextRules.isSensitive("Please send the agenda tomorrow."))
    }
    func testMemoryRetrievalUsesRelevance() {
        let a = MemoryEntry(text: "The meeting agenda is ready", app: "mail")
        let b = MemoryEntry(text: "Dinner is ready", app: "notes")
        XCTAssertEqual(Personalization.examples(prefix: "meeting agenda", app: "mail", entries: [b,a]), [a.text])
        XCTAssertEqual(Personalization.examples(prefix: "unrelated content", app: "mail", entries: [a]), [])
    }
    func testFactsRequireAttributeAndDelimiter() {
        XCTAssertNil(FactLibrary.match("I climbed Everest last year", facts: FactLibrary.builtIn))
        XCTAssertNotNil(FactLibrary.match("Height of Everest - ", facts: FactLibrary.builtIn))
        XCTAssertNotNil(FactLibrary.match("Height of Everest — ", facts: FactLibrary.builtIn))
        XCTAssertNil(FactLibrary.match("First MacBook Pro - ", facts: FactLibrary.builtIn))
        XCTAssertEqual(FactLibrary.match("First MacBook released - ", facts: FactLibrary.builtIn)?.answer, "2006")
    }
    func testFactURLsCannotBeLocalOrContainCredentials() {
        for source in ["http://example.com", "https://127.0.0.1/a", "https://localhost/a", "https://a:secret@example.com", "https://example.com/?token=secret"] {
            XCTAssertFalse(FactLibrary.validSource(source))
        }
        XCTAssertTrue(FactLibrary.validSource("https://www.apple.com/newsroom/"))
    }
    func testEmojiAndPrivacyPolicy() {
        XCTAssertEqual(TextRules.emoji("Hello :smile"), "😊")
        XCTAssertNil(TextRules.emoji("https://smile"))
        XCTAssertFalse(Preferences().allows("com.apple.Passwords"))
        XCTAssertTrue(Preferences().allows("com.apple.TextEdit"))
    }
    func testRoundTrip() throws {
        var data = LocalData(); data.memories.append(MemoryEntry(text: "A local sentence", app: "test"))
        let copy = try JSONDecoder().decode(LocalData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(copy.memories, data.memories)
    }
    func testGroundingRejectsUnsupportedAnswers() {
        XCTAssertTrue(ReferenceIndex.containsVerbatim("8848.86 meters", evidence: "The summit rises to 8848.86 meters above sea level."))
        XCTAssertFalse(ReferenceIndex.containsVerbatim("9000 meters", evidence: "The summit rises to 8848.86 meters."))
        XCTAssertFalse(ReferenceIndex.containsVerbatim("", evidence: "A reference"))
        let doc = ReferenceDocument(title: "Mountain report", source: "https://example.gov/report", text: "Mount Everest rises to 8848.86 meters.")
        XCTAssertEqual(ReferenceIndex.passages(query: "Everest height", documents: [doc]).first?.source, doc.source)
        XCTAssertTrue(ReferenceIndex.passages(query: "unrelated request", documents: [doc]).isEmpty)
    }
    func testOlderVaultSchemaCanLoad() throws {
        let bytes = Data(#"{"schema":1}"#.utf8)
        let data = try JSONDecoder().decode(LocalData.self, from: bytes)
        XCTAssertTrue(data.documents.isEmpty)
        XCTAssertEqual(data.preferences.modelID, "balanced")
    }
    func testSourceHTMLDoesNotIndexScripts() {
        let text = SourceText.html("<script>tracking(1234)</script><article><h1>Report</h1><p>Height: 8848.86&nbsp;m &amp; snow &#x2713;</p></article><footer>Other</footer>")
        XCTAssertTrue(text.contains("8848.86 m & snow ✓"))
        XCTAssertFalse(text.contains("tracking"))
        XCTAssertFalse(text.contains("Other"))
    }
}
