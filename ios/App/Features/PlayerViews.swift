import SwiftUI
import AVKit
import AudioToolbox
import GraceCore

struct MiniPlayer: View {
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if let prayer = services.playback.current {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { services.showPlayer = true } label: {
                        HStack(spacing: 10) {
                            PrayerArtwork(evening: prayer.category == "Rest").frame(width: 42, height: 46).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prayer.title).font(.caption.weight(.semibold)).lineLimit(2)
                                Text(services.playback.isPlaying ? "Playing · \(prayer.durationLabel)" : "Paused · \(prayer.durationLabel)").font(.caption2).foregroundStyle(GraceColor.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Open player, \(prayer.title)")
                    Button { services.playback.toggle() } label: { Image(systemName: services.playback.isPlaying ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }.accessibilityLabel(services.playback.isPlaying ? "Pause" : "Play")
                    Button { services.playback.dismissCurrent() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close player and stop playback")
                }.padding(.leading, 10).padding(.trailing, 2).padding(.vertical, 7)
                GeometryReader { geometry in Rectangle().fill(GraceColor.accent).frame(width: geometry.size.width * min(1, services.playback.position / max(1, services.playback.duration))) }.frame(height: 2).accessibilityHidden(true)
            }
            .foregroundStyle(GraceColor.ink)
            .background { if reduceTransparency { GraceColor.card } else { Rectangle().fill(.regularMaterial) } }
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(GraceColor.border.opacity(0.6), lineWidth: 0.6))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .accessibilityIdentifier("miniPlayer")
        }
    }
}

struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.prioritizesVideoDevices = false; view.accessibilityLabel = "Audio output"; return view }
    func updateUIView(_ view: AVRoutePickerView, context: Context) { view.tintColor = UIColor(GraceColor.ink); view.activeTintColor = UIColor(GraceColor.accent) }
}

