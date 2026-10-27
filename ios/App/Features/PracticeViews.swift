import SwiftUI
import GraceCore

struct PrivatePracticeContent<Content: View>: View {
    @Environment(AppServices.self) private var services
    @State private var reset = false
    @ViewBuilder var content: Content
    var body: some View {
        Group {
            if services.practice.isLocked { ContentUnavailableView("A private space", systemImage: "lock", description: Text("Unlock your device to open your practice records.")) }
            else if services.practice.needsRecovery {
                VStack(spacing: 20) {
                    StatusNotice(text: services.practice.errorMessage ?? "Your records could not be opened.")
                    Button("Try opening again") { services.practice.load() }.buttonStyle(PrimaryButtonStyle())
                    Button("Reset practice records", role: .destructive) { reset = true }
                }.padding(24)
            } else { content }
        }.confirmationDialog("Delete all practice records?", isPresented: $reset, titleVisibility: .visible) {
            Button("Reset practice records", role: .destructive) { services.resetPracticeRecords() }
        } message: { Text("This deletes routines, goals, activity, and journal entries on this device. Intentions, favorites, and downloads remain.") }
    }
}

struct PracticeErrorNotice: View {
    @Environment(AppServices.self) private var services
    var body: some View { if let error = services.practice.errorMessage { StatusNotice(text: error) } }
}

struct PracticeActions<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @ViewBuilder var content: Content
    var body: some View {
        let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 16))
        layout { content }
    }
}

struct AppLockedView: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield").font(.system(size: 48, weight: .light)).foregroundStyle(GraceColor.accent)
                Text("Your private prayer space").font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                Text("Unlock with Face ID, Touch ID, or your device passcode.").foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center)
                Button(services.appLock.authenticating ? "Unlocking…" : "Unlock prayer space") { Task { await services.unlockPrivateSpace() } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(services.appLock.authenticating).accessibilityIdentifier("unlockPrayerSpace")
                if let message = services.appLock.errorMessage { StatusNotice(text: message) }
            }.padding(28).frame(maxWidth: 500).frame(maxWidth: .infinity).padding(.top, 100)
        }.pageStyle()
    }
}

struct RoutinesView: View {
    @Environment(AppServices.self) private var services
    @State private var adding = false
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "Your own rhythm", title: "Prayer routines", subtitle: "Bring familiar prayers together. Choose the days that suit your life.")
                    if services.practice.document.routines.isEmpty { GraceEmpty(symbol: "sun.and.horizon", title: "Make a little space.", message: "Build a morning, midday, or evening routine. You can change it whenever you need.") }
                    ForEach(services.practice.document.routines) { routine in
                        NavigationLink(value: AppRoute.routine(routine.id)) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(routine.title).font(.headline)
                                Text("\(routine.period.title) · \(routine.prayerIDs.count) prayers\(routine.enabled ? "" : " · Paused")").font(.subheadline).foregroundStyle(GraceColor.secondary)
                                Text(routine.weekdays.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " · ")).font(.caption).foregroundStyle(GraceColor.secondary)
                            }.graceCard()
                        }.buttonStyle(.plain)
                    }
                    Button("Create a routine") { adding = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("createRoutine")
                    PracticeErrorNotice()
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.pageStyle().navigationTitle("Routines").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $adding) { RoutineEditor() }
        }
    }
}

