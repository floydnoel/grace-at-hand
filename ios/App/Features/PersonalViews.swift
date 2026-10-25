import SwiftUI
import GraceCore

struct MyPrayerView: View {
    @Environment(AppServices.self) private var services
    private let resources: [(String, String, String, AppRoute)] = [
        ("Saved prayers", "Return to the familiar", "heart", .saved),
        ("Downloads", "Ready without Wi-Fi", "arrow.down.to.line", .downloads),
        ("My intentions", "Private, just for you", "hands.sparkles", .intentions),
        ("Reminders", "A gentle invitation", "bell", .reminders)
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: "A place to return", title: "My prayer")
                HStack(spacing: 16) { Image(systemName: "leaf").font(.title2).frame(width: 48, height: 48).background(GraceColor.card, in: Circle()); VStack(alignment: .leading, spacing: 7) { Text("Your quiet corner").font(.body.weight(.semibold)); Text("Saved on this device").font(.caption).foregroundStyle(GraceColor.secondary) } }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 24))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(resources, id: \.0) { title, subtitle, symbol, route in
                        NavigationLink(value: route) {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: symbol).font(.title2.weight(.light)).foregroundStyle(GraceColor.accent)
                                Text(title).font(.body.weight(.semibold)); Text(subtitle).font(.caption).foregroundStyle(GraceColor.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading).graceCard(padding: 18)
                        }.buttonStyle(.plain).accessibilityIdentifier("resource-\(title)")
                    }
                }
                SectionHeading(title: "Your next small step") { EmptyView() }
                if let journey = services.catalog.catalog.journeys.first,
                   let id = journey.itemIDs.first(where: { services.local.record($0)?.completed != true }), let prayer = services.prayer(id) {
                    NavigationLink(value: AppRoute.prayer(id)) { VStack(alignment: .leading, spacing: 12) { Eyebrow(text: "A beginning in prayer"); Text(prayer.title).font(.system(.title, design: .serif)); Text("\(prayer.durationLabel) · Ready whenever you are").font(.subheadline).foregroundStyle(GraceColor.secondary) }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 24)) }.buttonStyle(.plain)
                } else { BeginnerCard() }
                NavigationLink(value: AppRoute.history) { Label("Recent prayers", systemImage: "clock").frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) }.buttonStyle(.plain)
                NavigationLink(value: AppRoute.support) { Label("Daily prayer. Freely shared.", systemImage: "leaf").frame(maxWidth: .infinity, minHeight: 48, alignment: .leading) }.buttonStyle(.plain)
                Text("Begin again wherever you are.").font(.system(.body, design: .serif)).foregroundStyle(GraceColor.secondary).padding(.vertical, 12)
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.rememberScroll("my-prayer").pageStyle().navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: AppRoute.settings) { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("Settings") } }
    }
}

struct SavedPrayersView: View {
    @Environment(AppServices.self) private var services
    private var prayers: [Prayer] { services.local.records.filter(\.favorite).compactMap { services.prayer($0.itemID) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Close at hand", title: "Saved prayers")
                if prayers.isEmpty {
                    GraceEmpty(symbol: "heart", title: "A familiar prayer,\nclose at hand.", message: "Save any prayer to find it here. Saving and downloading are separate choices.")
                    NavigationLink("Explore prayers", value: AppRoute.search).buttonStyle(PrimaryButtonStyle())
                }
                ForEach(prayers) { prayer in NavigationLink(value: AppRoute.prayer(prayer.id)) { PrayerRow(prayer: prayer, downloaded: services.downloads.isAvailable(prayer)) }.buttonStyle(.plain); Divider() }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}

struct DownloadAction: View {
    @Environment(AppServices.self) private var services
    let prayer: Prayer
    var body: some View {
        if let record = services.downloads.record(prayer.id), record.state == .downloading || record.state == .verifying {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: record.progress).accessibilityLabel("Download progress").accessibilityValue("\(Int(record.progress * 100)) percent")
                HStack { Text(record.state == .verifying ? "Checking download…" : "Downloading · \(Int(record.progress * 100))%").font(.caption); Spacer(); Button("Cancel") { services.downloads.cancel(prayer.id) }.font(.caption).frame(minHeight: 44) }
            }
        } else if services.downloads.isAvailable(prayer) {
            HStack { Label("Available offline", systemImage: "checkmark.circle").font(.subheadline); Spacer(); Text(ByteCountFormatter.string(fromByteCount: prayer.audio?.bytes ?? 0, countStyle: .file)).font(.caption).foregroundStyle(GraceColor.secondary) }.padding(.vertical, 10)
        } else if prayer.audio != nil {
            VStack(alignment: .leading, spacing: 8) {
                Button { services.download(prayer) } label: { Label(services.downloads.record(prayer.id)?.state == .failed ? "Retry download" : "Download for offline prayer", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity, minHeight: 48) }.accessibilityIdentifier("downloadPrayer")
                if let message = services.downloads.record(prayer.id)?.message { Text(message).font(.caption).foregroundStyle(GraceColor.secondary) }
            }
        }
    }
}

