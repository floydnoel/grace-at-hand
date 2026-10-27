import SwiftUI
import GraceCore

struct ActivityView: View {
    @Environment(AppServices.self) private var services
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var day = Date.now
    @State private var manual: PracticeSession?
    @State private var showManual = false
    @State private var deleting: UUID?
    @State private var clearing = false
    @State private var writing: JournalLink?
    private var sessions: [PracticeSession] {
        services.practice.document.sessions.filter { $0.day == LocalDay.key(day) }.sorted { $0.date > $1.date }
    }
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "Private · On this device", title: "Prayer activity", subtitle: "A record to return to, at your own pace.")
                    Toggle("Show calendar and progress", isOn: Binding(get: { services.practice.document.showProgress }, set: { services.practice.setProgressVisible($0) }))
                    Toggle("Show optional day streak", isOn: Binding(get: { services.practice.document.showStreaks }, set: { services.practice.setStreaks($0) }))
                    if !services.local.preferences.keepHistory {
                        StatusNotice(text: "Activity recording is off. Enable Keep prayer activity in Settings to record completions or add a prayer outside the app.")
                        NavigationLink("Open Settings", value: AppRoute.settings)
                    }
                    if services.practice.document.showProgress {
                        if services.practice.document.showStreaks {
                            let streak = PracticeRules.streak(sessions: services.practice.document.sessions)
                            Text("\(streak) consecutive prayer days").font(.system(.title2, design: .serif))
                            Text("Today stays open. You can add a prayer you made outside the app, including on an earlier day.").font(.footnote).foregroundStyle(GraceColor.secondary)
                        }
                        ActivityCalendar(month: $month, selected: $day, sessions: services.practice.document.sessions)
                        Text(day.formatted(date: .abbreviated, time: .omitted)).font(.system(.title2, design: .serif))
                            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                        if sessions.isEmpty { Text("No prayer activity recorded for this day.").foregroundStyle(GraceColor.secondary) }
                        ForEach(sessions) { session in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(session.title).font(.headline)
                                Text("\(session.date.formatted(date: .omitted, time: .shortened)) · \(session.source.rawValue.capitalized)\(session.durationSeconds > 0 ? " · \(max(1, Int(ceil(session.durationSeconds / 60)))) min" : "")").font(.caption).foregroundStyle(GraceColor.secondary)
                                PracticeActions {
                                    Button("Reflect") { writing = JournalLink(kind: .session, id: session.id.uuidString, title: session.title) }.frame(minHeight: 44)
                                    if session.source == .manual { Button("Edit") { manual = session; showManual = true }.frame(minHeight: 44) }
                                    Button("Delete", role: .destructive) { deleting = session.id }.frame(minHeight: 44)
                                }
                                if let id = session.prayerID, services.prayer(id) != nil { NavigationLink("Return to prayer", value: AppRoute.prayer(id)).frame(minHeight: 44) }
                            }.graceCard()
                        }
                    } else { StatusNotice(text: "Your calendar, session list, goal counts, and streak are hidden. Recording follows your activity setting.") }
                    Button("Log a prayer outside the app") { manual = nil; showManual = true }.buttonStyle(PrimaryButtonStyle()).disabled(!services.local.preferences.keepHistory).accessibilityIdentifier("logManualPrayer")
                    Button("Clear all prayer activity", role: .destructive) { clearing = true }.frame(minHeight: 44)
                    Text("Audio completions, prayers marked complete, finished silence timers, and your manual entries appear here. Listening history remains in Recent prayers.").font(.footnote).foregroundStyle(GraceColor.secondary)
                    PracticeErrorNotice()
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.pageStyle().navigationTitle("Activity").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showManual) { ManualPrayerEditor(session: manual, day: day) }
                .sheet(item: $writing) { link in JournalEditor(link: link) }
                .confirmationDialog("Delete this activity entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Delete entry", role: .destructive) { if let deleting { services.practice.deleteSession(deleting) }; deleting = nil }
                } message: { Text("Goal counts and optional streaks will update. Connected journal writing remains.") }
                .confirmationDialog("Clear all prayer activity?", isPresented: $clearing, titleVisibility: .visible) {
                    Button("Clear activity", role: .destructive) { services.clearActivity() }
                } message: { Text("This removes activity, listening positions, and beginner progress. Routines, goals, journal, intentions, and favorites remain.") }
        }
    }
}

