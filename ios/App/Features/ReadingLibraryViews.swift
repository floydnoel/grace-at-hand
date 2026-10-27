import SwiftUI
import GraceCore

struct ReadingLibraryView: View {
    @Environment(AppServices.self) private var services
    var initialKind: ReadingKind?
    @State private var kind: ReadingKind?
    @State private var author: String?
    @State private var query = ""
    @State private var offlineOnly = false
    @State private var results: [ReadingSearchResult] = []
    @State private var searching = false
    @State private var error: String?
    @FocusState private var searchFocused: Bool
    init(initialKind: ReadingKind? = nil) { self.initialKind = initialKind; _kind = State(initialValue: initialKind) }
    private var request: String { "\(query)|\(kind?.rawValue ?? "all")|\(author ?? "all")|\(offlineOnly)" }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Scripture & Catholic writings", title: "Reading library", subtitle: "Find a passage. Follow a theme. Read at your own pace.")
                if let library = services.readings.library {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Topic, title, author, or Bible reference", text: $query).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("readingSearch")
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Clear reading search") }
                    }.padding(12).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16))
                    HStack(alignment: .top) {
                        Menu {
                            Button("All writings") { kind = nil; author = nil }
                            ForEach(ReadingKind.allCases, id: \.self) { value in Button(value.title) { kind = value; author = nil } }
                        } label: { Label(kind?.title ?? "All writings", systemImage: "line.3.horizontal.decrease").frame(minHeight: 44) }
                        Spacer()
                        Menu {
                            Button("All authors") { author = nil }
                            ForEach(Array(Set(library.works.filter { kind == nil || $0.kind == kind }.map(\.author))).sorted(), id: \.self) { value in Button(value) { author = value } }
                        } label: { Text(author ?? "All authors").frame(minHeight: 44) }
                    }.font(.subheadline)
                    Toggle("Available offline only", isOn: $offlineOnly)
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let id = services.readingShelf.shelf.lastSectionID, let section = library.section(id) {
                            NavigationLink(value: AppRoute.readingSection(id, nil)) {
                                VStack(alignment: .leading, spacing: 8) { Eyebrow(text: "Continue reading"); Text(section.reference).font(.system(.title2, design: .serif)) }.frame(maxWidth: .infinity, alignment: .leading).graceCard()
                            }.buttonStyle(.plain)
                        }
                        if kind == nil && author == nil {
                            SectionHeading(title: "A path through reading") { EmptyView() }
                            ForEach(library.guides) { guide in
                                NavigationLink(value: AppRoute.readingGuide(guide.id)) { Label(guide.title, systemImage: "signpost.right").frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).graceCard(padding: 16) }.buttonStyle(.plain)
                            }
                        }
                        SectionHeading(title: "Explore a topic") { EmptyView() }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 10) {
                            ForEach(library.topics) { topic in Button(topic.title) { query = topic.title }.buttonStyle(.plain).frame(maxWidth: .infinity, minHeight: 48).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("readingTopic-\(topic.id)") }
                        }
                        SectionHeading(title: kind?.title ?? "Browse the library") { EmptyView() }
                        let works = library.works.filter { (kind == nil || $0.kind == kind) && (author == nil || $0.author == author) && (!offlineOnly || $0.isOffline) }
                        Text("\(works.count) works").font(.caption).foregroundStyle(GraceColor.secondary)
                        ForEach(works) { work in NavigationLink(value: AppRoute.readingWork(work.id)) { ReadingWorkRow(work: work) }.buttonStyle(.plain); Divider() }
                    } else {
                        if searching { ProgressView("Searching this device…") }
                        else if results.isEmpty && error == nil { GraceEmpty(symbol: "magnifyingglass", title: "Room to keep looking", message: "Try another topic, a shorter phrase, or different filters.") }
                        else { Text(results.count == 80 ? "Top 80 matches" : "\(results.count) matches").font(.caption).foregroundStyle(GraceColor.secondary) }
                        ForEach(results) { result in
                            NavigationLink(value: result.sectionID.map { AppRoute.readingSection($0, result.anchor) } ?? .readingWork(result.workID)) {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(result.title).font(.system(.title3, design: .serif))
                                    if let work = library.work(result.workID) { Text("\(work.author) · \(work.isOffline ? "Offline" : "Source link")").font(.caption).foregroundStyle(GraceColor.secondary) }
                                    Text(result.reason).font(.caption).foregroundStyle(GraceColor.accent)
                                    if let excerpt = result.excerpt { Text(excerpt).font(.subheadline).foregroundStyle(GraceColor.secondary).lineLimit(4) }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                            }.buttonStyle(.plain).accessibilityIdentifier("readingResult-\(result.id)")
                            Divider()
                        }
                    }
                    if let error { StatusNotice(text: error); Button("Try search again") { Task { await search() } }.frame(minHeight: 44) }
                    Text("Offline readings are saved on this device. Source websites need internet access.").font(.footnote).foregroundStyle(GraceColor.secondary)
                    Text(library.coverage).font(.caption).foregroundStyle(GraceColor.secondary)
                    if library.isDevelopment { Text("Development library · source, transcription, and reading-guide review pending.").font(.caption).foregroundStyle(GraceColor.secondary) }
                } else { StatusNotice(text: services.readings.errorMessage ?? "The reading library is unavailable.") }
            }.padding(24).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("readingLibraryScroll").scrollDismissesKeyboard(.interactively).pageStyle().navigationBarTitleDisplayMode(.inline)
            .task(id: request) {
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { results = []; error = nil; searching = false; return }
                do { try await Task.sleep(for: .milliseconds(200)); await search() } catch {}
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: AppRoute.savedReadings) { Image(systemName: "bookmark").frame(width: 44, height: 44) }.accessibilityLabel("Saved readings") } }
    }
    private func search() async {
        searching = true; error = nil; results = []
        do {
            let next = try await services.readings.search(query, kind: kind, author: author, offlineOnly: offlineOnly)
            guard !Task.isCancelled else { return }; results = next; searching = false
        } catch { if !Task.isCancelled { self.error = error.localizedDescription; results = []; searching = false } }
    }
}