struct DownloadsView: View {
    @Environment(AppServices.self) private var services
    @State private var removing: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "A little quiet, wherever you are", title: "Downloads")
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("\(services.downloads.available.count) prayers available offline").font(.subheadline.weight(.semibold)); Spacer(); Text(ByteCountFormatter.string(fromByteCount: services.downloads.totalBytes, countStyle: .file)).font(.caption) }
                    Text("Audio and prayer text saved together").font(.caption).foregroundStyle(GraceColor.secondary)
                }.padding(20).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 20))
                Toggle("Download on Wi-Fi only", isOn: Binding(get: { services.local.preferences.wifiOnly }, set: { services.local.preferences.wifiOnly = $0; services.local.save(); services.downloads.updatePolicy(wifiOnly: $0) })).padding(.vertical, 8)
                if let error = services.downloads.errorMessage { StatusNotice(text: error, symbol: "exclamationmark.circle") }
                if services.downloads.records.isEmpty {
                    GraceEmpty(symbol: "arrow.down.to.line", title: "Bring a little quiet\nwith you.", message: "Download a prayer to listen offline. Downloads are always free.")
                    NavigationLink("Find a prayer", value: AppRoute.search).buttonStyle(PrimaryButtonStyle())
                } else {
                    SectionHeading(title: "Ready to listen") { EmptyView() }
                    ForEach(services.downloads.records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                NavigationLink(value: AppRoute.prayer(record.id)) { PrayerRow(prayer: record.prayer, downloaded: services.downloads.isAvailable(record.prayer)) }.buttonStyle(.plain)
                                Menu {
                                    if services.downloads.isAvailable(record.prayer) { Button("Play downloaded prayer") { Task { await services.play(record.prayer) } } }
                                    Button("Remove download", role: .destructive) { removing = record.id }
                                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Options for \(record.prayer.title)")
                            }
                            DownloadAction(prayer: record.target)
                            if let message = record.message, record.state == .available { Text(message).font(.caption).foregroundStyle(GraceColor.secondary) }
                        }
                        Divider()
                    }
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Remove this download?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("Remove download", role: .destructive) { if let removing { services.downloads.remove(removing) }; removing = nil }
            } message: { Text("Your saved favorite will remain. You can download this recording again.") }
    }
}

