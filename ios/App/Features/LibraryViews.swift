import SwiftUI
import GraceCore

struct TodayView: View {
    @Environment(AppServices.self) private var services
    @State private var now = Date.now
    private var featured: Prayer? {
        if services.catalog.isOffline, let download = services.downloads.available.first { return download }
        let hour = Calendar.current.component(.hour, from: now)
        return services.catalog.catalog.item(hour >= 18 || hour < 5 ? "evening-surrender" : "morning-offering") ?? services.catalog.catalog.items.first
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: Calendar.current.component(.hour, from: now) < 12 ? "Good morning" : "A little space for prayer", title: "A moment for God.")
                    Spacer(minLength: 0); Image(systemName: "sun.max").font(.title2.weight(.light)).foregroundStyle(GraceColor.accent).padding(.top, 22).accessibilityHidden(true)
                }
                if services.catalog.isOffline { StatusNotice(text: "You’re offline. Your saved prayers are still here.", symbol: "wifi.slash") }
                if let featured { FeaturedPrayer(prayer: featured) }
                if let current = services.playback.current {
                    Button { services.showPlayer = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle").font(.title2)
                            VStack(alignment: .leading, spacing: 4) { Text("Continue listening").font(.caption); Text(current.title).font(.body.weight(.semibold)) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.foregroundStyle(GraceColor.ink).padding(18).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                SectionHeading(title: "A word for today") {
                    if let passage = services.catalog.catalog.passage(on: now) { NavigationLink("Read") { PassageDetailView(passage: passage) } }
                }
                if let passage = services.catalog.catalog.passage(on: now) {
                    NavigationLink { PassageDetailView(passage: passage) } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "\(passage.reference) · \(passage.translation)")
                            Text("“\(passage.verses.first ?? "")”").font(.system(.title2, design: .serif)).multilineTextAlignment(.leading)
                            HStack { Text("A moment to be renewed.").font(.subheadline).foregroundStyle(GraceColor.secondary); Spacer(); Image(systemName: "arrow.right") }
                        }.graceCard()
                    }.buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Today’s passage isn’t saved yet.").font(.headline)
                        Text("Your downloaded prayers and core prayer text are still here.").foregroundStyle(GraceColor.secondary)
                        HStack { Button("Try again") { Task { await services.refresh() } }; Spacer(); NavigationLink("Open downloads", value: AppRoute.downloads) }
                    }.graceCard()
                }
                SectionHeading(title: "A beginning in prayer") { NavigationLink("View path", value: AppRoute.journey) }
                BeginnerCard()
                if let entry = services.catalog.catalog.calendarEntry(on: now) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "calendar").foregroundStyle(GraceColor.accent)
                        VStack(alignment: .leading, spacing: 6) { Text(entry.season).font(.subheadline.weight(.medium)); Text(entry.observance).font(.caption).foregroundStyle(GraceColor.secondary) }
                    }.padding(.vertical, 8)
                }
                if let error = services.catalog.errorMessage { StatusNotice(text: error) }
                if services.catalog.catalog.isFixture { Text("Development preview · sample recordings and calendar").font(.caption2).foregroundStyle(GraceColor.secondary) }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.rememberScroll("today").pageStyle().navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .refreshable { await services.refresh() }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}

struct FeaturedPrayer: View {
    @Environment(AppServices.self) private var services
    let prayer: Prayer
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Spacer(); Label(prayer.category == "Rest" ? "Evening prayer" : "Morning prayer", systemImage: prayer.symbol).font(.caption2).padding(.horizontal, 12).padding(.vertical, 8).background(Color(hex: 0x253E32).opacity(0.86), in: Capsule()) }
            Spacer(minLength: 130)
            Text("BEGIN WHERE YOU ARE").font(.caption2.weight(.semibold)).tracking(1.5)
            Text(prayer.title).font(.system(.largeTitle, design: .serif))
            Label("\(prayer.durationLabel) · A gentle place to begin", systemImage: "headphones").font(.caption)
            Button { Task { await services.play(prayer) } } label: { Label("Pray now", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle(light: true)).accessibilityIdentifier("prayNow")
        }.padding(24).foregroundStyle(Color.white).frame(minHeight: 330)
            .background {
                PrayerArtwork(evening: prayer.category == "Rest")
                    .overlay(LinearGradient(colors: [.black.opacity(0.02), Color(hex: 0x142C20).opacity(0.15), Color(hex: 0x142C20).opacity(0.95)], startPoint: .top, endPoint: .bottom))
            }.clipShape(RoundedRectangle(cornerRadius: 26))
    }
}

struct BeginnerCard: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        NavigationLink(value: AppRoute.journey) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "New to prayer?")
                Text("A beginning\nin prayer").font(.system(.title, design: .serif))
                Text("Seven small invitations.\nYour own pace.").font(.subheadline).foregroundStyle(GraceColor.secondary)
                HStack { Image(systemName: "arrow.right").frame(width: 40, height: 40).background(GraceColor.card, in: Circle()); Spacer(); Image(systemName: "leaf").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(GraceColor.accent.opacity(0.35)).accessibilityHidden(true) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }
}

