import AppKit
import SwiftUI
import Combine
import IOKit.ps
import SatzCore

struct PendingSuggestion {
    let snapshot: FieldSnapshot
    let text: String
    let origin: String
    let replacement: Int
    let sourced: Bool
    let sourceURL: String?
}

private struct QueuedContinuation {
    let previous: PendingSuggestion
    let expectedText: String
    let expectedLocation: Int
    let remaining: String
    let expires: Date
}

@MainActor
final class AppModel: ObservableObject {
    @Published var data = LocalData()
    @Published var status = "Starting…"
    @Published var permission = false
    @Published var hookActive = false
    @Published var fieldStatus = "No external field sampled yet"
    @Published var fieldHistory: [String] = []
    @Published var error: String?
    @Published var lastLatency: Double = 0
    @Published var sourceStatus = "Source checking is manual. No typed text is sent online."
    @Published var referenceQuestion = "What is the height of Mount Everest?"
    @Published var referenceAnswer = ""
    @Published var referenceBusy = false
    @Published var playgroundInput = "Please send me the meeting "
    @Published var playgroundOutput = ""
    @Published var playgroundBusy = false
    let engine = LocalEngine()
    private var vault: Vault?
    private var subscription: AnyCancellable?
    private let keyboard = KeyboardHook()
    private let panel = SuggestionPanel()
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var previous: FieldSnapshot?
    private var pending: PendingSuggestion?
    private var queued: QueuedContinuation?
    private var revision = 0
    private var pausedUntil = Date.distantPast
    private var lastAccepted = Date.distantPast
    private var lastChange = Date()
    private var observedAt = Date()
    private var force = false
    private var locked = false
    private var lastInput = Date()
    private var activationObserver: NSObjectProtocol?
    var onMenuChange: (() -> Void)?

