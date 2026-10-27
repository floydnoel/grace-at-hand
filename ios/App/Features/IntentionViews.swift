import SwiftUI
import GraceCore

struct IntentionsView: View {
    @Environment(AppServices.self) private var services
    @State private var adding = false
    @State private var query = ""
    @State private var status = "active"
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var deleting = false
    @State private var clearing = false
    @State private var exporting = false
    private var entries: [PrayerIntention] { services.intentions.entries.filter { (status == "all" || $0.status.rawValue == status) && $0.matches(query) } }
    private var selectedEntries: [PrayerIntention] { services.intentions.entries.filter { selection.contains($0.id) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Private · On this device", title: "My intentions", subtitle: "People and hopes to bring to prayer.")
                if services.intentions.isLocked { GraceEmpty(symbol: "lock", title: "A private space.", message: "Unlock your device to return to your intentions.") }
                else if let error = services.intentions.errorMessage {
                    StatusNotice(text: error, symbol: "lock")
                    Button("Try opening again") { services.intentions.load() }
                    Button("Clear all intentions", role: .destructive) { clearing = true }
                } else {
                    TextField("Search intentions, tags, and updates", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("intentionSearch")
                    Picker("Intention status", selection: $status) { Text("Active").tag("active"); Text("Answered").tag("answered"); Text("Archived").tag("archived"); Text("All").tag("all") }.pickerStyle(.menu)
                    if entries.isEmpty { GraceEmpty(symbol: "hands.sparkles", title: services.intentions.entries.isEmpty ? "Who is on\nyour heart?" : "A little room to look.", message: services.intentions.entries.isEmpty ? "You can begin with a name, a hope, or a few words." : "No intentions match these filters.") }
                    if selecting {
                        PracticeActions { Text("\(selection.count) selected"); Button("Select all") { selection = Set(entries.map(\.id)) }; Button("Done") { selecting = false; selection = [] } }
                        PracticeActions { Button("Export selected") { exporting = true }; Button("Delete selected", role: .destructive) { deleting = true } }.disabled(selection.isEmpty)
                    }
                    ForEach(entries) { intention in
                        HStack(alignment: .top, spacing: 12) {
                            if selecting { Button { if selection.contains(intention.id) { selection.remove(intention.id) } else { selection.insert(intention.id) } } label: { Image(systemName: selection.contains(intention.id) ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44) }.accessibilityLabel("Select \(intention.title)").accessibilityValue(selection.contains(intention.id) ? "Selected" : "Not selected") }
                            NavigationLink(value: AppRoute.intention(intention.id)) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(intention.title).font(.headline)
                                    if !intention.note.isEmpty { Text(intention.note).font(.subheadline).foregroundStyle(GraceColor.secondary).lineLimit(3) }
                                    Text(intention.status.title).font(.caption).foregroundStyle(GraceColor.secondary)
                                    if !intention.tags.isEmpty { Text(intention.tags.joined(separator: " · ")).font(.caption).foregroundStyle(GraceColor.accent) }
                                    if let date = intention.followUpDate { Label("Follow-up: \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell").font(.caption).foregroundStyle(GraceColor.secondary) }
                                }.graceCard()
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { adding = true } label: { Label("Add an intention", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addIntention")
                    StatusNotice(text: "Your intentions and updates stay on this device. Follow-up notifications use neutral wording.", symbol: "lock")
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity).privacySensitive()
        }.scrollDismissesKeyboard(.interactively).pageStyle().navigationTitle("Intentions").navigationBarTitleDisplayMode(.inline)
            .toolbar { Menu {
                Button("Select intentions") { selecting = true }
                Button("Export all intentions") { selection = Set(services.intentions.entries.map(\.id)); exporting = true }
                Button("Clear all intentions", role: .destructive) { clearing = true }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.disabled(services.intentions.entries.isEmpty).accessibilityLabel("Intention options") }
            .sheet(isPresented: $adding) { IntentionEditor(intention: nil) }
            .sheet(isPresented: $exporting) { PrivateExportView(title: "Intention export", text: IntentionExport.text(selectedEntries)) }
            .confirmationDialog("Delete selected intentions?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete selected intentions", role: .destructive) {
                    for id in selection { services.intentions.delete(id); if services.intentions.errorMessage != nil { break } }
                    selection = selection.intersection(Set(services.intentions.entries.map(\.id))); sync()
                }
            } message: { Text("This deletes selected intentions and their updates and cancels their follow-ups.") }
            .confirmationDialog("Clear every intention?", isPresented: $clearing, titleVisibility: .visible) {
                Button("Clear all intentions", role: .destructive) { if services.intentions.clear() { selection = []; sync() } }
            } message: { Text("This permanently deletes your intentions and updates from this device. Export first if you want a copy.") }
    }
    private func sync() { Task { await services.reminders.syncFollowUps(services.intentions.entries) } }
}

struct IntentionDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var exporting = false
    @State private var deletingUpdate: UUID?
    @State private var update = ""
    @FocusState private var writingUpdate: Bool
    private var intention: PrayerIntention? { services.intentions.entries.first { $0.id == id } }
    var body: some View {
        ScrollView {
            if let intention {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: intention.status.title, title: intention.title)
                    if !intention.note.isEmpty { ReadingText(text: intention.note, scale: services.local.preferences.readingScale) }
                    if !intention.tags.isEmpty { Text(intention.tags.joined(separator: " · ")).foregroundStyle(GraceColor.accent) }
                    if let date = intention.followUpDate {
                        Label("Follow-up: \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell").font(.subheadline)
                        if services.reminders.authorization == .denied { StatusNotice(text: "Notifications are off in system Settings. Your follow-up date is still saved.") }
                    }
                    NavigationLink(value: AppRoute.silence) { Label("Make a little space to pray", systemImage: "hands.sparkles") }.buttonStyle(PrimaryButtonStyle())
                    SectionHeading(title: "Updates and reflections") { EmptyView() }
                    ForEach(intention.updates.sorted { $0.date > $1.date }) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(GraceColor.secondary)
                            Text(item.text).textSelection(.enabled)
                            Button("Delete update", role: .destructive) { deletingUpdate = item.id }.font(.footnote).frame(minHeight: 44)
                        }.graceCard()
                    }
                    TextEditor(text: $update).focused($writingUpdate).frame(minHeight: 140).padding(8).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16)).accessibilityLabel("New intention update").accessibilityIdentifier("intentionUpdate")
                    Button("Save update") { if services.intentions.addUpdate(id, text: update) { update = "" } }.buttonStyle(PrimaryButtonStyle()).disabled(update.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveIntentionUpdate")
                    Text("Use an update to record a change, gratitude, or an answered prayer. Edit the intention to change its status or follow-up.").font(.footnote).foregroundStyle(GraceColor.secondary)
                    if let error = services.intentions.errorMessage { StatusNotice(text: error) }
                }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity).privacySensitive()
            } else { ContentUnavailableView("Intention unavailable", systemImage: "hands.sparkles", description: Text("It may have been deleted, or your private space is locked.")) }
        }.scrollDismissesKeyboard(.interactively).pageStyle().navigationTitle("Your intention").navigationBarTitleDisplayMode(.inline).task { await services.reminders.refreshAuthorization() }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { writingUpdate = false } } }
            .toolbar { Menu { Button("Edit intention") { editing = true }; Button("Export intention") { exporting = true }; Button("Delete intention", role: .destructive) { deleting = true } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Intention options") }
            .sheet(isPresented: $editing) { if let intention { IntentionEditor(intention: intention) } }
            .sheet(isPresented: $exporting) { if let intention { PrivateExportView(title: "Intention export", text: IntentionExport.text([intention])) } }
            .confirmationDialog("Delete this intention?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete intention", role: .destructive) { services.intentions.delete(id); if intention == nil { Task { await services.reminders.syncFollowUps(services.intentions.entries) }; dismiss() } } } message: { Text("This deletes the intention and its updates and cancels its follow-up.") }
            .confirmationDialog("Delete this update?", isPresented: Binding(get: { deletingUpdate != nil }, set: { if !$0 { deletingUpdate = nil } }), titleVisibility: .visible) { Button("Delete update", role: .destructive) { if let deletingUpdate { services.intentions.deleteUpdate(deletingUpdate, intention: id) }; deletingUpdate = nil } }
    }
}