struct DiscoverView: View {
    @Environment(AppServices.self) private var services
    @Environment(NavigationMemory.self) private var memory
    @State private var category = "All"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Prayer for everyday life", title: "Discover")
                NavigationLink(value: AppRoute.search) { Label("Prayers, topics, or Scripture", systemImage: "magnifyingglass").foregroundStyle(GraceColor.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain).accessibilityIdentifier("openSearch")
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(["All", "Pray", "Reflect", "Rest", "Learn"], id: \.self) { value in FilterChip(title: value, selected: category == value) { category = value } } } }
                if category == "All" {
                    BeginnerCard()
                    SectionHeading(title: "Find your quiet") { EmptyView() }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(services.catalog.catalog.collections) { collection in
                            NavigationLink(value: AppRoute.collection(collection.id)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(systemName: collection.symbol).font(.title2.weight(.light))
                                    Text(collection.title).font(.subheadline.weight(.semibold))
                                    Text(collection.subtitle).font(.caption).foregroundStyle(GraceColor.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading).padding(18).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(.plain)
                        }
                    }
                    NavigationLink(value: AppRoute.silence) { Label("Sit with silence", systemImage: "timer").frame(maxWidth: .infinity, alignment: .leading).graceCard() }.buttonStyle(.plain)
                }
                SectionHeading(title: category == "All" ? "A place to begin" : category == "Rest" ? "Let the day come to rest" : "Room for \(category.lowercased())") { EmptyView() }
                ForEach(services.catalog.catalog.items.filter { category == "All" || $0.category == category }) { prayer in
                    NavigationLink(value: AppRoute.prayer(prayer.id)) { PrayerRow(prayer: prayer, downloaded: services.downloads.isAvailable(prayer)) }.buttonStyle(.plain)
                    Divider().overlay(GraceColor.border)
                }
            }.padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.rememberScroll("discover").pageStyle().navigationBarTitleDisplayMode(.inline)
            .onAppear { category = memory.category }.onChange(of: category) { _, value in memory.category = value }
    }
}

struct SearchView: View {
    @Environment(AppServices.self) private var services
    @Environment(NavigationMemory.self) private var memory
    @State private var query = ""
    @State private var short = false
    @State private var downloaded = false
    @State private var family = false
    @FocusState private var searchFocused: Bool
    private var results: [Prayer] {
        services.catalog.catalog.items.filter { prayer in
            let terms = query.split(whereSeparator: \.isWhitespace)
            let haystack = ([prayer.title, prayer.subtitle, prayer.category] + prayer.topics).joined(separator: " ")
            return terms.allSatisfy { haystack.localizedCaseInsensitiveContains(String($0)) } && (!short || prayer.durationSeconds <= 600) && (!downloaded || services.downloads.isAvailable(prayer)) && (!family || prayer.suitability == "family")
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Find a prayer").font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                HStack { Image(systemName: "magnifyingglass"); TextField("Prayers, topics, or Scripture", text: $query).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("prayerSearch") }
                    .padding(16).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16))
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) {
                    FilterChip(title: "Under 10 min", selected: short) { short.toggle() }
                    FilterChip(title: "Downloaded", selected: downloaded) { downloaded.toggle() }
                    FilterChip(title: "Family", selected: family) { family.toggle() }
                } }
                Text("\(results.count) prayers · All freely available").font(.caption).foregroundStyle(GraceColor.secondary)
                if results.isEmpty {
                    GraceEmpty(symbol: "magnifyingglass", title: "A little more room to look", message: "No prayers found. Try fewer words or another topic.")
                    Button("Clear search & filters") { query = ""; short = false; downloaded = false; family = false; searchFocused = false }.buttonStyle(PrimaryButtonStyle())
                }
                ForEach(results) { prayer in NavigationLink(value: AppRoute.prayer(prayer.id)) { PrayerRow(prayer: prayer, downloaded: services.downloads.isAvailable(prayer)) }.buttonStyle(.plain); Divider() }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.rememberScroll("search").scrollDismissesKeyboard(.interactively).pageStyle().navigationBarTitleDisplayMode(.inline)
            .onAppear { query = memory.query; short = memory.shortOnly; downloaded = memory.downloadedOnly; family = memory.familyOnly }
            .onChange(of: query) { _, value in memory.query = value }
            .onChange(of: short) { _, value in memory.shortOnly = value }
            .onChange(of: downloaded) { _, value in memory.downloadedOnly = value }
            .onChange(of: family) { _, value in memory.familyOnly = value }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { searchFocused = false } } }
    }
}

