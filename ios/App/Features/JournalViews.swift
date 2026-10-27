import SwiftUI
import GraceCore
import UniformTypeIdentifiers

struct JournalView: View {
    @Environment(AppServices.self) private var services
    @State private var query = ""
    @State private var adding = false
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var deleteSelection = false
    @State private var deleteAll = false
    @State private var exporting = false
    private var entries: [JournalEntry] { services.practice.document.journalWithDrafts.filter { $0.matches(query) }.sorted { $0.date > $1.date } }
    private var selectedEntries: [JournalEntry] { services.practice.document.journalWithDrafts.filter { selection.contains($0.id) } }
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "Private · On this device", title: "Prayer journal", subtitle: "A few words, a moment of gratitude, or room to reflect.")
                    TextField("Search writing, tags, or connected prayers", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("journalSearch")
                    if services.practice.document.journalWithDrafts.isEmpty {
                        GraceEmpty(symbol: "book.closed", title: "Room for your own words.", message: "Your writing stays on this device. There is no account or cloud copy.")
                    } else if entries.isEmpty { Text("No entries match this search.").foregroundStyle(GraceColor.secondary) }
                    if selecting {
                        PracticeActions { Text("\(selection.count) selected"); Button("Select all") { selection = Set(entries.map(\.id)) }; Button("Done") { selecting = false; selection = [] } }
                        PracticeActions { Button("Export selected") { exporting = true }; Button("Delete selected", role: .destructive) { deleteSelection = true } }.disabled(selection.isEmpty)
                    }
                    ForEach(entries) { entry in
                        HStack(alignment: .top, spacing: 14) {
                            if selecting {
                                Button { if selection.contains(entry.id) { selection.remove(entry.id) } else { selection.insert(entry.id) } } label: { Image(systemName: selection.contains(entry.id) ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44) }.accessibilityLabel("Select \(entry.title.isEmpty ? entry.kind.title : entry.title)").accessibilityValue(selection.contains(entry.id) ? "Selected" : "Not selected")
                            }
                            NavigationLink(value: AppRoute.journalEntry(entry.id)) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(entry.title.isEmpty ? entry.kind.title : entry.title).font(.headline)
                                    if services.practice.document.journalDrafts.contains(where: { $0.id == entry.id }) { Text("Draft · saved when your private space locked").font(.caption).foregroundStyle(GraceColor.secondary) }
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(GraceColor.secondary)
                                    Text(entry.body).font(.subheadline).foregroundStyle(GraceColor.secondary).lineLimit(3)
                                    if !entry.tags.isEmpty { Text(entry.tags.joined(separator: " · ")).font(.caption).foregroundStyle(GraceColor.accent) }
                                    if let link = entry.link { Label(link.title, systemImage: "link").font(.caption).foregroundStyle(GraceColor.secondary) }
                                }.graceCard()
                            }.buttonStyle(.plain)
                        }
                    }
                    Button("Write an entry") { adding = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("writeJournalEntry")
                    PracticeErrorNotice()
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity).privacySensitive()
            }.scrollDismissesKeyboard(.interactively).pageStyle().navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
                .toolbar { Menu {
                    Button("Select entries") { selecting = true }
                    Button("Export all entries") { selection = Set(services.practice.document.journalWithDrafts.map(\.id)); exporting = true }
                    Button("Delete all journal entries", role: .destructive) { deleteAll = true }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.disabled(services.practice.document.journalWithDrafts.isEmpty).accessibilityLabel("Journal options") }
                .sheet(isPresented: $adding) { JournalEditor() }
                .sheet(isPresented: $exporting) { PrivateExportView(title: "Journal export", text: PracticeRules.journalExport(selectedEntries)) }
                .confirmationDialog("Delete selected journal entries?", isPresented: $deleteSelection, titleVisibility: .visible) {
                    Button("Delete selected entries", role: .destructive) {
                        for id in selection { if !services.practice.deleteEntry(id) { break } }
                        selection = selection.intersection(Set(services.practice.document.journalWithDrafts.map(\.id)))
                    }
                } message: { Text("This removes the selected writing from this device. There is no cloud copy.") }
                .confirmationDialog("Delete every journal entry?", isPresented: $deleteAll, titleVisibility: .visible) { Button("Delete all entries", role: .destructive) { if services.practice.clearJournal() { selection = [] } } } message: { Text("Activity, intentions, routines, and goals remain. Export first if you want a copy of your writing.") }
        }
    }
}