struct RoutineDetailView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var editing = false
    @State private var deleting = false
    private var routine: PrayerRoutine? { services.practice.document.routines.first { $0.id == id } }
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                if let routine {
                    let completed = services.practice.completedIDs(for: id)
                    let next = routine.prayerIDs.first { !completed.contains($0) && services.prayer($0) != nil }
                    VStack(alignment: .leading, spacing: 22) {
                        PageHeading(eyebrow: routine.period.title, title: routine.title, subtitle: routine.isScheduled(on: .now) ? "A little space for today." : "You can return to this routine on any day.")
                        if services.local.preferences.keepHistory {
                            Text("\(routine.prayerIDs.filter { completed.contains($0) }.count) of \(routine.prayerIDs.count) prayed today").font(.subheadline)
                        } else { StatusNotice(text: "Activity is off. You can read and listen; enable activity in Settings to save routine completion.") }
                        if let next, let prayer = services.prayer(next) {
                            if prayer.audio != nil {
                                Button("Start next prayer") { Task { await services.play(prayer, routineID: id) } }.buttonStyle(PrimaryButtonStyle())
                            } else { NavigationLink("Read next prayer", value: AppRoute.routineReader(next, id)).buttonStyle(PrimaryButtonStyle()) }
                        }
                        ForEach(Array(routine.prayerIDs.enumerated()), id: \.element) { index, prayerID in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prayer \(index + 1)").font(.caption).foregroundStyle(GraceColor.secondary)
                                if let prayer = services.prayer(prayerID) {
                                    NavigationLink(value: AppRoute.prayer(prayerID)) { Text(prayer.title).font(.headline) }
                                    PracticeActions {
                                        if prayer.audio != nil { Button("Listen") { Task { await services.play(prayer, routineID: id) } }.frame(minHeight: 44) }
                                        NavigationLink("Read", value: AppRoute.routineReader(prayerID, id)).frame(minHeight: 44)
                                    }
                                    if services.local.preferences.keepHistory {
                                        Button {
                                            if completed.contains(prayerID) { services.practice.undoRoutinePrayer(prayerID, routineID: id) }
                                            else { services.recordPractice(PracticeSession(title: prayer.title, durationSeconds: 0, source: .routine, sourceID: "routine:\(id):\(prayerID):\(LocalDay.key(.now))", prayerID: prayerID, routineID: id)) }
                                        } label: { Label(completed.contains(prayerID) ? "Prayed today · undo" : "Mark prayed today", systemImage: completed.contains(prayerID) ? "checkmark.circle.fill" : "circle") }.frame(minHeight: 44)
                                    }
                                } else { Text("This prayer is unavailable. Edit the routine to replace it.").foregroundStyle(GraceColor.secondary) }
                            }.graceCard()
                        }
                        Text("Move at your own pace. Each prayer opens on its own; completion is saved for the day you pray.").font(.footnote).foregroundStyle(GraceColor.secondary)
                        PracticeErrorNotice()
                    }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
                }
            }.pageStyle().navigationTitle("Your routine").navigationBarTitleDisplayMode(.inline)
                .toolbar { Menu { Button("Edit routine") { editing = true }; Button("Delete routine", role: .destructive) { deleting = true } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Routine options") }
                .sheet(isPresented: $editing) { if let routine { RoutineEditor(routine: routine) } }
                .confirmationDialog("Delete this routine?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete routine", role: .destructive) { if services.practice.deleteRoutine(id) { dismiss() } } } message: { Text("Your recorded activity and journal entries remain.") }
        }
    }
}

struct RoutineEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var routine: PrayerRoutine
    @State private var choosing = false
    init(routine: PrayerRoutine? = nil) { _routine = State(initialValue: routine ?? PrayerRoutine(title: "")) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your routine") {
                    TextField("Routine name", text: $routine.title).accessibilityIdentifier("routineName")
                    Picker("Time of day", selection: $routine.period) { ForEach(PrayerPeriod.allCases) { Text($0.title).tag($0) } }
                    Toggle("Show on scheduled days", isOn: $routine.enabled)
                }
                Section("Chosen days") {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                        Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { routine.weekdays.contains(day) }, set: { if $0 { routine.weekdays.append(day) } else { routine.weekdays.removeAll { $0 == day } } }))
                    }
                }
                Section("Prayers in order") {
                    ForEach(routine.prayerIDs, id: \.self) { id in Text(services.prayer(id)?.title ?? "Unavailable prayer") }
                        .onMove { routine.prayerIDs.move(fromOffsets: $0, toOffset: $1) }.onDelete { routine.prayerIDs.remove(atOffsets: $0) }
                    Button("Add prayers") { choosing = true }.accessibilityIdentifier("addRoutinePrayers")
                    Text("Use Edit to reorder or remove prayers. Routine schedules do not create notifications; choose reminders separately.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error = services.practice.errorMessage { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Build a routine").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { EditButton() }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { routine.title = routine.title.trimmingCharacters(in: .whitespacesAndNewlines); if services.practice.saveRoutine(routine) { dismiss() } }.disabled(routine.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.prayerIDs.isEmpty || routine.weekdays.isEmpty).accessibilityIdentifier("saveRoutine") }
                }
                .sheet(isPresented: $choosing) {
                    NavigationStack {
                        List(services.catalog.catalog.items) { prayer in
                            Button {
                                if routine.prayerIDs.contains(prayer.id) { routine.prayerIDs.removeAll { $0 == prayer.id } }
                                else { routine.prayerIDs.append(prayer.id) }
                            } label: { HStack { Text(prayer.title); Spacer(); if routine.prayerIDs.contains(prayer.id) { Image(systemName: "checkmark") } } }
                                .accessibilityValue(routine.prayerIDs.contains(prayer.id) ? "Selected" : "Not selected")
                        }.navigationTitle("Choose prayers").toolbar { Button("Done") { choosing = false } }
                    }
                }
        }
    }
}