struct ActivityCalendar: View {
    @Binding var month: Date
    @Binding var selected: Date
    let sessions: [PracticeSession]
    @ScaledMetric(relativeTo: .body) private var dayFontSize = 17.0
    private let calendar = Calendar.current
    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month), let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: interval.start) + 5) % 7
        return Array(repeating: nil, count: offset) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }.map(Optional.some)
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous activity month").accessibilityIdentifier("previousActivityMonth")
                Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.headline); Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month)).accessibilityLabel("Next activity month").accessibilityIdentifier("nextActivityMonth")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { value in Text(calendar.veryShortWeekdaySymbols[value - 1]).font(.caption2).accessibilityLabel(calendar.weekdaySymbols[value - 1]) }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let count = sessions.filter { $0.day == LocalDay.key(date) }.count
                        Button { selected = date } label: {
                            VStack(spacing: 2) {
                                Text("\(calendar.component(.day, from: date))").font(.system(size: min(dayFontSize, 24))).lineLimit(1).minimumScaleFactor(0.6)
                                Image(systemName: count > 0 ? "checkmark" : "minus").font(.system(size: 9)).accessibilityHidden(true)
                            }.frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(calendar.isDate(date, inSameDayAs: selected) ? GraceColor.buttonText : GraceColor.ink)
                                .background(calendar.isDate(date, inSameDayAs: selected) ? GraceColor.button : GraceColor.wash, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).disabled(date > .now)
                            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(count) prayer entries")
                            .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selected) ? .isSelected : [])
                    } else { Color.clear.frame(minHeight: 44).accessibilityHidden(true) }
                }
            }
        }
    }
    private func move(_ offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: month) { month = next; selected = next }
    }
}

struct ManualPrayerEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    private let original: PracticeSession?
    @State private var title: String
    @State private var date: Date
    @State private var minutes: Int
    init(session: PracticeSession? = nil, day: Date = .now) {
        original = session
        _title = State(initialValue: session?.title ?? "")
        let calendar = Calendar.current
        let chosenTime = calendar.date(bySettingHour: calendar.component(.hour, from: .now), minute: calendar.component(.minute, from: .now), second: 0, of: day) ?? day
        _date = State(initialValue: session?.date ?? min(chosenTime, .now))
        _minutes = State(initialValue: max(1, Int((session?.durationSeconds ?? 300) / 60)))
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Prayer or practice", text: $title).accessibilityIdentifier("manualPrayerTitle")
                DatePicker("When you prayed", selection: $date, in: ...Date.now)
                Stepper("\(minutes) minutes", value: $minutes, in: 1...1440)
                Text("Record a prayer outside the app or add one from an earlier day. It counts toward that day’s goals and optional streak.").font(.footnote).foregroundStyle(.secondary)
                if let error = services.practice.errorMessage { Text(error).foregroundStyle(.red) }
            }.navigationTitle(original == nil ? "Log a prayer" : "Edit prayer activity").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let session = PracticeSession(id: original?.id ?? UUID(), date: date, title: title.trimmingCharacters(in: .whitespacesAndNewlines), durationSeconds: Double(minutes * 60), source: .manual, sourceID: original?.sourceID ?? UUID().uuidString)
                            if services.local.preferences.keepHistory, services.practice.saveManual(session) { dismiss() }
                        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !services.local.preferences.keepHistory).accessibilityIdentifier("saveManualPrayer")
                    }
                }
        }
    }
}