struct JournalDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var exporting = false
    private var entry: JournalEntry? { services.practice.document.journalWithDrafts.first { $0.id == id } }
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                if let entry {
                    VStack(alignment: .leading, spacing: 24) {
                        PageHeading(eyebrow: entry.kind.title, title: entry.title.isEmpty ? "Your own words" : entry.title, subtitle: entry.date.formatted(date: .abbreviated, time: .shortened))
                        if !entry.tags.isEmpty { Text(entry.tags.joined(separator: " · ")).font(.subheadline).foregroundStyle(GraceColor.accent) }
                        ReadingText(text: entry.body, scale: services.local.preferences.readingScale)
                        if let link = entry.link { JournalConnectionView(link: link) }
                        PracticeErrorNotice()
                    }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity).privacySensitive()
                }
            }.pageStyle().navigationTitle("Your journal").navigationBarTitleDisplayMode(.inline)
                .toolbar { Menu { Button("Edit entry") { editing = true }; Button("Export entry") { exporting = true }; Button("Delete entry", role: .destructive) { deleting = true } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Journal entry options") }
                .sheet(isPresented: $editing) { if let entry { JournalEditor(entry: entry) } }
                .sheet(isPresented: $exporting) { if let entry { PrivateExportView(title: "Journal export", text: PracticeRules.journalExport([entry])) } }
                .confirmationDialog("Delete this journal entry?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete entry", role: .destructive) { if services.practice.deleteEntry(id) { dismiss() } } } message: { Text("This removes the writing from this device. There is no cloud copy.") }
        }
    }
}

struct JournalConnectionView: View {
    @Environment(AppServices.self) private var services
    let link: JournalLink
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connected to \(link.title)", systemImage: "link").font(.subheadline)
            if link.kind == .prayer, services.prayer(link.id) != nil { NavigationLink("Return to prayer", value: AppRoute.prayer(link.id)).frame(minHeight: 44) }
            if link.kind == .passage {
                if let passage = services.local.savedPassages.first(where: { $0.id == link.id }) ?? services.catalog.catalog.passages.first(where: { $0.id == link.id }) {
                    NavigationLink("Read passage") { PassageDetailView(passage: passage) }.frame(minHeight: 44)
                }
            }
            if link.kind == .session { NavigationLink("Open prayer activity", value: AppRoute.activity).frame(minHeight: 44) }
        }.graceCard()
    }
}