struct ReadingWorkRow: View {
    let work: ReadingWork
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: work.kind == .bible ? "book" : "text.book.closed").font(.title2).foregroundStyle(GraceColor.accent).frame(width: 40, height: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(work.title).font(.system(.title3, design: .serif))
                Text(work.author).font(.subheadline).foregroundStyle(GraceColor.secondary)
                Text((work.date.map { "\($0) · " } ?? "") + (work.isOffline ? "Available offline" : "Read at source")).font(.caption).foregroundStyle(GraceColor.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).padding(.top, 8).accessibilityHidden(true)
        }.padding(.vertical, 8)
    }
}

struct ReadingWorkView: View {
    @Environment(AppServices.self) private var services
    let id: String
    var body: some View {
        ScrollView {
            if let work = services.readings.library?.work(id) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: work.kind.title, title: work.title, subtitle: work.author)
                    ReadingEditionNotice(work: work)
                    Text(work.summary).foregroundStyle(GraceColor.secondary)
                    if !work.sections.isEmpty {
                        ReadingControls()
                        SectionHeading(title: work.kind == .bible ? "Chapters" : "Contents") { EmptyView() }
                        ForEach(work.sections.sorted { $0.order < $1.order }) { section in
                            NavigationLink(value: AppRoute.readingSection(section.id, nil)) {
                                HStack { Text(section.title); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                                    .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("readingSection-\(section.id)")
                            Divider()
                        }
                    } else {
                        StatusNotice(text: "Read the complete document at its source. Offline text for this edition is not included.", symbol: "globe")
                    }
                    ReadingSourceView(work: work)
                }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { ReadingSaveButton(id: work.id) } }
            } else { ContentUnavailableView("Reading unavailable", systemImage: "book") }
        }.accessibilityIdentifier("readingWorkScroll").pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}