struct PlayerView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var seeking: Double?
    private var evening: Bool { services.playback.current?.category == "Rest" }
    var body: some View {
        NavigationStack {
            ScrollView {
                if let prayer = services.playback.current {
                    VStack(spacing: 24) {
                        Eyebrow(text: evening ? "A gentle ending" : "A little space for prayer").padding(.top, 12)
                        PrayerArtwork(evening: evening).frame(height: 270).clipShape(ArchShape()).frame(maxWidth: 340)
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(prayer.title).font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                                Text("\(prayer.topics.first ?? prayer.category) · \(prayer.durationLabel)").font(.subheadline).foregroundStyle(GraceColor.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button { services.local.toggleFavorite(prayer.id) } label: { Image(systemName: services.local.isFavorite(prayer.id) ? "heart.fill" : "heart").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel(services.local.isFavorite(prayer.id) ? "Remove saved prayer" : "Save prayer")
                        }
                        VStack(spacing: 3) {
                            Slider(value: Binding(get: { seeking ?? services.playback.position }, set: { seeking = $0 }), in: 0...max(1, services.playback.duration), onEditingChanged: { editing in if !editing, let seeking { services.playback.seek(to: seeking); self.seeking = nil } })
                                .accessibilityLabel("Playback position").accessibilityValue(time(seeking ?? services.playback.position))
                            HStack { Text(time(seeking ?? services.playback.position)); Spacer(); Text(time(services.playback.duration)) }.font(.caption).monospacedDigit().foregroundStyle(GraceColor.secondary)
                        }
                        HStack(spacing: 40) {
                            Button { services.playback.skip(-15) } label: { Image(systemName: "gobackward.15").font(.title2).frame(width: 48, height: 48) }.accessibilityLabel("Back 15 seconds")
                            Button { services.playback.toggle() } label: {
                                Group { if services.playback.isLoading { ProgressView().tint(GraceColor.buttonText) } else { Image(systemName: services.playback.isPlaying ? "pause.fill" : "play.fill").font(.title2) } }
                                    .frame(width: 70, height: 70).foregroundStyle(GraceColor.buttonText).background(GraceColor.button, in: Circle())
                            }.accessibilityLabel(services.playback.isPlaying ? "Pause prayer" : "Play prayer").accessibilityIdentifier("mainPlayback")
                            Button { services.playback.skip(15) } label: { Image(systemName: "goforward.15").font(.title2).frame(width: 48, height: 48) }.accessibilityLabel("Forward 15 seconds")
                        }
                        HStack {
                            Menu { ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in Button("\(value.formatted())×") { services.playback.setRate(Float(value)) } } } label: { Text("\(Double(services.playback.rate).formatted())×").font(.subheadline.weight(.semibold)).frame(width: 48, height: 48) }.accessibilityLabel("Playback speed")
                            Spacer(); SleepTimerMenu(); Spacer()
                            Button { services.download(prayer) } label: { Image(systemName: services.downloads.isAvailable(prayer) ? "checkmark.circle" : "arrow.down.to.line").font(.title3).frame(width: 48, height: 48) }.accessibilityLabel(services.downloads.isAvailable(prayer) ? "Downloaded" : "Download prayer").disabled(services.downloads.isAvailable(prayer))
                            Spacer(); AudioRoutePicker().frame(width: 48, height: 48)
                        }
                        if let record = services.downloads.record(prayer.id), record.state != .available { DownloadAction(prayer: prayer) }
                        if let message = services.playback.errorMessage {
                            StatusNotice(text: message, symbol: "waveform.slash")
                            Button("Try audio again") { Task { await services.play(prayer) } }.frame(minHeight: 44)
                        }
                        NavigationLink { ReaderView(prayer: prayer, transcript: true) } label: { HStack { Text("Read along"); Spacer(); Image(systemName: "book") }.padding(18).background(GraceColor.wash, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
                        if let deadline = services.playback.sleepDeadline { Text("Sleep timer ends at \(deadline.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(GraceColor.secondary) }
                        if services.playback.sleepAtEnd { Text("Playback will stop at the end of this prayer.").font(.caption).foregroundStyle(GraceColor.secondary) }
                    }.padding(24).frame(maxWidth: 580).frame(maxWidth: .infinity)
                }
            }.pageStyle().toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Close full player") }
                ToolbarItem(placement: .topBarTrailing) { Menu { Button("Stop listening") { services.playback.dismissCurrent(); dismiss() } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Player options") }
            }.navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(evening ? .dark : nil)
    }
    private func time(_ seconds: Double) -> String { let seconds = Int(max(0, seconds)); return String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

struct SleepTimerMenu: View {
    @Environment(AppServices.self) private var services
    var body: some View {
        Menu {
            Button("Off") { services.playback.setSleep(minutes: nil) }
            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in Button("\(minutes) minutes") { services.playback.setSleep(minutes: minutes) } }
            Button("At the end of this prayer") { services.playback.setSleep(minutes: 0) }
        } label: { Image(systemName: services.playback.sleepDeadline == nil && !services.playback.sleepAtEnd ? "moon" : "moon.fill").font(.title3).frame(width: 48, height: 48) }.accessibilityLabel("Sleep timer")
    }
}

struct ReaderView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prayer: Prayer
    let transcript: Bool
    @State private var follow = false
    private var paragraphs: [String] { transcript ? prayer.transcript : prayer.text }
    private var activeParagraph: Int? { guard transcript, follow, services.playback.current?.id == prayer.id else { return nil }; return prayer.cues?.first { services.playback.position >= $0.start && services.playback.position < $0.end }?.paragraph }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Eyebrow(text: prayer.title)
                    ReadingControls()
                    if transcript, !(prayer.cues ?? []).isEmpty { Toggle("Follow the recording", isOn: $follow).font(.subheadline) }
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                        ReadingText(text: text, scale: services.local.preferences.readingScale).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(activeParagraph == index ? GraceColor.wash : .clear, in: RoundedRectangle(cornerRadius: 16)).id(index)
                    }
                    Divider()
                    ForEach(prayer.credits, id: \.self) { Text($0).font(.caption).foregroundStyle(GraceColor.secondary) }
                    Button { services.local.markComplete(prayer) } label: { Label(services.local.record(prayer.id)?.completed == true ? "Completed · tap to undo" : "Mark session complete", systemImage: services.local.record(prayer.id)?.completed == true ? "checkmark.circle.fill" : "checkmark.circle") }.frame(minHeight: 44)
                }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity)
            }.onChange(of: activeParagraph) { _, next in
                guard let next else { return }
                if reduceMotion { proxy.scrollTo(next, anchor: .center) } else { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(next, anchor: .center) } }
            }
        }.pageStyle().navigationTitle(transcript ? "Read along" : "Read prayer").navigationBarTitleDisplayMode(.inline)
    }
}

