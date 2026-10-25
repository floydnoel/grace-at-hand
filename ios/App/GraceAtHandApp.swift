import SwiftUI
import UIKit

@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    weak var downloads: DownloadManager?
    private var pendingCompletion: (() -> Void)?
    private var privacyCovers: [UIView] = []
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(coverPrivateContent), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(revealContent), name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }
    @objc private func coverPrivateContent() {
        guard privacyCovers.isEmpty else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where !window.isHidden {
                let cover = UIView(frame: window.bounds)
                cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                cover.backgroundColor = UIColor(GraceColor.canvas)
                let label = UILabel(); label.text = "Grace at Hand"
                label.font = .preferredFont(forTextStyle: .title1); label.textColor = UIColor(GraceColor.ink)
                label.translatesAutoresizingMaskIntoConstraints = false
                cover.addSubview(label); window.addSubview(cover)
                NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: cover.centerXAnchor), label.centerYAnchor.constraint(equalTo: cover.centerYAnchor)])
                privacyCovers.append(cover)
            }
        }
    }
    @objc private func revealContent() { privacyCovers.forEach { $0.removeFromSuperview() }; privacyCovers.removeAll() }
    func attach(_ downloads: DownloadManager) {
        self.downloads = downloads
        if let completion = pendingCompletion { pendingCompletion = nil; downloads.handleBackgroundEvents(completion: completion) }
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == DownloadManager.sessionIdentifier else { completionHandler(); return }
        if let downloads { downloads.handleBackgroundEvents(completion: completionHandler) }
        else { pendingCompletion = completionHandler }
    }
}

@main struct GraceAtHandApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var services: AppServices?
    @State private var startupError = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let services {
                    RootView().environment(services)
                        .preferredColorScheme(services.local.preferences.appearance == "light" ? .light : services.local.preferences.appearance == "dark" ? .dark : nil)
                        .task { await services.refresh() }
                        .task { await services.observeStorefront() }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in services.intentions.lock() }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in services.intentions.load() }
                } else if startupError {
                    ContentUnavailableView {
                        Label("A moment to reconnect", systemImage: "leaf")
                    } description: {
                        Text("Your local library could not be opened. Your saved data has not been erased.")
                    } actions: { Button("Try again", action: load) }
                } else { ProgressView("Opening a little space…").task { load() } }
            }
            .tint(GraceColor.accent)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { services?.intentions.load(); Task { await services?.refresh() } }
                else { services?.playback.savePosition(); services?.local.save() }
            }
        }
    }
    private func load() {
        do {
            let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
            let services = try AppServices(testing: testing)
            if ProcessInfo.processInfo.arguments.contains("--skip-welcome") { services.local.preferences.welcomed = true; services.local.save() }
            delegate.attach(services.downloads); self.services = services; startupError = false
        } catch { startupError = true }
    }
}
