import SwiftUI
import GraceCore

enum AppTab: String, CaseIterable, Identifiable {
    case today, discover, scripture, myPrayer
    var id: String { rawValue }
    var title: String { switch self { case .today: "Today"; case .discover: "Discover"; case .scripture: "Scripture"; case .myPrayer: "My prayer" } }
    var symbol: String { switch self { case .today: "sun.max"; case .discover: "safari"; case .scripture: "book"; case .myPrayer: "heart" } }
}
enum AppRoute: Hashable {
    case prayer(String), collection(String), journey, search, saved, downloads, intentions, reminders, settings, support, history, savedPassages, rosary(String), silence, reader(String)
    case routines, routine(UUID), goals, activity, journal, journalEntry(UUID), intention(UUID)
    case routineReader(String, UUID)
    case readingLibrary(ReadingKind?), readingWork(String), readingSection(String, String?), readingGuide(String), savedReadings
}

@Observable final class NavigationMemory {
    var offsets: [String: CGFloat] = [:]
    var query = ""
    var shortOnly = false
    var downloadedOnly = false
    var familyOnly = false
    var category = "All"
    var scriptureDate = Date.now
}

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var selection: AppTab = .today
    @State private var paths: [AppTab: [AppRoute]] = [:]
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var memory = NavigationMemory()
    var body: some View {
        @Bindable var services = services
        Group {
            if !services.local.preferences.welcomed { WelcomeView() }
            else if horizontalSize == .regular && !dynamicType.isAccessibilitySize {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    List(selection: Binding<AppTab?>(get: { selection }, set: { if let tab = $0 { selection = tab } })) {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "Daily prayer.\nFreely shared.")
                            Text("Grace at Hand").font(.system(.title2, design: .serif))
                        }.padding(.vertical, 22).listRowBackground(Color.clear)
                        ForEach(AppTab.allCases) { tab in Label(tab.title, systemImage: tab.symbol).padding(.vertical, 8).tag(tab) }
                        Section("Your prayer") {
                            Button { selection = .myPrayer; paths[.myPrayer] = [.downloads] } label: { Label("Downloads", systemImage: "arrow.down.to.line") }
                            Button { selection = .scripture; paths[.scripture] = [.savedPassages] } label: { Label("Saved passages", systemImage: "bookmark") }
                            Button { selection = .discover; paths[.discover] = [.readingLibrary(nil)] } label: { Label("Reading library", systemImage: "books.vertical") }
                        }
                    }.scrollContentBackground(.hidden).background(GraceColor.canvas)
                        .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
                } detail: {
                    navigation(for: selection).id(selection)
                }.navigationSplitViewStyle(.balanced)
            } else {
                destinations
            }
        }
        .pageStyle()
        .environment(memory)
        .onChange(of: services.local.preferences.welcomed) { _, welcomed in
            if !welcomed { paths = [:]; selection = .today; memory = NavigationMemory() }
        }
        .onChange(of: services.local.errorMessage) { _, message in if let message { services.alertMessage = message } }
        .sheet(isPresented: $services.showPlayer) { PlayerView().environment(services) }
        .alert("A little help", isPresented: Binding(get: { services.alertMessage != nil }, set: { if !$0 { services.alertMessage = nil } })) {
            Button("OK", role: .cancel) { services.alertMessage = nil }
        } message: { Text(services.alertMessage ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .graceOpenPrayer)) { notification in
            if let id = notification.object as? String { selection = .today; paths[.today, default: []].append(.prayer(id)) }
        }
        .onChange(of: services.pendingIntentionID) { _, _ in openPendingIntention() }
        .onChange(of: services.reminders.pendingIntentionID) { _, _ in openPendingIntention() }
        .onAppear { openPendingIntention() }
    }
    private var destinations: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                navigation(for: tab).tabItem { Label(tab.title, systemImage: tab.symbol) }.tag(tab)
            }
        }
    }
    private func path(for tab: AppTab) -> Binding<[AppRoute]> { Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 }) }
    private func navigation(for tab: AppTab) -> some View {
        NavigationStack(path: path(for: tab)) {
            Group {
                switch tab { case .today: TodayView(); case .discover: DiscoverView(); case .scripture: ScriptureView(); case .myPrayer: MyPrayerView() }
            }
            .navigationDestination(for: AppRoute.self) { route in destination(route) }
            .toolbarBackground(GraceColor.canvas, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if services.playback.current != nil { MiniPlayer().padding(.horizontal, 16).padding(.bottom, 8) }
            }
        }
    }
    @ViewBuilder private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .prayer(let id): if let prayer = services.prayer(id) { PrayerDetailView(prayer: prayer) } else { ContentUnavailableView("Prayer unavailable", systemImage: "book", description: Text("This prayer is no longer in the current library.")) }
        case .collection(let id): CollectionView(id: id)
        case .journey: JourneyView()
        case .search: SearchView()
        case .saved: SavedPrayersView()
        case .downloads: DownloadsView()
        case .intentions: IntentionsView()
        case .reminders: RemindersView()
        case .settings: SettingsView()
        case .support: SupportView()
        case .history: HistoryView()
        case .savedPassages: SavedPassagesView()
        case .rosary(let raw): RosaryView(initialSet: RosaryMysteries(rawValue: raw) ?? .joyful)
        case .silence: SilenceView()
        case .reader(let id): if let prayer = services.prayer(id) { ReaderView(prayer: prayer, transcript: false) }
        case .routines: RoutinesView()
        case .routine(let id): RoutineDetailView(id: id)
        case .goals: GoalsView()
        case .activity: ActivityView()
        case .journal: JournalView()
        case .journalEntry(let id): JournalDetailView(id: id)
        case .intention(let id): IntentionDetailView(id: id)
        case .routineReader(let prayerID, let routineID): if let prayer = services.prayer(prayerID) { ReaderView(prayer: prayer, transcript: false, routineID: routineID) }
        case .readingLibrary(let kind): ReadingLibraryView(initialKind: kind)
        case .readingWork(let id): ReadingWorkView(id: id)
        case .readingSection(let id, let anchor): ReadingSectionView(id: id, anchor: anchor)
        case .readingGuide(let id): ReadingGuideView(id: id)
        case .savedReadings: SavedReadingsView()
        }
    }
    private func openPendingIntention() {
        guard let value = services.pendingIntentionID ?? services.reminders.pendingIntentionID, let id = UUID(uuidString: value) else { return }
        services.pendingIntentionID = nil; services.reminders.pendingIntentionID = nil; selection = .myPrayer; paths[.myPrayer] = [.intentions, .intention(id)]
    }
}