struct IntentionEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let intention: PrayerIntention?
    private let saveID: UUID
    @State private var title: String
    @State private var note: String
    @State private var tags: String
    @State private var status: IntentionStatus
    @State private var followUp: Bool
    @State private var date: Date
    @State private var saving = false
    @State private var message: String?
    init(intention: PrayerIntention?) {
        self.intention = intention
        saveID = intention?.id ?? UUID()
        _title = State(initialValue: intention?.title ?? ""); _note = State(initialValue: intention?.note ?? "")
        _tags = State(initialValue: intention?.tags.joined(separator: ", ") ?? ""); _status = State(initialValue: intention?.status ?? .active)
        let future = (intention?.followUpDate ?? .distantPast) > .now
        _followUp = State(initialValue: future); _date = State(initialValue: future ? intention!.followUpDate! : Date.now.addingTimeInterval(86_400))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("A name or a hope") { TextField("Who is on your heart?", text: $title).accessibilityIdentifier("intentionTitle") }
                Section("A few words, if you like") { TextEditor(text: $note).frame(minHeight: 160).accessibilityLabel("Intention notes") }
                Section("Organization") {
                    TextField("Tags, separated by commas", text: $tags).accessibilityIdentifier("intentionTags")
                    Picker("Status", selection: $status) { ForEach(IntentionStatus.allCases) { Text($0.title).tag($0) } }
                }
                if status == .active {
                    Section("Optional follow-up") {
                        Toggle("Remind me to return", isOn: $followUp)
                        if followUp { DatePicker("Follow-up time", selection: $date, in: Date.now...) }
                        Text("The notification says only: A quiet moment to return to your private prayer space. Quiet hours may move delivery later. Up to ten follow-ups can be scheduled.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section { Label("Private · Saved only on this device", systemImage: "lock").font(.footnote) }
                if let error = message ?? services.intentions.errorMessage { Text(error).foregroundStyle(.red) }
            }.privacySensitive().scrollDismissesKeyboard(.interactively).navigationTitle(intention == nil ? "A new intention" : "Edit intention").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving).accessibilityIdentifier("saveIntention")
                    }
                }
        }
    }
    private func save() async {
        saving = true; defer { saving = false }; message = nil
        if followUp, status == .active, !(await services.reminders.requestPermission()) { message = "Allow notifications in system Settings, or turn off the follow-up to save without a reminder."; return }
        guard services.intentions.upsert(id: saveID, title: title, note: note, tags: PracticeRules.tags(tags), status: status, followUpDate: followUp && status == .active ? date : nil, quietStart: services.reminders.quietStart, quietEnd: services.reminders.quietEnd) else { return }
        if await services.reminders.syncFollowUps(services.intentions.entries) { dismiss() }
        else { message = services.reminders.errorMessage }
    }
}
