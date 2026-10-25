import SwiftUI
import GraceCore

extension View {
    func rememberScroll(_ key: String) -> some View { modifier(RememberedScroll(key: key)) }
    func graceCard(padding: CGFloat = 20) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(GraceColor.card, in: RoundedRectangle(cornerRadius: GraceLayout.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: GraceLayout.cardRadius).strokeBorder(GraceColor.border, lineWidth: 0.7))
    }
    func pageStyle() -> some View { self.background(GraceColor.canvas).foregroundStyle(GraceColor.ink) }
}
private struct RememberedScroll: ViewModifier {
    @Environment(NavigationMemory.self) private var memory
    let key: String
    @State private var position = ScrollPosition(edge: .top)
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content.scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, value in offset = value }
            .onDisappear { memory.offsets[key] = offset }
            .task { if let saved = memory.offsets[key] { position.scrollTo(y: saved) } }
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.semibold)).multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: GraceLayout.primaryHeight)
            .foregroundStyle(light ? Color(hex: 0x253E32) : GraceColor.buttonText)
            .background(light ? Color(hex: 0xF7F6F0) : GraceColor.button, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
extension Color {
    init(hex: UInt) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption2.weight(.semibold)).tracking(1.8).foregroundStyle(GraceColor.secondary) }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var size = 36.0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: size, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(.body).foregroundStyle(GraceColor.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
struct SectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ScaledMetric(relativeTo: .title2) private var size = 26.0
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: size, design: .serif)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8); trailing.font(.subheadline)
        }
    }
}
struct GraceEmpty: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(GraceColor.accent).frame(width: 86, height: 106).background(GraceColor.card, in: ArchShape())
            Text(title).font(.system(.title, design: .serif)).multilineTextAlignment(.center)
            Text(message).foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}
struct StatusNotice: View {
    let text: String
    var symbol = "info.circle"
    var body: some View {
        Label(text, systemImage: symbol).font(.subheadline).foregroundStyle(GraceColor.secondary)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16))
    }
}
struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height / 2)
        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.closeSubpath()
        }
    }
}
struct PrayerArtwork: View {
    var evening = false
    var body: some View {
        GeometryReader { geometry in
            if evening {
                ZStack {
                    Color(hex: 0x182B24)
                    Circle().stroke(Color(hex: 0xBDC7B8).opacity(0.1), lineWidth: 1).padding(22)
                    Circle().stroke(Color(hex: 0xBDC7B8).opacity(0.06), lineWidth: 1).padding(4)
                    Image(systemName: "moon.stars.fill").font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .ultraLight)).foregroundStyle(Color(hex: 0xD5D4AA))
                }
            } else { Image("Cloister").resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped() }
        }.accessibilityHidden(true)
    }
}
struct PrayerRow: View {
    let prayer: Prayer
    var downloaded = false
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if prayer.id == "morning-offering" { PrayerArtwork().frame(width: 58, height: 66).clipShape(RoundedRectangle(cornerRadius: 15)) }
                else { Image(systemName: prayer.symbol).font(.title2.weight(.light)).foregroundStyle(GraceColor.accent).frame(width: 58, height: 66).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 15)) }
            }.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(prayer.title).font(.body.weight(.semibold)).foregroundStyle(GraceColor.ink)
                Text("\(downloaded ? "Downloaded" : prayer.category) · \(prayer.durationLabel)").font(.caption).foregroundStyle(GraceColor.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: downloaded ? "checkmark.circle" : "chevron.right").font(.caption).foregroundStyle(GraceColor.accent).accessibilityHidden(true)
        }.padding(.vertical, 10).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(.subheadline).padding(.horizontal, 17).frame(minHeight: 44)
                .foregroundStyle(selected ? GraceColor.buttonText : GraceColor.ink)
                .background(selected ? GraceColor.button : GraceColor.wash, in: Capsule()) }
            .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct ReadingText: View {
    let text: String
    var scale: Double = 1
    @ScaledMetric(relativeTo: .body) private var size = 23.0
    var body: some View { Text(text).font(.system(size: size * scale, weight: .regular, design: .serif)).lineSpacing(8).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
}
struct ReadingControls: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        HStack {
            Button { services.local.preferences.readingScale = max(0.8, services.local.preferences.readingScale - 0.1); services.local.save() } label: { Image(systemName: "textformat.size.smaller").frame(width: 48, height: 48) }.accessibilityLabel("Decrease reading size")
            Spacer(); Text("Reading size").font(.caption).foregroundStyle(GraceColor.secondary); Spacer()
            Button { services.local.preferences.readingScale = min(1.7, services.local.preferences.readingScale + 0.1); services.local.save() } label: { Image(systemName: "textformat.size.larger").frame(width: 48, height: 48) }.accessibilityLabel("Increase reading size")
        }.padding(.horizontal, 8).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 14))
    }
}