struct GoalsView: View {
    @Environment(AppServices.self) private var services
    @State private var editing: PrayerGoal?
    @State private var showEditor = false
    @State private var deleting: UUID?
    var body: some View {
        PrivatePracticeContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "Gentle by choice", title: "Personal goals", subtitle: "Choose a rhythm that fits. Every week is a fresh invitation.")
                    Text("Weeks run Monday–Sunday. Each day counts once, however many prayers you choose.").font(.footnote).foregroundStyle(GraceColor.secondary)
                    if services.practice.document.goals.isEmpty { GraceEmpty(symbol: "leaf", title: "Your own small step.", message: "Try three mornings a week, or choose another rhythm. You can pause or change your goal any time.") }
                    ForEach(services.practice.document.goals) { goal in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(goal.title).font(.headline)
                            Text("\(goal.daysPerWeek) days each week · \(goal.period.title)\(goal.enabled ? "" : " · Paused")").font(.subheadline).foregroundStyle(GraceColor.secondary)
                            if goal.enabled, services.practice.document.showProgress, services.local.preferences.keepHistory {
                                let progress = PracticeRules.progress(for: goal, sessions: services.practice.document.sessions)
                                ProgressView(value: Double(min(progress, goal.daysPerWeek)), total: Double(goal.daysPerWeek))
                                Text("\(progress) of \(goal.daysPerWeek) days this week\(progress >= goal.daysPerWeek ? " · A little space made." : "")").font(.caption)
                            }
                            HStack { Button("Edit goal") { editing = goal; showEditor = true }.frame(minHeight: 44); Spacer(); Button("Delete", role: .destructive) { deleting = goal.id }.frame(minHeight: 44) }
                        }.graceCard()
                    }
                    Button("Add a goal") { editing = nil; showEditor = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addGoal")
                    NavigationLink("Activity and visibility settings", value: AppRoute.activity).frame(minHeight: 44)
                    PracticeErrorNotice()
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }.pageStyle().navigationTitle("Goals").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showEditor) { GoalEditor(goal: editing) }
                .confirmationDialog("Delete this goal?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("Delete goal", role: .destructive) { if let deleting { services.practice.deleteGoal(deleting) }; deleting = nil } } message: { Text("Your recorded prayer activity remains.") }
        }
    }
}

struct GoalEditor: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var goal: PrayerGoal
    init(goal: PrayerGoal? = nil) { _goal = State(initialValue: goal ?? PrayerGoal(title: "")) }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal name", text: $goal.title).accessibilityIdentifier("goalName")
                Stepper("\(goal.daysPerWeek) days per week", value: $goal.daysPerWeek, in: 1...7)
                Picker("Time of day", selection: $goal.period) { ForEach(PrayerPeriod.allCases) { Text($0.title).tag($0) } }
                Toggle("Goal active", isOn: $goal.enabled)
                Text("Morning is 5 am–noon, midday is noon–5 pm, and evening includes the night. Activity keeps the day and time of day where it happened. Editing a goal does not delete activity.").font(.footnote).foregroundStyle(.secondary)
                if let error = services.practice.errorMessage { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Your prayer goal").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { goal.title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines); if services.practice.saveGoal(goal) { dismiss() } }.disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("saveGoal") }
                }
        }
    }
}
