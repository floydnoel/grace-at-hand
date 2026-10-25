import SwiftUI
import GraceCore

struct ScriptureView: View {
    @Environment(AppServices.self) private var services
    @Environment(NavigationMemory.self) private var memory
    @State private var date = Date.now
    @State private var choosingDate = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "A word to carry with you", title: "Scripture")
                HStack {
                    Button { if let previous = Calendar.current.date(byAdding: .day, value: -1, to: date) { date = previous } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous daily passage")
                    Spacer(); Text(Calendar.current.isDateInToday(date) ? "A passage for today" : date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.medium)); Spacer()
                    Button { choosingDate = true } label: { Image(systemName: "calendar").frame(width: 44, height: 44) }.accessibilityLabel("Choose passage date")
                }
                Divider()
                if let passage = services.catalog.catalog.passage(on: date) { PassageContent(passage: passage) }
                else {
                    GraceEmpty(symbol: "book", title: "A little space to return", message: "This day’s passage isn’t saved yet. Your saved passages and downloaded prayers are still here.")
                    Button("Try again") { Task { await services.refresh() } }.buttonStyle(PrimaryButtonStyle())
                    NavigationLink("Open saved passages", value: AppRoute.savedPassages).frame(minHeight: 44)
                    if !Calendar.current.isDateInToday(date) { Button("Return to today") { date = .now }.frame(minHeight: 44) }
                }
            }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity)
        }.rememberScroll("scripture").pageStyle().navigationBarTitleDisplayMode(.inline)
            .onAppear { date = memory.scriptureDate }.onChange(of: date) { _, value in memory.scriptureDate = value }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: AppRoute.savedPassages) { Image(systemName: "bookmark").frame(width: 44, height: 44) }.accessibilityLabel("Saved passages") } }
            .sheet(isPresented: $choosingDate) {
                NavigationStack { DatePicker("Passage date", selection: $date, displayedComponents: .date).datePickerStyle(.graphical).padding().navigationTitle("Choose a day").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { choosingDate = false } } } }.presentationDetents([.medium, .large])
            }
    }
}

struct PassageDetailView: View {
    let passage: Passage
    var body: some View { ScrollView { PassageContent(passage: passage).padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity) }.pageStyle().navigationTitle("Scripture").navigationBarTitleDisplayMode(.inline) }
}
struct PassageContent: View {
    @Environment(AppServices.self) private var services
    let passage: Passage
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Eyebrow(text: passage.title)
            HStack {
                Text(passage.reference).font(.system(.title, design: .serif)).accessibilityAddTraits(.isHeader)
                Spacer(); Text(passage.translation == "Douay–Rheims" ? "D–R" : passage.translation).font(.caption).padding(8).background(GraceColor.wash, in: Capsule()).accessibilityLabel(passage.translation)
            }
            if let note = passage.numberingNote { Text(note).font(.caption).foregroundStyle(GraceColor.secondary) }
            ReadingControls()
            ForEach(Array(passage.verses.enumerated()), id: \.offset) { index, verse in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let numbers = passage.verseNumbers, numbers.indices.contains(index) {
                        Text(numbers[index]).font(.caption2).foregroundStyle(GraceColor.secondary).accessibilityLabel("Verse \(numbers[index])")
                    }
                    ReadingText(text: verse, scale: services.local.preferences.readingScale)
                }
            }
            HStack(spacing: 16) {
                if let id = passage.audioItemID, let prayer = services.prayer(id) { Button { Task { await services.play(prayer) } } label: { Label("Listen", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()) }
                Button { services.local.togglePassage(passage) } label: { Image(systemName: services.local.isSaved(passage) ? "bookmark.fill" : "bookmark").font(.title2).frame(width: 48, height: 52) }.accessibilityLabel(services.local.isSaved(passage) ? "Remove saved passage" : "Save passage")
            }
            VStack(alignment: .leading, spacing: 10) { Text("For reflection").font(.subheadline.weight(.semibold)); Text(passage.reflection).font(.subheadline).lineSpacing(4) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 22))
            Text("\(passage.date) · \(passage.credit)").font(.caption).foregroundStyle(GraceColor.secondary)
        }
    }
}
struct SavedPassagesView: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(eyebrow: "Words to return to", title: "Saved passages")
                if services.local.savedPassages.isEmpty { GraceEmpty(symbol: "bookmark", title: "A word, close at hand.", message: "Save a daily passage to return to it here, even without a connection.") }
                ForEach(services.local.savedPassages) { passage in
                    NavigationLink { PassageDetailView(passage: passage) } label: {
                        VStack(alignment: .leading, spacing: 12) { Eyebrow(text: passage.date); Text(passage.reference).font(.system(.title2, design: .serif)); Text(passage.verses.first ?? "").font(.subheadline).foregroundStyle(GraceColor.secondary).lineLimit(3) }.graceCard()
                    }.buttonStyle(.plain)
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
    }
}