struct RosaryView: View {
    @Environment(AppServices.self) private var services
    let initialSet: RosaryMysteries
    @State private var set: RosaryMysteries = .joyful
    @State private var index = 0
    @State private var showHelp = false
    @State private var following = false
    private var recording: Prayer? { services.catalog.catalog.item("rosary-\(set.rawValue)") }
    private var steps: [RosaryStep] { RosaryGuide.steps(for: set) }
    private var step: RosaryStep { steps[min(index, steps.count - 1)] }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    PageHeading(eyebrow: "The Holy Rosary", title: "The \(set.title)")
                    Picker("Choose mysteries", selection: $set) { ForEach(RosaryMysteries.allCases) { set in Text(set.title).tag(set) } }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Choose mysteries")
                    Text("Suggested today: \(RosaryMysteries.suggested(on: .now).title)").font(.caption).foregroundStyle(GraceColor.secondary)
                    if !(recording?.rosaryCues ?? []).isEmpty { Toggle("Follow the recording", isOn: $following).font(.subheadline) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    Circle().stroke(GraceColor.border, lineWidth: 1).frame(width: 180, height: 180)
                    ForEach(0..<10) { bead in Circle().fill(bead < (step.bead ?? 0) ? GraceColor.accent : GraceColor.border).frame(width: bead + 1 == step.bead ? 15 : 12, height: bead + 1 == step.bead ? 15 : 12).offset(x: sin(Double(bead) * .pi / 5) * 90, y: -cos(Double(bead) * .pi / 5) * 90) }
                    VStack(spacing: 8) {
                        Image(systemName: "cross").font(.title3).foregroundStyle(GraceColor.gold)
                        if let bead = step.bead { Text("\(bead) / 10").font(.system(.title, design: .serif)); Text("HAIL MARY").font(.caption2).tracking(1) }
                        else { Text(step.decade.map { "Decade \($0)" } ?? "Begin gently").font(.system(.headline, design: .serif)) }
                    }
                }.frame(height: 220).accessibilityElement(children: .ignore).accessibilityLabel(step.bead.map { "Hail Mary \($0) of 10, decade \(step.decade ?? 1) of 5" } ?? step.title)
                if let decade = step.decade { Eyebrow(text: "Decade \(decade) of 5") }
                Text(step.title).font(.system(.title, design: .serif)).multilineTextAlignment(.center)
                ReadingText(text: step.text, scale: services.local.preferences.readingScale).frame(maxWidth: .infinity)
                HStack(spacing: 32) {
                    Button { following = false; index = max(0, index - 1) } label: { Image(systemName: "chevron.left").frame(width: 50, height: 50).background(GraceColor.wash, in: Circle()) }.disabled(index == 0).accessibilityLabel("Previous Rosary prayer")
                    if let prayer = services.catalog.catalog.item("rosary-\(set.rawValue)") { Button { Task { await services.play(prayer) } } label: { Image(systemName: "play.fill").frame(width: 70, height: 70).foregroundStyle(GraceColor.buttonText).background(GraceColor.button, in: Circle()) }.accessibilityLabel("Listen to Rosary introduction") }
                    Button { following = false; index = min(steps.count - 1, index + 1) } label: { Image(systemName: "chevron.right").frame(width: 50, height: 50).background(GraceColor.wash, in: Circle()) }.disabled(index == steps.count - 1).accessibilityLabel("Next Rosary prayer")
                }
                Text("Step \(index + 1) of \(steps.count) · Move at your own pace").font(.caption).foregroundStyle(GraceColor.secondary)
                if index == steps.count - 1 { Button("Begin again") { index = 0 }.frame(minHeight: 44) }
                Text("Traditional prayer text · development edition pending editorial review").font(.caption2).foregroundStyle(GraceColor.secondary)
            }.padding(24).frame(maxWidth: GraceLayout.readingWidth).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
            .onAppear { set = initialSet }.onChange(of: set) { _, _ in index = 0 }
            .onChange(of: services.playback.position) { _, position in
                guard following, services.playback.current?.id == recording?.id,
                      let cue = recording?.rosaryCues?.first(where: { position >= $0.start && position < $0.end }) else { return }
                index = cue.step
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showHelp = true } label: { Image(systemName: "info.circle").frame(width: 44, height: 44) }.accessibilityLabel("How to pray the Rosary") } }
            .alert("How to pray the Rosary", isPresented: $showHelp) { Button("Done", role: .cancel) {} } message: { Text("Begin with the opening prayers. Each decade has an Our Father, ten Hail Marys, and a Glory Be, with one mystery for reflection. The bead controls advance the text independently. The sample audio is an introduction, not synchronized narration of the complete Rosary.") }
    }
}