struct WelcomeView: View {
    @Environment(AppServices.self) private var services
    @State private var personalizing = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 48.0
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    PrayerArtwork().frame(height: min(geometry.size.height * 0.48, 440))
                        .overlay(alignment: .bottom) { LinearGradient(colors: [.clear, GraceColor.canvas], startPoint: .top, endPoint: .bottom).frame(height: 100) }
                    VStack(spacing: 20) {
                        Eyebrow(text: "Daily prayer. Freely shared.")
                        Text("Grace\nat Hand").font(.system(size: titleSize, design: .serif)).multilineTextAlignment(.center).lineSpacing(-4)
                        Text("Catholic prayer, Scripture, and reflection\nfor everyday life.").foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center).lineSpacing(5)
                        Button { services.local.preferences.welcomed = true; services.local.save() } label: { Label("Begin praying", systemImage: "arrow.right") }
                            .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("beginPraying")
                        Text("Every prayer is free. No account needed.").font(.caption).foregroundStyle(GraceColor.secondary)
                        Button("Personalize my experience") { personalizing = true }.font(.subheadline).frame(minHeight: 44)
                    }.padding(.horizontal, 28).padding(.bottom, 24).frame(maxWidth: 480)
                }.frame(maxWidth: .infinity)
            }.ignoresSafeArea(edges: .top).background(GraceColor.canvas)
        }.sheet(isPresented: $personalizing) { PreferencesView() }
    }
}
struct PreferencesView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var preferences = services.local.preferences
        NavigationStack {
            Form {
                Section { Text("Your choices shape the prayer suggested on Today. All prayers stay available in Discover. These choices are optional and can change any time.") }
                Section("What brings you here?") {
                    ForEach(["Beginner", "Morning", "Scripture", "Family", "Rest", "Rosary"], id: \.self) { interest in
                        Toggle(interest, isOn: Binding(get: { preferences.interests.contains(interest) }, set: { selected in
                            preferences.interests.removeAll { $0 == interest }; if selected { preferences.interests.append(interest) }
                        }))
                    }
                }
                Section("A little time for prayer") {
                    Picker("Available time", selection: $preferences.availableMinutes) { Text("5 minutes").tag(5); Text("10 minutes").tag(10); Text("20 minutes").tag(20) }
                    Text("We’ll suggest prayers within this time when available. The actual length is always shown.").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("English · US Roman Catholic calendar\nMore languages and calendars can be added later.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("A place to begin").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { services.local.save(); dismiss() } } }
        }
    }
}