struct JournalEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry
    @State private var tags: String
    @State private var choosingLink = false
    @State private var finished = false
    @State private var flusherID = UUID()
    private let original: JournalEntry?
    init(entry: JournalEntry? = nil, link: JournalLink? = nil) {
        original = entry
        _entry = State(initialValue: entry ?? JournalEntry(title: "", body: "", link: link))
        _tags = State(initialValue: entry?.tags.joined(separator: ", ") ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your entry") {
                    TextField("Title (optional)", text: $entry.title).accessibilityIdentifier("journalTitle")
                    Picker("Kind", selection: $entry.kind) { ForEach(JournalKind.allCases) { Text($0.title).tag($0) } }
                    DatePicker("Entry date", selection: $entry.date, in: ...Date.now)
                    TextEditor(text: $entry.body).frame(minHeight: 240).accessibilityLabel("Journal writing").accessibilityIdentifier("journalBody")
                }
                Section("Organization") {
                    TextField("Tags, separated by commas", text: $tags).accessibilityIdentifier("journalTags")
                    if let link = entry.link {
                        Label(link.title, systemImage: "link")
                        Button("Remove connection", role: .destructive) { entry.link = nil }
                    }
                    Button(entry.link == nil ? "Connect a prayer, passage, or session" : "Change connection") { choosingLink = true }
                }
                Section { Text("Private writing is saved only on this device and excluded from cloud backup. If your private space locks while you write, your words are retained as a protected draft. Cancel discards your current edits.").font(.footnote).foregroundStyle(.secondary) }
                if let error = services.practice.errorMessage { Text(error).foregroundStyle(.red) }
            }.privacySensitive().scrollDismissesKeyboard(.interactively).navigationTitle("Your own words").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { finished = true; if services.practice.document.journalDrafts.contains(where: { $0.id == entry.id }) { guard services.practice.discardJournalDraft(entry.id) else { finished = false; return } }; dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            entry.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines); entry.tags = PracticeRules.tags(tags)
                            if services.practice.saveEntry(entry) { finished = true; dismiss() }
                        }.disabled(entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveJournal")
                    }
                }
                .sheet(isPresented: $choosingLink) { JournalLinkPicker { entry.link = $0; choosingLink = false } }
                .onAppear {
                    services.privateEditorFlushers[flusherID] = {
                        guard !finished, entry != original || tags != original?.tags.joined(separator: ", "), !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        var draft = entry; draft.tags = PracticeRules.tags(tags); services.practice.saveJournalDraft(draft)
                    }
                }
                .onDisappear { services.privateEditorFlushers.removeValue(forKey: flusherID) }
        }
    }
}

struct JournalLinkPicker: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let choose: (JournalLink) -> Void
    private var passages: [Passage] {
        var seen = Set<String>()
        return (services.local.savedPassages + [services.catalog.catalog.passage(on: .now)].compactMap { $0 }).filter { seen.insert($0.id).inserted }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Prayers") { ForEach(services.catalog.catalog.items.filter { PracticeRules.matches(query, in: [$0.title]) }) { prayer in Button(prayer.title) { choose(JournalLink(kind: .prayer, id: prayer.id, title: prayer.title)) } } }
                Section("Today and saved passages") { ForEach(passages.filter { PracticeRules.matches(query, in: [$0.reference, $0.title]) }) { passage in Button("\(passage.reference) · \(passage.date)") { choose(JournalLink(kind: .passage, id: passage.id, title: "\(passage.reference) · \(passage.date)")) } } }
                Section("Recent activity") { ForEach(services.practice.document.sessions.sorted { $0.date > $1.date }.filter { PracticeRules.matches(query, in: [$0.title, $0.day]) }.prefix(30)) { session in Button("\(session.title) · \(session.day)") { choose(JournalLink(kind: .session, id: session.id.uuidString, title: session.title)) } } }
            }.searchable(text: $query).navigationTitle("Connect your writing").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}

struct PrivateExportView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let text: String
    @State private var saving = false
    @State private var exportError = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StatusNotice(text: "This export contains private writing. Review it before sharing. Copies you share are outside the app’s protection.", symbol: "lock.open")
                    ShareLink(item: text) { Label("Share readable copy", systemImage: "square.and.arrow.up") }.buttonStyle(PrimaryButtonStyle())
                    Button("Save a text file") { saving = true }.frame(minHeight: 44)
                    if exportError { StatusNotice(text: "The export could not be saved. Please try again.") }
                    Text(text).font(.body).textSelection(.enabled)
                }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity)
            }.privacySensitive().pageStyle().navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
                .fileExporter(isPresented: $saving, document: PrivateTextDocument(text: text), contentType: .plainText, defaultFilename: "Grace at Hand - \(title).txt") { result in
                    if case .failure = result { exportError = true } else { exportError = false }
                }
        }
    }
}

struct PrivateTextDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