struct SilenceView: View {
    @Environment(AppServices.self) private var services
    @State private var minutes = 5
    @State private var notify = false
    @State private var now = Date.now
    @State private var finished = false
    private var remaining: Int { max(0, Int(ceil(services.local.preferences.silenceDeadline?.timeIntervalSince(now) ?? Double(minutes * 60)))) }
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                PageHeading(eyebrow: "Room for stillness", title: "Sit with silence.", subtitle: "Nothing to achieve. A little space to be with God.").frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "leaf").font(.system(size: 60, weight: .ultraLight)).foregroundStyle(GraceColor.accent).padding(.top, 30)
                Text(finished ? "A gentle return." : String(format: "%d:%02d", remaining / 60, remaining % 60)).font(.system(size: 56, weight: .light, design: .serif)).monospacedDigit().accessibilityLabel(finished ? "Silence timer finished" : "\(remaining / 60) minutes, \(remaining % 60) seconds remaining")
                if services.local.preferences.silenceDeadline == nil {
                    Picker("Length", selection: $minutes) { ForEach([1, 3, 5, 10, 15, 20], id: \.self) { Text("\($0) minutes").tag($0) } }.pickerStyle(.menu)
                    Toggle("Opening and closing sound", isOn: Binding(get: { services.local.preferences.silenceSound }, set: { services.local.preferences.silenceSound = $0; services.local.save() }))
                    Toggle("Notify me when finished", isOn: $notify).onChange(of: notify) { _, value in if value { Task { if !(await services.reminders.requestPermission()) { notify = false } } } }
                    Button("Begin quiet time") {
                        services.playback.pause(); finished = false; now = .now
                        let deadline = now.addingTimeInterval(Double(minutes * 60))
                        services.local.preferences.silenceDeadline = deadline; services.local.save()
                        if services.local.preferences.silenceSound { AudioServicesPlaySystemSound(1057) }
                        if notify { Task { await services.reminders.scheduleSilence(at: deadline, sound: services.local.preferences.silenceSound) } }
                    }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("End quiet time") { end(sound: false) }.buttonStyle(PrimaryButtonStyle())
                }
                Text("The timer keeps its place if you leave the app. A background completion sound needs notification permission.").font(.footnote).foregroundStyle(GraceColor.secondary).multilineTextAlignment(.center)
            }.padding(24).frame(maxWidth: 580).frame(maxWidth: .infinity)
        }.pageStyle().navigationBarTitleDisplayMode(.inline)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0; if services.local.preferences.silenceDeadline != nil && remaining == 0 { end(sound: true) } }
    }
    private func end(sound: Bool) {
        services.local.preferences.silenceDeadline = nil; services.local.save(); services.reminders.cancelSilence(); finished = true
        if sound && services.local.preferences.silenceSound { AudioServicesPlaySystemSound(1057) }
    }
}