struct IntentionsView: View {
    @Environment(AppServices.self) private var services
    @State private var editing: PrayerIntention?
    @State private var showingEditor = false
    @State private var deleting: PrayerIntention?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Private · On this device", title: services.intentions.entries.isEmpty ? "My intentions" : "On your heart.", subtitle: "People and hopes to bring to prayer.")
                if services.intentions.isLocked { GraceEmpty(symbol: "lock", title: "A private space.", message: "Unlock your device to return to your intentions.") }
                else if let error = services.intentions.errorMessage { StatusNotice(text: error, symbol: "lock"); Button("Try again") { services.intentions.load() } }
                else {
                    if services.intentions.entries.isEmpty { GraceEmpty(symbol: "hands.sparkles", title: "Who is on\nyour heart?", message: "You can begin with a name, a hope, or a few words.") }
                    ForEach(services.intentions.entries) { intention in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(intention.title).font(.headline).privacySensitive()
                                Spacer()
                                Menu {
                                    Button("Edit intention") { editing = intention; showingEditor = true }
                                    Button("Delete intention", role: .destructive) { deleting = intention }
                                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Intention options")
                            }
                            if !intention.note.isEmpty { Text(intention.note).foregroundStyle(GraceColor.secondary).privacySensitive() }
                            HStack {
                                Text(intention.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(GraceColor.secondary)
                                Spacer(); NavigationLink(value: AppRoute.silence) { Label("Pray", systemImage: "hands.sparkles").font(.subheadline).frame(minHeight: 44) }
                            }
                        }.graceCard()
                    }
                    Button { editing = nil; showingEditor = true } label: { Label("Add an intention", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addIntention")
                    StatusNotice(text: "Your intentions stay on this device. No account or sharing is needed.", symbol: "lock")
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditor) { IntentionEditor(intention: editing) }
            .confirmationDialog("Delete this intention?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("Delete intention", role: .destructive) { if let deleting { services.intentions.delete(deleting.id) }; deleting = nil } } message: { Text("This removes it from this device. There is no cloud copy.") }
    }
}

struct IntentionEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let intention: PrayerIntention?
    @State private var title: String
    @State private var note: String
    init(intention: PrayerIntention?) { self.intention = intention; _title = State(initialValue: intention?.title ?? ""); _note = State(initialValue: intention?.note ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                Section("A name or a hope") { TextField("Who is on your heart?", text: $title).privacySensitive().accessibilityIdentifier("intentionTitle") }
                Section("A few words, if you like") { TextEditor(text: $note).frame(minHeight: 160).privacySensitive().accessibilityLabel("Intention notes") }
                Section { Label("Private · Saved only on this device", systemImage: "lock").font(.footnote); if let error = services.intentions.errorMessage { Text(error).foregroundStyle(.red) } }
            }.navigationTitle(intention == nil ? "A new intention" : "Edit intention").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { if services.intentions.upsert(id: intention?.id, title: title, note: note) { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveIntention") }
                }
        }
    }
}

struct HistoryView: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Begin wherever you are", title: "Recent prayers")
                if services.local.recent.isEmpty { GraceEmpty(symbol: "clock", title: "A gentle return.", message: services.local.preferences.keepHistory ? "The prayers you listen to can be found here. Your activity stays on this device." : "Recent activity is turned off. Your saved prayers and downloads are still available.") }
                ForEach(services.local.recent, id: \.itemID) { record in
                    if let prayer = services.prayer(record.itemID) {
                        HStack { NavigationLink(value: AppRoute.prayer(prayer.id)) { PrayerRow(prayer: prayer) }.buttonStyle(.plain); Button { services.local.removeHistory(record.itemID) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Remove \(prayer.title) from history") }
                        Divider()
                    }
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}

struct RemindersView: View {
    @Environment(AppServices.self) private var services
    @State private var editing: PrayerReminder?
    @State private var showingEditor = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Gentle by choice", title: "Make a little space.", subtitle: "Choose when you’d like a quiet reminder.")
                if services.reminders.authorization == .denied {
                    StatusNotice(text: "Reminders are off. You can enable them in Settings.", symbol: "bell.slash")
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!).frame(minHeight: 44)
                }
                ForEach(services.reminders.reminders) { reminder in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(String(format: "%02d:%02d", reminder.hour, reminder.minute)).font(.system(.largeTitle, design: .serif)).monospacedDigit()
                            Spacer()
                            Menu { Button("Edit") { editing = reminder; showingEditor = true }; Button("Delete reminder", role: .destructive) { services.reminders.delete(reminder.id) } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Reminder options")
                        }
                        Text(services.prayer(reminder.prayerID)?.title ?? "A moment for prayer").font(.subheadline)
                        Text(reminder.weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " · ")).font(.caption).foregroundStyle(GraceColor.secondary)
                        Toggle("Reminder enabled", isOn: Binding(get: { reminder.enabled }, set: { enabled in var updated = reminder; updated.enabled = enabled; Task { _ = await services.reminders.save(updated) } }))
                    }.graceCard()
                }
                Button { editing = nil; showingEditor = true } label: { Label("Add a reminder", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle())
                StatusNotice(text: "A moment for prayer, when you’re ready.\n\nNotifications never include private intention text.", symbol: "bell")
                if let error = services.reminders.errorMessage { Text(error).font(.footnote).foregroundStyle(GraceColor.secondary) }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline).task { await services.reminders.refreshAuthorization() }
            .sheet(isPresented: $showingEditor) { ReminderEditor(reminder: editing) }
    }
}