struct ReadingSectionView: View {
    @Environment(AppServices.self) private var services
    let id: String
    var anchor: String?
    @State private var currentID: String?
    @State private var blocks: [ReadingBlock] = []
    @State private var error: String?
    @State private var loading = true
    private var section: ReadingSection? { services.readings.library?.section(currentID ?? id) }
    private var work: ReadingWork? { services.readings.library?.works.first { $0.sections.contains { $0.id == (currentID ?? id) } } }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let section, let work {
                        PageHeading(eyebrow: work.author, title: section.reference)
                        ReadingEditionNotice(work: work, section: section)
                        ReadingControls()
                        if loading { ProgressView("Opening reading…") }
                        if let error { StatusNotice(text: error); Button("Try opening again") { Task { await load() } }.frame(minHeight: 44) }
                        ForEach(blocks) { block in
                            ReadingMarkdownBlock(block: block, scale: services.local.preferences.readingScale).id(block.id)
                        }
                        if !loading && error == nil {
                            HStack {
                                if let previous = work.sections.last(where: { $0.order < section.order }) { Button { currentID = previous.id } label: { Label("Previous", systemImage: "chevron.left") }.frame(minHeight: 48) }
                                Spacer()
                                if let next = work.sections.first(where: { $0.order > section.order }) { Button { currentID = next.id } label: { Label("Next", systemImage: "chevron.right") }.frame(minHeight: 48).accessibilityIdentifier("nextReadingSection") }
                            }
                            Divider(); ReadingSourceView(work: work, section: section)
                        }
                    }
                }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity).id("reading-top")
            }.accessibilityIdentifier("readingReaderScroll").pageStyle().navigationTitle(work?.title ?? "Reading").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let work, let section {
                            Menu {
                                NavigationLink("Table of contents", value: AppRoute.readingWork(work.id))
                                if let previous = work.sections.last(where: { $0.order < section.order }) { Button(work.kind == .bible ? "Previous chapter" : "Previous section") { currentID = previous.id } }
                                if let next = work.sections.first(where: { $0.order > section.order }) { Button(work.kind == .bible ? "Next chapter" : "Next section") { currentID = next.id } }
                            } label: { Image(systemName: "list.bullet").frame(width: 44, height: 44) }.accessibilityLabel("Reading navigation").accessibilityIdentifier("readingNavigation")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) { ReadingSaveButton(id: currentID ?? id) }
                }
                .task(id: currentID ?? id) { await load(); await Task.yield(); if !Task.isCancelled { proxy.scrollTo(currentID == nil ? (anchor ?? "reading-top") : "reading-top", anchor: .top) } }
        }
    }
    private func load() async {
        loading = true; error = nil; blocks = []
        guard let section else { error = "This reading is no longer available."; loading = false; return }
        do {
            let next = try await services.readings.blocks(for: section)
            guard !Task.isCancelled else { return }
            blocks = next.filter { !($0.headingLevel > 0 && ($0.text == section.reference || $0.text == section.title)) }; loading = false
            if services.local.preferences.keepHistory { services.readingShelf.remember(section.id) }
        } catch { if !Task.isCancelled { self.error = error.localizedDescription; loading = false } }
    }
}

private struct ReadingMarkdownBlock: View {
    let block: ReadingBlock
    let scale: Double
    @ScaledMetric(relativeTo: .body) private var size = 23.0
    private var text: AttributedString {
        (try? AttributedString(markdown: block.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(block.text)
    }
    var body: some View {
        Text(text).font(.system(size: size * scale * (block.headingLevel > 0 ? 1.15 : 1), weight: block.headingLevel > 0 ? .semibold : .regular, design: .serif))
            .lineSpacing(8).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            .accessibilityAddTraits(block.headingLevel > 0 ? .isHeader : [])
    }
}

struct ReadingSourceView: View {
    let work: ReadingWork
    var section: ReadingSection? = nil
    private var isEditorialSummary: Bool { section.map(work.isEditorialSummary) ?? false }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: isEditorialSummary ? "Original document source" : "Source & edition")
            if isEditorialSummary {
                Text("This English editorial summary is unreviewed. The source edition and its notices are available in the table of contents.").font(.footnote).foregroundStyle(GraceColor.secondary)
            } else {
                Text(work.isOffline ? work.rights.edition : work.sourceIsDirectory == true ? "Find this document in the source directory." : "Published source edition").font(.footnote)
                if work.isOffline { Text("Text language: \(Locale(identifier: "en").localizedString(forLanguageCode: work.language) ?? work.language)").font(.caption).foregroundStyle(GraceColor.secondary) }
                if let language = work.sourceLanguage { Text("Source language: \(Locale(identifier: "en").localizedString(forLanguageCode: language) ?? language)").font(.caption).foregroundStyle(GraceColor.secondary) }
                Text(work.isOffline ? work.rights.statement : "This edition opens on the source website and is not saved offline in Grace at Hand.").font(.footnote).foregroundStyle(GraceColor.secondary)
            }
            if let type = work.originalType { Text("Document type: \(type.replacingOccurrences(of: "-", with: " "))").font(.caption).foregroundStyle(GraceColor.secondary) }
            if let url = URL(string: work.sourceURL) { Link(work.sourceIsDirectory == true ? "Browse source directory" : "Open source website", destination: url).frame(minHeight: 44).accessibilityIdentifier("readingSourceLink") }
            if work.rights.evidenceURL != work.sourceURL, let url = URL(string: work.rights.evidenceURL) { Link("Source rights notice", destination: url).font(.footnote).frame(minHeight: 44) }
        }
    }
}

