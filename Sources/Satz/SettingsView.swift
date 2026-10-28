import SwiftUI
import Charts
import ServiceManagement
import SatzCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case overview = "Overview", writing = "Writing", memory = "Personalization", apps = "Applications", sources = "Sources", privacy = "Privacy", diagnostics = "Diagnostics"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .writing: return "text.cursor"
        case .memory: return "brain"
        case .apps: return "app.badge"
        case .sources: return "checkmark.seal"
        case .privacy: return "lock.shield"
        case .diagnostics: return "waveform.path.ecg"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var page = SettingsPage.overview
    @State private var appID = ""
    @State private var memorySearch = ""
    @State private var confirmClear = false
    @State private var loginError = ""
    @State private var factTitle = ""
    @State private var factTopics = ""
    @State private var factAttributes = ""
    @State private var factAnswer = ""
    @State private var factURL = ""
    @State private var checking = false
    @State private var documentTitle = ""
    @State private var documentURL = ""
    private let accent = Color(red: 0.95, green: 0.62, blue: 0.24)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "text.cursor").font(.system(size: 26, weight: .bold)).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Satz").font(.system(size: 27, weight: .semibold))
                        Text("PRECISION IN EVERY WORD").font(.system(size: 8, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 34)
                ForEach(SettingsPage.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(item.rawValue).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                            Spacer()
                        }.padding(.horizontal, 12).padding(.vertical, 11)
                            .foregroundStyle(page == item ? accent : .primary)
                            .background(page == item ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(model.engine.ready ? .green : .orange).frame(width: 6, height: 6)
                    Text(model.engine.ready ? "ON DEVICE" : "STARTING").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }
                Text("No account. No subscription.").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 8)
            }.padding(22).frame(width: 220).background(Color(red: 0.08, green: 0.095, blue: 0.12))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(page.rawValue).font(.system(size: 30, weight: .semibold))
                            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: page.symbol).font(.system(size: 28, weight: .light)).foregroundStyle(accent.opacity(0.8))
                    }.padding(.bottom, 4)
                    if let error = model.error { card("Attention", icon: "exclamationmark.triangle") { Text(error).foregroundStyle(.orange) } }
                    switch page {
                    case .overview: overview
                    case .writing: writing
                    case .memory: memory
                    case .apps: apps
                    case .sources: sources
                    case .privacy: privacy
                    case .diagnostics: diagnostics
                    }
                }.padding(30).frame(maxWidth: 850, alignment: .leading)
            }.frame(maxWidth: .infinity).background(Color(red: 0.11, green: 0.125, blue: 0.15))
        }.frame(minWidth: 940, minHeight: 690).preferredColorScheme(.dark).tint(accent)
    }

    var subtitle: String {
        switch page {
        case .overview: return "Your words. A little further ahead."
        case .writing: return "Quiet assistance, precisely where you type."
        case .memory: return "A growing vocabulary that belongs to you."
        case .apps: return "Choose where Satz works and how it writes."
        case .sources: return "Keep evidence separate from prediction."
        case .privacy: return "Local by design. Explicit by choice."
        case .diagnostics: return "Measure first. Improve with evidence."
        }
    }

    func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
            content().font(.system(size: 12))
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.07)))
    }

    var overview: some View {
        Group {
            card("Readiness", icon: "power") {
                Toggle("Enable writing assistance", isOn: $model.data.preferences.enabled)
                Label(model.status, systemImage: model.engine.ready ? "checkmark.circle.fill" : "hourglass").foregroundStyle(model.engine.ready ? .green : .orange)
                if !model.permission {
                    Text("Accessibility permission is required to read the active text field and accept suggestions. Satz never records raw key events.").foregroundStyle(.secondary)
                    Button("Open Accessibility Settings") { openAccessibility() }.buttonStyle(.borderedProminent)
                } else {
                    Label("Accessibility granted", systemImage: "checkmark.shield").foregroundStyle(.green)
                }
                Text("Tab accepts the next word. Shift–Tab accepts the whole suggestion. Esc dismisses it. Control–Option–Space requests a suggestion.").foregroundStyle(.secondary)
                Text("If Cotypist is running, Satz suspends external suggestions to prevent conflicts.").foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                metric("Words accepted", value: String(model.data.statistics.words), icon: "textformat.abc")
                metric("Local memories", value: String(model.data.memories.count), icon: "brain")
                metric("Last response", value: model.lastLatency > 0 ? String(format: "%.0f ms", model.lastLatency) : "—", icon: "bolt")
            }
            card("Try it here", icon: "pencil.line") {
                Text("This test stays inside Satz and does not need Accessibility. It is not added to your memory.").foregroundStyle(.secondary)
                TextEditor(text: $model.playgroundInput).font(.system(size: 14)).frame(height: 85).scrollContentBackground(.hidden).padding(8).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
                HStack {
                    Button(model.playgroundBusy ? "Generating…" : "Generate continuation") { model.testCompletion() }.disabled(!model.engine.ready || model.playgroundBusy)
                    if model.playgroundBusy { ProgressView().controlSize(.small) }
                }
                if !model.playgroundOutput.isEmpty { Text(model.playgroundOutput).font(.system(size: 15)).textSelection(.enabled).padding(.top, 4) }
            }
            if !model.data.statistics.byDay.isEmpty {
                card("Accepted words · recent activity", icon: "chart.bar") {
                    Chart(model.data.statistics.byDay.sorted(by: { $0.key < $1.key }).suffix(14), id: \.key) { item in
                        BarMark(x: .value("Day", String(item.key.suffix(5))), y: .value("Words", item.value)).foregroundStyle(accent)
                    }.frame(height: 120)
                }
            }
        }
    }

    func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(accent)
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded))
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    var writing: some View {
        Group {
            card("Completion", icon: "text.cursor") {
                Picker("Local model", selection: $model.data.preferences.modelID) {
                    Text("Balanced · Qwen3 4B · 2.5 GB").tag("balanced")
                    Text("Fast · Qwen3 1.7B · 1.8 GB").tag("fast")
                }
                Text("Changing the model takes effect after restarting Satz.").foregroundStyle(.secondary)
                Stepper("Maximum length: \(model.data.preferences.maxWords) words", value: $model.data.preferences.maxWords, in: 1...12)
                HStack { Text("Pause before suggesting"); Slider(value: $model.data.preferences.delay, in: 0.25...1.5, step: 0.05); Text(String(format: "%.2f s", model.data.preferences.delay)).monospacedDigit().frame(width: 45) }
                Toggle("Suggest spelling corrections", isOn: $model.data.preferences.autocorrect)
                Toggle("Suggest emoji from :shortcodes", isOn: $model.data.preferences.useEmoji)
                Text("Spelling uses installed macOS dictionaries. Corrections are suggestions; text changes only when you accept.").foregroundStyle(.secondary)
            }
            card("Writing instructions", icon: "slider.horizontal.3") {
                TextEditor(text: $model.data.preferences.instructions).frame(height: 95).scrollContentBackground(.hidden)
                Text("Language follows the text you are writing. Russian, Czech and English can be used without changing settings.").foregroundStyle(.secondary)
            }
            card("Energy", icon: "battery.75percent") {
                Toggle("On battery, generate only on request", isOn: $model.data.preferences.onDemandOnBattery)
                Toggle("On battery, keep suggestions shorter", isOn: $model.data.preferences.shortOnBattery)
                Text("Inference runs only after an editing pause. New input cancels stale requests. The model stays in memory while Satz is open.").foregroundStyle(.secondary)
            }
            card("Launch", icon: "sunrise") {
                Toggle("Launch Satz at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { enabled in
                    do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { loginError = error.localizedDescription }
                }))
                if !loginError.isEmpty { Text(loginError).foregroundStyle(.orange) }
            }
        }
    }

    var memory: some View {
        Group {
            card("Learning", icon: "brain") {
                Toggle("Learn from text where I accept a suggestion", isOn: $model.data.preferences.learnAccepted)
                Toggle("Also remember completed fields after recent acceptance", isOn: $model.data.preferences.learnSentences)
                Text("Satz learns local examples and preferred wording. It does not train model weights. Sensitive-pattern filtering is an additional safeguard, not a guarantee: exclude confidential apps below.").foregroundStyle(.secondary)
                Stepper("Keep up to \(model.data.preferences.maxEntries) examples", value: $model.data.preferences.maxEntries, in: 1000...50000, step: 1000)
                Stepper("Retention: \(model.data.preferences.retentionDays) days", value: $model.data.preferences.retentionDays, in: 7...730, step: 7)
                Button("Apply retention now") { model.prune() }
            }
            card("Personal dictionary", icon: "character.book.closed") {
                Text("Names, abbreviations and terminology you want to preserve. This field stays in the encrypted local vault.").foregroundStyle(.secondary)
                TextEditor(text: $model.data.preferences.personalDictionary).frame(height: 80).scrollContentBackground(.hidden)
            }
            card("Local memory · \(model.data.memories.count) examples", icon: "internaldrive") {
                TextField("Search your local memory", text: $memorySearch).textFieldStyle(.roundedBorder)
                ForEach(model.data.memories.reversed().filter { memorySearch.isEmpty || $0.text.localizedCaseInsensitiveContains(memorySearch) }.prefix(30)) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text).textSelection(.enabled).lineLimit(3)
                            Text("\(entry.app) · \(entry.date.formatted(date: .abbreviated, time: .omitted)) · used \(entry.uses)×").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.data.memories.removeAll { $0.id == entry.id } } label: { Image(systemName: "trash") }.help("Forget this example")
                    }
                    Divider()
                }
                if model.data.memories.isEmpty { Text("Your memory will grow as you accept suggestions.").foregroundStyle(.secondary) }
                Button("Clear learned examples…", role: .destructive) { confirmClear = true }
                    .confirmationDialog("Clear all learned examples? This cannot be undone. Your settings and dictionary will remain.", isPresented: $confirmClear) {
                        Button("Clear learned examples", role: .destructive) { model.data.memories = []; model.save() }
                    }
            }
        }
    }

    var apps: some View {
        Group {
            card("Application rules", icon: "app.badge") {
                Text("Use a bundle identifier, for example com.apple.mail. Rules and instructions are local. Password managers, terminals and code editors are excluded by default.").foregroundStyle(.secondary)
                HStack {
                    TextField("Application bundle identifier", text: $appID).textFieldStyle(.roundedBorder)
                    Button("Add rule") {
                        let id = appID.trimmingCharacters(in: .whitespaces)
                        guard id.contains("."), !model.data.preferences.appRules.contains(where: { $0.id == id }) else { return }
                        model.data.preferences.appRules.append(AppRule(id: id)); appID = ""
                    }
                }
                ForEach($model.data.preferences.appRules) { $rule in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(rule.id, isOn: $rule.enabled)
                        TextField("Instructions for this app", text: $rule.instructions).textFieldStyle(.roundedBorder)
                        Button("Remove rule") { model.data.preferences.appRules.removeAll { $0.id == rule.id } }
                    }.padding(.vertical, 8)
                }
            }
            card("Excluded applications", icon: "hand.raised") {
                Text("Exclusions take priority over application rules. Remove an exclusion only if you want Satz to read eligible text fields in that application.").foregroundStyle(.secondary)
                HStack {
                    Button("Exclude current app ID") {
                        let id = appID.trimmingCharacters(in: .whitespaces)
                        if id.contains("."), !model.data.preferences.deniedApps.contains(id) { model.data.preferences.deniedApps.append(id); appID = "" }
                    }.disabled(!appID.contains("."))
                }
                ForEach(model.data.preferences.deniedApps, id: \.self) { id in
                    HStack { Text(id).font(.system(size: 11, design: .monospaced)); Spacer(); Button("Allow") { model.data.preferences.deniedApps.removeAll { $0 == id } } }
                }
            }
        }
    }

    var sources: some View {
        Group {
            card("Source-backed suggestions", icon: "checkmark.seal") {
                Toggle("Use the local fact library", isOn: $model.data.preferences.useFacts)
                Text("Known facts can complete a matching phrase ending in a colon, dash or equals sign. The initial library contains two documented examples, not general web search. Suggestion details and sources are available through the small ellipsis beside the ghost text.").foregroundStyle(.secondary)
                Text("Example: Height of Everest —\nExample: First MacBook released —").textSelection(.enabled)
            }
            card("Reason over local references", icon: "doc.text.magnifyingglass") {
                Text("Import an official page or PDF once. Questions are answered locally by extracting an exact span from retrieved passages. Source text and questions stay in your encrypted vault. An exact match is evidence to review, not a guarantee of factual correctness.").foregroundStyle(.secondary)
                TextField("Document title", text: $documentTitle).textFieldStyle(.roundedBorder)
                TextField("Official HTTPS page or PDF URL", text: $documentURL).textFieldStyle(.roundedBorder)
                Button("Download reference into local library") {
                    guard SourceReader.allowed(documentURL), !documentTitle.isEmpty else { model.sourceStatus = "Enter a title and a supported official HTTPS URL."; return }
                    let url = documentURL, title = documentTitle
                    checking = true
                    Task {
                        defer { checking = false }
                        do {
                            let text = try await SourceReader.download(url)
                            guard !text.isEmpty, model.data.documents.count < 50 else { model.sourceStatus = "Empty source or document limit reached (50)."; return }
                            model.data.documents.removeAll { $0.source == url }
                            model.data.documents.append(ReferenceDocument(title: title, source: url, text: text))
                            model.sourceStatus = "Reference imported locally. Review its content before relying on extracted answers."
                            documentTitle = ""; documentURL = ""
                        } catch { model.sourceStatus = "Import failed: \(error.localizedDescription)" }
                    }
                }.disabled(checking)
                ForEach(model.data.documents) { document in
                    HStack {
                        VStack(alignment: .leading) { Text(document.title); Text("\(document.text.count) characters · \(document.fetched.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 10)).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Remove") { model.data.documents.removeAll { $0.id == document.id } }
                    }
                }
                Divider()
                TextField("Question for your local references", text: $model.referenceQuestion).textFieldStyle(.roundedBorder)
                Button(model.referenceBusy ? "Reading locally…" : "Find an evidence-backed answer") { model.askReferences() }.disabled(model.referenceBusy || !model.engine.ready)
                if !model.referenceAnswer.isEmpty { Text(model.referenceAnswer).textSelection(.enabled).lineLimit(30) }
            }
            ForEach(model.data.customFacts + FactLibrary.builtIn) { fact in
                card(fact.title, icon: "doc.text.magnifyingglass") {
                    Text(fact.answer).font(.system(size: 22, weight: .medium)).textSelection(.enabled)
                    Link(URL(string: fact.source)?.host ?? fact.source, destination: URL(string: fact.source)!)
                    Text("Reference recorded: \(fact.checked). A date records a check, not a guarantee that a claim will remain current.").foregroundStyle(.secondary)
                    HStack {
                        Button("Check answer text in source") { check(fact) }.disabled(checking || !SourceReader.allowed(fact.source))
                        if model.data.customFacts.contains(where: { $0.id == fact.id }) { Button("Remove") { model.data.customFacts.removeAll { $0.id == fact.id } } }
                    }
                }
            }
            card("Add a reference", icon: "plus.circle") {
                Text("No writing history is sent to the source. Checking downloads only the URL below. Supported official hosts are listed in the project documentation. Review the source yourself: finding the answer text does not prove its meaning.").foregroundStyle(.secondary)
                TextField("Title", text: $factTitle).textFieldStyle(.roundedBorder)
                TextField("Topic keywords, separated by commas", text: $factTopics).textFieldStyle(.roundedBorder)
                TextField("Attribute keywords, separated by commas", text: $factAttributes).textFieldStyle(.roundedBorder)
                TextField("Exact answer to insert", text: $factAnswer).textFieldStyle(.roundedBorder)
                TextField("Official HTTPS source URL", text: $factURL).textFieldStyle(.roundedBorder)
                Button("Add to local library") {
                    guard FactLibrary.validSource(factURL), !factTitle.isEmpty, !factAnswer.isEmpty else { model.sourceStatus = "Enter a title, answer and public HTTPS source without query parameters."; return }
                    let topics = keywords(factTopics), attrs = keywords(factAttributes)
                    guard !topics.isEmpty, !attrs.isEmpty else { model.sourceStatus = "Add at least one topic and attribute keyword."; return }
                    model.data.customFacts.append(SourceFact(title: factTitle, topics: topics, attributes: attrs, answer: factAnswer, source: factURL, checked: "User reference · not independently verified"))
                    factTitle = ""; factTopics = ""; factAttributes = ""; factAnswer = ""; factURL = ""
                }
                Text(model.sourceStatus).foregroundStyle(.secondary).textSelection(.enabled)
                if checking { ProgressView().controlSize(.small) }
            }
        }
    }

    var privacy: some View {
        Group {
            card("Your data boundary", icon: "lock.shield") {
                Label("Model inference stays on this Mac", systemImage: "checkmark")
                Label("Personalization is encrypted with AES-GCM", systemImage: "checkmark")
                Label("Encryption key is kept in this Mac's Keychain", systemImage: "checkmark")
                Label("No account, telemetry, cloud sync or clipboard access", systemImage: "checkmark")
                Label("No background website requests", systemImage: "checkmark")
                Text("External traffic is limited to the model download during setup and source URLs you explicitly check or open. The local model server binds only to 127.0.0.1 and requires a random session token. Text is not written to server logs.").foregroundStyle(.secondary)
            }
            card("Sensitive fields", icon: "hand.raised.slash") {
                Text("Secure input and password fields are excluded. Selected text is not replaced by autocomplete. Unsupported fields fail closed. Private-window detection depends on the host app; exclude browsers or confidential apps if you need stronger isolation.").foregroundStyle(.secondary)
                Text("No app can guarantee that all sensitive prose is recognisable automatically. Review your application exclusions and local memory.").foregroundStyle(.secondary)
            }
            card("Storage", icon: "internaldrive") {
                Text("Application Support / Satz").font(.system(.body, design: .monospaced))
                Button("Reveal local storage") { NSWorkspace.shared.open(LocalPaths.root) }
                Text("Personal data never belongs in the source repository. The public export includes only tracked source files. Model weights, encrypted data, backups and local settings are excluded.").foregroundStyle(.secondary)
            }
            card("Return to Cotypist", icon: "arrow.uturn.backward") {
                Text("Cotypist was not removed. Its settings, model files and writing database remain in its own application folder. Quit Satz before opening Cotypist.").foregroundStyle(.secondary)
                Button("Quit Satz and open Cotypist") {
                    model.stop()
                    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Cotypist.app"), configuration: .init()) { _, _ in }
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    var diagnostics: some View {
        Group {
            card("Runtime", icon: "waveform.path.ecg") {
                Text(model.status)
                Text("Accessibility: \(model.permission ? "granted" : "required") · Keyboard hook: \(model.hookActive ? "active" : "inactive")")
                Text("Last external field: \(model.fieldStatus)").textSelection(.enabled)
                ForEach(Array(model.fieldHistory.enumerated()), id: \.offset) { _, event in Text(event).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
                Text("Model: Qwen3 \(model.engine.modelID == "fast" ? "1.7B Q8_0" : "4B Q4_K_M") · Metal · 4,096-token context")
                Text("Mode: \(model.battery ? "battery" : "external power")")
                Text("Accepted completions: \(model.data.statistics.completions)")
                let stats = model.data.statistics
                Text(stats.generations > 0 ? String(format: "Mean local inference: %.0f ms", stats.totalLatencyMS / Double(stats.generations)) : "Inference measurements appear after external suggestions.")
                Button("Start local AI") { Task { await model.engine.start(modelID: model.data.preferences.modelID) } }
                Button("Open Accessibility Settings") { openAccessibility() }
            }
            card("Compatibility contract", icon: "checklist") {
                Text("Satz requires a text value, a collapsed selection and usable caret bounds through macOS Accessibility. App-specific compatibility must be tested. TextEdit is the initial target; browser canvases and custom editors can require additional adapters.").foregroundStyle(.secondary)
                Text("Version 0.1.0 · Independent open-source implementation").foregroundStyle(.secondary)
            }
        }
    }

    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func keywords(_ text: String) -> [String] { text.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    func check(_ fact: SourceFact) {
        checking = true; model.sourceStatus = "Checking only \(URL(string: fact.source)?.host ?? "source")…"
        Task {
            defer { checking = false }
            do {
                let found = try await SourceReader.check(fact)
                model.sourceStatus = found ? "Answer text found in the source. Review the context before relying on the claim." : "Answer text was not found. Do not treat this reference as verified."
            } catch { model.sourceStatus = "Source check failed: \(error.localizedDescription)" }
        }
    }
}