struct ReminderEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let reminder: PrayerReminder?
    @State private var time: Date
    @State private var days: Set<Int>
    @State private var prayerID: String
    @State private var saving = false
    init(reminder: PrayerReminder?) {
        self.reminder = reminder
        _time = State(initialValue: Calendar.current.date(bySettingHour: reminder?.hour ?? 7, minute: reminder?.minute ?? 0, second: 0, of: .now) ?? .now)
        _days = State(initialValue: Set(reminder?.weekdays ?? [2, 3, 4, 5, 6]))
        _prayerID = State(initialValue: reminder?.prayerID ?? "morning-offering")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("When you’d like a quiet reminder") { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                Section("Chosen days") { ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { days.contains(day) }, set: { if $0 { days.insert(day) } else { days.remove(day) } })) } }
                Section("Prayer") { Picker("Prayer", selection: $prayerID) { ForEach(services.catalog.catalog.items) { Text($0.title).tag($0.id) } } }
                Section("Quiet hours") { Text("\(formatted(services.local.preferences.quietStart)) – \(formatted(services.local.preferences.quietEnd))"); Text("Change quiet hours in Settings. Times inside quiet hours are not scheduled.").font(.footnote).foregroundStyle(.secondary) }
                Section("Notification preview") { Label("Grace at Hand\nA moment for prayer, when you’re ready.", systemImage: "leaf"); Text("Your reminder won’t include private intention text.").font(.footnote).foregroundStyle(.secondary) }
                if let error = services.reminders.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            }.navigationTitle("Gentle reminder").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saving ? "Saving…" : "Set reminder") {
                            saving = true
                            let calendar = Calendar.current
                            let value = PrayerReminder(id: reminder?.id ?? UUID(), hour: calendar.component(.hour, from: time), minute: calendar.component(.minute, from: time), weekdays: days.sorted(), prayerID: prayerID, enabled: true)
                            Task { let saved = await services.reminders.save(value); saving = false; if saved { dismiss() } }
                        }.disabled(days.isEmpty || saving)
                    }
                }
        }
    }
    private func formatted(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @State private var clearHistory = false
    @State private var reset = false
    @State private var showPreferences = false
    var body: some View {
        @Bindable var preferences = services.local.preferences
        Form {
            Section("Your experience") {
                Picker("Appearance", selection: $preferences.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                ReadingControls()
                LabeledContent("Content language", value: "English")
                LabeledContent("Calendar", value: "US · Latin rite")
                Button("Prayer preferences") { showPreferences = true }
                NavigationLink("Reminders", value: AppRoute.reminders)
            }
            Section("Quiet hours") {
                DatePicker("Begin", selection: minuteBinding(\.quietStart), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: minuteBinding(\.quietEnd), displayedComponents: .hourAndMinute)
                Text("Reminders within these hours are suppressed. Equal start and end times turn quiet hours off.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Private by default") {
                NavigationLink { PrivacyView() } label: { Label("Privacy & data", systemImage: "lock") }
                Toggle("Keep recent activity", isOn: $preferences.keepHistory)
                Button("Clear local activity", role: .destructive) { clearHistory = true }
                Button("Reset all local data", role: .destructive) { reset = true }
                Text("Intentions and activity stay on this device and are excluded from cloud backup. Deleting the app removes them. Downloads can be saved again.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Help & support") {
                NavigationLink("Daily prayer. Freely shared.", value: AppRoute.support)
                NavigationLink { HelpView() } label: { Text("Playback and download help") }
                ShareLink(item: services.diagnosticReport) { Label("Share diagnostic report", systemImage: "square.and.arrow.up") }
                if let email = services.configuration.helpEmail, let url = URL(string: "mailto:\(email)") { Link("Contact support", destination: url) }
            }
            Section {
                LabeledContent("Version", value: "0.1.0")
                if services.catalog.catalog.isFixture { Text("Development preview. Audio, passages, and calendar entries are fixtures pending production review.").font(.footnote).foregroundStyle(.secondary) }
                if let error = services.local.errorMessage { Text(error).foregroundStyle(.red) }
            }
        }.scrollContentBackground(.hidden).pageStyle().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .onChange(of: preferences.appearance) { _, _ in services.local.save() }
            .onChange(of: preferences.keepHistory) { _, enabled in if !enabled { services.local.clearHistory() }; services.local.save() }
            .sheet(isPresented: $showPreferences) { PreferencesView() }
            .confirmationDialog("Clear local activity?", isPresented: $clearHistory, titleVisibility: .visible) {
                Button("Clear activity", role: .destructive) { services.playback.dismissCurrent(); services.local.clearHistory() }
            } message: { Text("This removes recent listening, positions, and beginner progress. Saved prayers, passages, intentions, and downloads remain.") }
            .confirmationDialog("Reset all local data?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reset this device", role: .destructive) { services.reset() }
            } message: { Text("This permanently deletes intentions, saved prayers and passages, activity, settings, downloads, and reminders from this device.") }
    }
    private func minuteBinding(_ keyPath: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Date> {
        Binding(get: { let minutes = services.local.preferences[keyPath: keyPath]; return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now }, set: { date in
            services.local.preferences[keyPath: keyPath] = Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
            services.local.save(); services.reminders.quietStart = services.local.preferences.quietStart; services.reminders.quietEnd = services.local.preferences.quietEnd
            Task { await services.reminders.reschedule() }
        })
    }
}

struct PrivacyView: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "Private by default", title: "A space that’s yours.")
            Text("Your intentions, saved prayers, bookmarks, reminders, and listening activity stay on this device. There is no account or synchronization in this version.")
            Text("Personal data is excluded from cloud backup. Intentions use locked-device file protection. Audio downloads remain available for listening with the screen locked.")
            Text("The app requests public catalog and media files when you refresh, stream, or download. The hosting provider receives ordinary network information such as your IP address. Private intentions, search terms, and listening history are not included in those requests.")
            Text("There are no advertising or behavioral analytics SDKs. You can choose to share a diagnostic report or contact support. Review the report before sharing it.")
            Text("You can delete individual intentions and downloads, clear activity, or reset all local data in Settings. Removing the app deletes its local prayer data.")
            if let url = services.configuration.privacyURL { Link("Read the privacy policy", destination: url) }
        }.lineSpacing(5).padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity) }.pageStyle().navigationTitle("Privacy & data").navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeading(eyebrow: "A little help", title: "Keep a prayer close.")
            help("Listening offline", "Download a recording from its prayer page. Wait for Available offline before disconnecting. Audio and text are saved together; saving a favorite alone does not download it.")
            help("When audio won’t play", "Check your audio output and volume, then retry. You can still read the prayer. A call or disconnected headphones may pause playback to preserve your place.")
            help("An interrupted download", "Open Downloads and choose Retry. If Wi-Fi-only is on, a transfer may wait for Wi-Fi. Free some storage if the device is full. Force-quitting can interrupt background transfers; reopen the app to recover them.")
            help("Reminders", "Choose a time outside quiet hours. If permission is denied, open system Settings to enable notifications. Snoozed reminders respect quiet hours.")
            help("Report a problem", "Settings lets you share a diagnostic report containing app and connection information. It excludes your private writing and prayer history. Include the affected prayer title yourself if you want to report a content issue.")
        }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity) }.pageStyle().navigationTitle("Help").navigationBarTitleDisplayMode(.inline)
    }
    private func help(_ title: String, _ text: String) -> some View { VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(.title2, design: .serif)); Text(text).foregroundStyle(GraceColor.secondary).lineSpacing(5) } }
}