private struct ReadingEditionNotice: View {
    let work: ReadingWork
    var section: ReadingSection? = nil
    var body: some View {
        if let section, work.isEditorialSummary(section) {
            Text("English editorial summary · review pending").font(.caption).foregroundStyle(GraceColor.secondary)
                .accessibilityIdentifier("readingEditorialSummaryNotice")
        } else if work.rights.status == .developmentOnly {
            VStack(alignment: .leading, spacing: 8) {
                Text("Research edition · review pending").font(.caption).foregroundStyle(GraceColor.secondary)
                if work.rights.edition.contains("DeepL") {
                    Text("Unreviewed machine translation from Italian.").font(.footnote).foregroundStyle(GraceColor.secondary)
                } else if work.language != "en" {
                    Text("Read in \(Locale(identifier: "en").localizedString(forLanguageCode: work.language) ?? work.language)").font(.footnote).foregroundStyle(GraceColor.secondary)
                }
                if work.originalType == "allocution-excerpts" { Text("This source contains excerpts of the address.").font(.footnote).foregroundStyle(GraceColor.secondary) }
            }
        }
    }
}

struct ReadingGuideView: View {
    @Environment(AppServices.self) private var services
    let id: String
    var body: some View {
        ScrollView {
            if let library = services.readings.library, let guide = library.guides.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "A path through reading", title: guide.title, subtitle: guide.introduction)
                    ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                        NavigationLink(value: step.sectionID.map { AppRoute.readingSection($0, step.anchor) } ?? .readingWork(step.workID)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Eyebrow(text: "Reading \(index + 1)")
                                Text(step.title).font(.system(.title2, design: .serif))
                                Text(library.section(step.sectionID ?? "")?.reference ?? library.work(step.workID)?.title ?? "Reading").font(.subheadline)
                                Text(step.note).font(.subheadline).foregroundStyle(GraceColor.secondary)
                                Label(step.sectionID == nil ? "Read at source" : "Read offline", systemImage: step.sectionID == nil ? "globe" : "book").font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading).graceCard()
                        }.buttonStyle(.plain)
                    }
                }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}

struct ReadingSaveButton: View {
    @Environment(AppServices.self) private var services
    let id: String
    var body: some View {
        Button { services.readingShelf.toggleSaved(id); if let error = services.readingShelf.errorMessage { services.alertMessage = error } } label: { Image(systemName: services.readingShelf.shelf.savedIDs.contains(id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44) }
            .accessibilityLabel(services.readingShelf.shelf.savedIDs.contains(id) ? "Remove saved reading" : "Save reading").accessibilityIdentifier("saveReading")
    }
}

struct SavedReadingsView: View {
    @Environment(AppServices.self) private var services
    @State private var reset = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Close at hand", title: "Saved readings")
                if let error = services.readingShelf.errorMessage {
                    StatusNotice(text: error)
                    if services.readingShelf.needsRecovery { Button("Try opening saved readings again") { services.readingShelf.load() }; Button("Reset saved readings", role: .destructive) { reset = true } }
                }
                if services.readingShelf.shelf.savedIDs.isEmpty { GraceEmpty(symbol: "bookmark", title: "Words to return to", message: "Save a work or chapter from the reading library. Public-domain readings stay available offline.") }
                if let library = services.readings.library {
                    ForEach(services.readingShelf.shelf.savedIDs, id: \.self) { id in
                        if let work = library.work(id) { NavigationLink(value: AppRoute.readingWork(id)) { ReadingWorkRow(work: work) }.buttonStyle(.plain) }
                        else if let section = library.section(id) { NavigationLink(section.reference, value: AppRoute.readingSection(id, nil)).frame(minHeight: 48) }
                        else { Text("A previously saved reading is unavailable.").font(.footnote).foregroundStyle(GraceColor.secondary) }
                        Button("Remove saved reading", role: .destructive) { services.readingShelf.toggleSaved(id) }.font(.caption).frame(minHeight: 44)
                        Divider()
                    }
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Reset saved readings?", isPresented: $reset, titleVisibility: .visible) { Button("Reset saved readings", role: .destructive) { services.readingShelf.reset() } } message: { Text("This removes reading bookmarks and your last reading position. The reading library remains available.") }
    }
}