    init() {
        do {
            let storage = try Vault()
            data = try storage.load(); vault = storage
        } catch {
            locked = true; self.error = error.localizedDescription
            status = "Local vault locked · existing data preserved"
        }
        subscription = $data.dropFirst().debounce(for: .seconds(0.7), scheduler: RunLoop.main).sink { [weak self] _ in
            self?.save(); self?.onMenuChange?()
        }
        engine.onStatus = { [weak self] status in self?.status = status; self?.onMenuChange?() }
        keyboard.onKey = { [weak self] code, flags in self?.handleKey(code, flags: flags) ?? false }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.lastInput = Date(); self?.clear() }
        }
    }

    func start() {
        guard !locked else { return }
        prune()
        Task { await engine.start(modelID: data.preferences.modelID) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 0.07
    }
    func stop() { timer?.invalidate(); task?.cancel(); panel.hide(); keyboard.stop(); engine.stop(); save() }
    func save() {
        guard !locked else { return }
        do { try vault?.save(data) } catch { self.error = "Local save failed: \(error.localizedDescription)" }
    }
    func prune() {
        let cutoff = Date().addingTimeInterval(-Double(data.preferences.retentionDays) * 86400)
        data.memories = Array(data.memories.filter { $0.date > cutoff }.suffix(data.preferences.maxEntries))
    }
    var battery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return source as String == kIOPSBatteryPowerValue
    }

    func toggle() { data.preferences.enabled.toggle(); clear(); onMenuChange?() }
    func clear() { revision += 1; task?.cancel(); task = nil; pending = nil; queued = nil; panel.hide() }

    private func tick() {
        let allowed = Accessibility.trusted
        if permission != allowed { permission = allowed; onMenuChange?() }
        if allowed && !keyboard.active { keyboard.start(); hookActive = keyboard.active }
        if panel.isShowingDetails { return }
        if Date().timeIntervalSince(lastInput) > 10, pending == nil, task == nil { return }
        let conflict = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "app.cotypist.Cotypist" && !$0.isTerminated }
        guard allowed, !locked, data.preferences.enabled, Date() > pausedUntil, !conflict else {
            if conflict { fieldStatus = "Paused while Cotypist is running" }
            if pending != nil || task != nil { clear() }
            return
        }
        guard let now = Accessibility.snapshot(preferences: data.preferences) else {
            recordFieldStatus()
            if let old = previous { learnCompleted(old) }
            previous = nil
            if pending != nil || task != nil { clear() }
            return
        }
        recordFieldStatus()
        if restoreContinuation(now) { return }
        if let previous, now.same(as: previous) {
            if pending != nil { return }
            if task == nil, Date().timeIntervalSince(lastChange) >= data.preferences.delay, Date().timeIntervalSince(observedAt) < 15 {
                if battery && data.preferences.onDemandOnBattery && !force { return }
                generate(now); observedAt = .distantPast
            }
            return
        }
        if let old = previous, old.pid != now.pid || !CFEqual(old.element, now.element) { learnCompleted(old) }
        previous = now; lastChange = Date(); observedAt = Date(); clear()
    }

    private func restoreContinuation(_ snapshot: FieldSnapshot) -> Bool {
        guard let next = queued else { return false }
        guard Date() < next.expires else { queued = nil; return false }
        guard snapshot.pid == next.previous.snapshot.pid,
              CFEqual(snapshot.element, next.previous.snapshot.element),
              snapshot.text == next.expectedText, snapshot.range.location == next.expectedLocation else { queued = nil; return false }
        queued = nil; previous = snapshot; lastChange = Date(); observedAt = Date()
        present(snapshot, text: next.remaining, origin: next.previous.origin, sourced: next.previous.sourced, sourceURL: next.previous.sourceURL)
        return true
    }

    private func recordFieldStatus() {
        guard fieldStatus != Accessibility.lastIssue else { return }
        fieldStatus = Accessibility.lastIssue
        fieldHistory.append(fieldStatus)
        fieldHistory = Array(fieldHistory.suffix(8))
    }

    private func generate(_ snapshot: FieldSnapshot) {
        let prefix = snapshot.prefix
        guard !prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        force = false
        if data.preferences.useEmoji, let emoji = TextRules.emoji(prefix) {
            present(snapshot, text: emoji, origin: "Emoji", replacement: TextRules.emojiTriggerLength(prefix)); return
        }
        if data.preferences.useFacts, let fact = FactLibrary.match(prefix, facts: data.customFacts + FactLibrary.builtIn) {
            present(snapshot, text: FactLibrary.answer(fact, language: TextRules.language(prefix)), origin: "Source · \(URL(string: fact.source)?.host ?? "official reference")", sourced: true, sourceURL: fact.source); return
        }
        if data.preferences.useFacts, FactLibrary.isSourceRequest(prefix) {
            let passages = ReferenceIndex.passages(query: prefix, documents: data.documents)
            guard engine.ready, !passages.isEmpty else { return }
            let current = revision
            task = Task { [weak self] in
                guard let self else { return }
                defer { if current == revision { task = nil } }
                for passage in passages {
                    guard !Task.isCancelled, current == revision else { return }
                    if let answer = try? await engine.extractAnswer(question: prefix, passage: passage.text),
                       let now = Accessibility.snapshot(preferences: data.preferences), snapshot.same(as: now), current == revision {
                        present(snapshot, text: answer, origin: "Source extract · \(URL(string: passage.source)?.host ?? "reference")", sourced: true, sourceURL: passage.source)
                        return
                    }
                }
            }
            return
        }
        if data.preferences.autocorrect, let correction = correction(prefix) {
            present(snapshot, text: correction.1, origin: "Spelling · \(correction.0)", replacement: correction.0.utf16.count); return
        }
        if let memory = Personalization.continuation(prefix: prefix, entries: data.memories) {
            present(snapshot, text: TextRules.clean(memory, prefix: prefix, maxWords: data.preferences.maxWords), origin: "Personal memory"); return
        }
        guard prefix.count >= 8, engine.ready else { return }
        let examples = Personalization.examples(prefix: prefix, app: snapshot.bundle, entries: data.memories)
        let current = revision
        task = Task { [weak self] in
            guard let self else { return }
            let start = Date()
            do {
                let result = try await engine.complete(prefix: prefix, suffix: snapshot.suffix, preferences: data.preferences, app: snapshot.bundle, examples: examples, short: battery && data.preferences.shortOnBattery)
                guard !Task.isCancelled, current == revision else { return }
                task = nil
                lastLatency = Date().timeIntervalSince(start) * 1000
                data.statistics.totalLatencyMS += lastLatency; data.statistics.generations += 1
                if let now = Accessibility.snapshot(preferences: data.preferences), snapshot.same(as: now), !result.isEmpty {
                    present(snapshot, text: result, origin: "Local AI · unverified")
                }
            } catch {
                if current == revision { task = nil }
            }
        }
    }

    private func correction(_ prefix: String) -> (String, String)? {
        guard let r = prefix.range(of: #"[\p{L}]{4,}$"#, options: .regularExpression) else { return nil }
        let word = String(prefix[r])
        guard !word.first!.isUppercase, !data.preferences.personalDictionary.lowercased().contains(word.lowercased()) else { return nil }
        let language = TextRules.language(prefix)
        let checker = NSSpellChecker.shared
        let misspelled = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        guard misspelled.location != NSNotFound,
              let guess = checker.guesses(forWordRange: NSRange(location: 0, length: word.utf16.count), in: word, language: language, inSpellDocumentWithTag: 0)?.first,
              guess.lowercased() != word.lowercased(), abs(guess.count - word.count) <= 2 else { return nil }
        return (word, guess)
    }

    private func present(_ snapshot: FieldSnapshot, text: String, origin: String, replacement: Int = 0, sourced: Bool = false, sourceURL: String? = nil) {
        guard !text.isEmpty else { return }
        pending = PendingSuggestion(snapshot: snapshot, text: text, origin: origin, replacement: replacement, sourced: sourced, sourceURL: sourceURL)
        let inline = snapshot.suffix.components(separatedBy: "\n").first?.isEmpty ?? true
        panel.show(text: text, origin: origin, source: sourced, sourceURL: sourceURL, caret: snapshot.caret, font: snapshot.font, inline: inline)
    }

    private func handleKey(_ code: Int64, flags: CGEventFlags) -> Bool {
        lastInput = Date()
        if code == -1 && panel.containsPointer { return false }
        if code == 48, pending == nil, queued != nil, let snapshot = Accessibility.snapshot(preferences: data.preferences) { _ = restoreContinuation(snapshot) }
        if code == 49 && flags.contains(.maskControl) && flags.contains(.maskAlternate) {
            clear(); force = true; observedAt = Date(); lastChange = .distantPast
            return true
        }
        if code == 48, let suggestion = pending,
           !flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate), data.preferences.enabled {
            let part = flags.contains(.maskShift) || suggestion.replacement > 0 ? suggestion.text : TextRules.firstWord(suggestion.text)
            let ok = Accessibility.insert(part, replacing: suggestion.replacement, snapshot: suggestion.snapshot, preferences: data.preferences)
            clear()
            if ok {
                let remainder = String(suggestion.text.dropFirst(part.count))
                if !remainder.isEmpty, suggestion.replacement == 0 {
                    let expected = (suggestion.snapshot.text as NSString).replacingCharacters(in: NSRange(location: suggestion.snapshot.range.location, length: 0), with: part)
                    queued = QueuedContinuation(previous: suggestion, expectedText: expected, expectedLocation: suggestion.snapshot.range.location + part.utf16.count, remaining: remainder, expires: Date().addingTimeInterval(2))
                }
                lastAccepted = Date()
                data.statistics.words += part.split(whereSeparator: \.isWhitespace).count
                data.statistics.characters += part.count; data.statistics.completions += 1
                let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
                data.statistics.byDay[String(day), default: 0] += part.split(whereSeparator: \.isWhitespace).count
                if data.preferences.learnAccepted {
                    let end = max(0, suggestion.snapshot.range.location - suggestion.replacement)
                    let prefix = (suggestion.snapshot.text as NSString).substring(to: end)
                    remember(String((prefix + part).suffix(500)), app: suggestion.snapshot.bundle)
                }
            }
            return ok
        }
        if code == 53, pending != nil { clear(); pausedUntil = Date().addingTimeInterval(3); return true }
        // Dismiss on every real edit or pointer movement. Never store raw key events.
        if pending != nil || task != nil { clear() }
        return false
    }

    private func learnCompleted(_ snapshot: FieldSnapshot) {
        guard data.preferences.learnSentences, Date().timeIntervalSince(lastAccepted) < 600 else { return }
        remember(String(snapshot.prefix.suffix(500)), app: snapshot.bundle)
    }

    func remember(_ text: String, app: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 12, !TextRules.isSensitive(value) else { return }
        if let index = data.memories.firstIndex(where: { $0.text == value }) {
            data.memories[index].uses += 1; data.memories[index].date = Date()
        } else { data.memories.append(MemoryEntry(text: value, app: app)) }
        prune()
    }

    func testCompletion() {
        guard !playgroundBusy else { return }
        playgroundBusy = true; playgroundOutput = ""
        Task {
            defer { playgroundBusy = false }
            if let fact = FactLibrary.match(playgroundInput, facts: data.customFacts + FactLibrary.builtIn) {
                playgroundOutput = FactLibrary.answer(fact, language: TextRules.language(playgroundInput)) + "\nSource: " + fact.source
                return
            }
            do {
                let start = Date()
                playgroundOutput = try await engine.complete(prefix: playgroundInput, suffix: "", preferences: data.preferences, app: "playground", examples: Personalization.examples(prefix: playgroundInput, app: "playground", entries: data.memories), short: false)
                lastLatency = Date().timeIntervalSince(start) * 1000
            } catch { playgroundOutput = "Local AI error: \(error.localizedDescription)" }
        }
    }

    func askReferences() {
        guard !referenceBusy else { return }
        referenceBusy = true; referenceAnswer = ""
        Task {
            defer { referenceBusy = false }
            let passages = ReferenceIndex.passages(query: referenceQuestion, documents: data.documents)
            guard !passages.isEmpty else { referenceAnswer = "No matching local reference. Import a relevant official document first. No online question was sent."; return }
            for passage in passages {
                do {
                    if let answer = try await engine.extractAnswer(question: referenceQuestion, passage: passage.text) {
                        referenceAnswer = answer + "\n\nSource: " + passage.source + "\n\nEvidence passage:\n" + passage.text
                        return
                    }
                } catch { referenceAnswer = "Local extraction failed: \(error.localizedDescription)"; return }
            }
            referenceAnswer = "No supported answer span found in the retrieved passages. The app will not invent a sourced answer."
        }
    }
}