struct SupportView: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Image(systemName: "leaf").font(.system(size: 32, weight: .light)).foregroundStyle(GraceColor.gold).frame(width: 84, height: 104).overlay(ArchShape().stroke(GraceColor.gold, lineWidth: 1)).padding(.top, 24)
                Eyebrow(text: "Daily prayer. Freely shared.")
                Text("Free to pray.\nSupported together.").font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                Text("Every published prayer is freely available. Optional support helps make room for the work behind it.").foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center).lineSpacing(5)
                if services.canSupport, let url = services.configuration.supportURL {
                    Link(destination: url) { Label("Support development", systemImage: "heart") }.buttonStyle(PrimaryButtonStyle())
                    Text("Opens your browser. Support goes to the developer and does not unlock content. Check the amount, currency, and frequency on the support page before paying.").font(.caption).foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center)
                }
                Divider()
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "Your support makes room for")
                    Label("Thoughtful recordings and reliable offline listening", systemImage: "headphones")
                    Label("Editorial and theological review", systemImage: "book")
                    Label("Translations and accessibility", systemImage: "globe")
                    Label("Hosting and ongoing app maintenance", systemImage: "leaf")
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text("Giving is always optional. Prayer always remains free.").font(.system(.body, design: .serif)).multilineTextAlignment(.center).foregroundStyle(GraceColor.secondary)
            }.padding(28).frame(maxWidth: 580).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}