struct PrayerDetailView: View {
    @Environment(AppServices.self) private var services
    let prayer: Prayer
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PrayerArtwork(evening: prayer.category == "Rest").frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 24))
                PageHeading(eyebrow: prayer.category == "Rest" ? "Evening prayer" : prayer.topics.first ?? prayer.category, title: prayer.title, subtitle: prayer.subtitle)
                HStack(spacing: 12) { Label(prayer.durationLabel, systemImage: "clock"); Label(prayer.audio == nil ? "Text" : "Text & audio", systemImage: "text.alignleft"); Text("English") }.font(.caption).foregroundStyle(GraceColor.secondary)
                if prayer.audio != nil {
                    Button { Task { await services.play(prayer) } } label: { Label("Begin prayer", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("beginPrayer")
                    DownloadAction(prayer: prayer)
                }
                Text(prayer.howTo).foregroundStyle(GraceColor.secondary).lineSpacing(5)
                NavigationLink(value: AppRoute.reader(prayer.id)) { Label("Read the prayer", systemImage: "book").frame(maxWidth: .infinity, alignment: .leading).graceCard() }.buttonStyle(.plain)
                if let set = prayer.rosarySet { NavigationLink(value: AppRoute.rosary(set)) { Label("Open the guided Rosary", systemImage: "cross").frame(maxWidth: .infinity, alignment: .leading).graceCard() }.buttonStyle(.plain) }
                if prayer.id == "sit-with-silence" { NavigationLink("Open silence timer", value: AppRoute.silence).frame(minHeight: 44) }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Sources & credits")
                    ForEach(prayer.credits, id: \.self) { Text($0).font(.footnote).foregroundStyle(GraceColor.secondary) }
                    Text(prayer.suitability == "family" ? "Family prayer · children participate with an adult" : "General audience").font(.caption).foregroundStyle(GraceColor.secondary)
                }.padding(.top, 10)
                Button("Report a content issue") { services.alertMessage = "You can share a diagnostic report from Settings. Include the prayer title and the correction you suggest in your own message." }.font(.footnote).frame(minHeight: 44)
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.rememberScroll("prayer:\(prayer.id)").pageStyle().navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { services.local.toggleFavorite(prayer.id) } label: { Image(systemName: services.local.isFavorite(prayer.id) ? "heart.fill" : "heart").frame(width: 44, height: 44) }.accessibilityLabel(services.local.isFavorite(prayer.id) ? "Remove saved prayer" : "Save prayer").accessibilityIdentifier("savePrayer") } }
    }
}

struct CollectionView: View {
    @Environment(AppServices.self) private var services
    let id: String
    var body: some View {
        ScrollView {
            if let collection = services.catalog.catalog.collections.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "A little space for prayer", title: collection.title, subtitle: collection.subtitle)
                    ForEach(collection.itemIDs.compactMap(services.prayer)) { prayer in NavigationLink(value: AppRoute.prayer(prayer.id)) { PrayerRow(prayer: prayer, downloaded: services.downloads.isAvailable(prayer)) }.buttonStyle(.plain); Divider() }
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }.rememberScroll("collection:\(id)").pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}

struct JourneyView: View {
    @Environment(AppServices.self) private var services
    private var journey: Journey? { services.catalog.catalog.journeys.first }
    private var complete: Int { journey?.itemIDs.filter { services.local.record($0)?.completed == true }.count ?? 0 }
    var body: some View {
        ScrollView {
            if let journey {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeading(eyebrow: "A seven-session journey", title: journey.title, subtitle: "Seven small invitations.\nTake them at your own pace.")
                        HStack(spacing: 5) { ForEach(journey.itemIDs, id: \.self) { id in Capsule().fill(services.local.record(id)?.completed == true ? GraceColor.accent : GraceColor.border).frame(height: 4) } }.accessibilityHidden(true)
                        Text("\(complete) of 7 sessions completed").font(.caption).foregroundStyle(GraceColor.secondary)
                    }.padding(24).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 24))
                    ForEach(Array(journey.itemIDs.enumerated()), id: \.element) { index, id in
                        if let prayer = services.prayer(id) {
                            NavigationLink(value: AppRoute.prayer(id)) {
                                HStack(spacing: 16) {
                                    Group { if services.local.record(id)?.completed == true { Image(systemName: "checkmark") } else { Text("\(index + 1)") } }.font(.subheadline).frame(width: 40, height: 40).background(GraceColor.wash, in: Circle())
                                    VStack(alignment: .leading, spacing: 7) { Text(prayer.title).font(.body.weight(.semibold)); Text(services.local.record(id)?.completed == true ? "Completed · return any time" : "\(prayer.durationLabel) · Ready whenever you are").font(.caption).foregroundStyle(GraceColor.secondary) }
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }.padding(.vertical, 12)
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("No missed days. No catching up. Your next small step is enough.").font(.footnote).foregroundStyle(GraceColor.secondary)
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }.rememberScroll("journey").pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}
