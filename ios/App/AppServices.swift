import Foundation
import Observation
import GraceCore
import StoreKit

@MainActor @Observable final class AppServices {
    let configuration: AppConfiguration
    let local: LocalStore
    let intentions: IntentStore
    let catalog: CatalogRepository
    let downloads: DownloadManager
    let playback: PlaybackService
    let reminders: ReminderService
    var showPlayer = false
    var storefrontCountry: String?
    var alertMessage: String?
    private var requestID = UUID()
    var canSupport: Bool { configuration.supportURL != nil && storefrontCountry == "USA" }

    init(testing: Bool = false, root: URL? = nil, inMemory: Bool? = nil) throws {
        configuration = AppConfiguration()
        let root = root ?? (testing ? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) : nil)
        local = try LocalStore(inMemory: inMemory ?? testing, root: root)
        intentions = try IntentStore(root: root)
        catalog = try CatalogRepository(configuration: configuration, root: root)
        downloads = try DownloadManager(root: root, testing: testing)
        playback = PlaybackService()
        reminders = try ReminderService(root: root)
        downloads.wifiOnly = local.preferences.wifiOnly
        downloads.resolveMedia = { [weak catalog] asset in catalog?.mediaURL(asset) }
        playback.persist = { [weak local] prayer, position, complete in local?.savePlayback(prayer, seconds: position, completed: complete) }
        reminders.quietStart = local.preferences.quietStart; reminders.quietEnd = local.preferences.quietEnd
        if let recent = local.recent.first, let prayer = self.prayer(recent.itemID) {
            let restoreRequest = requestID
            Task { [weak self] in
                guard let self else { return }
                let downloaded = await downloads.localURL(for: prayer)
                guard requestID == restoreRequest, playback.current == nil,
                      let url = downloaded ?? prayer.audio.flatMap(catalog.mediaURL) else { return }
                playback.prepare(prayer, url: url, position: local.checkpoint(for: prayer), autoplay: false)
            }
        }
    }
    func prayer(_ id: String) -> Prayer? { catalog.catalog.item(id) ?? downloads.record(id)?.prayer }
    func play(_ prayer: Prayer) async {
        let request = UUID(); requestID = request
        let localURL = await downloads.localURL(for: prayer)
        guard requestID == request else { return }
        guard let url = localURL ?? prayer.audio.flatMap(catalog.mediaURL) else { alertMessage = "This recording is unavailable. You can still read the prayer."; return }
        if playback.current?.id == prayer.id && playback.current?.audio?.revision == prayer.audio?.revision && playback.currentURL == url && playback.errorMessage == nil { playback.play() }
        else { playback.prepare(prayer, url: url, position: local.checkpoint(for: prayer)) }
        showPlayer = true
    }
    func refresh() async {
        await catalog.refresh()
        downloads.reconcileCatalog(catalog.catalog)
        if let id = playback.current?.id, catalog.catalog.withdrawnIDs.contains(id) { playback.dismissCurrent(); showPlayer = false }
        await reminders.refreshAuthorization()
        storefrontCountry = await Storefront.current?.countryCode
    }
    func observeStorefront() async {
        for await storefront in Storefront.updates {
            guard !Task.isCancelled else { return }
            storefrontCountry = storefront.countryCode
        }
    }
    func download(_ prayer: Prayer) {
        downloads.errorMessage = nil; downloads.start(prayer)
        if let message = downloads.errorMessage { alertMessage = message }
    }
    func reset() {
        guard intentions.clear() else { alertMessage = intentions.errorMessage; return }
        requestID = UUID(); playback.dismissCurrent(); showPlayer = false
        guard downloads.clear() else { alertMessage = downloads.errorMessage; return }
        guard reminders.clear() else { alertMessage = reminders.errorMessage; return }
        local.reset()
        if let error = local.errorMessage { alertMessage = error }
    }
    var diagnosticReport: String {
        "Grace at Hand support report\nApp version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")\nEnvironment: \(configuration.environment)\nCatalog revision: \(catalog.catalog.revision)\nConnectivity: \(catalog.isOffline ? "offline" : "available")\nPlayback error present: \(playback.errorMessage != nil)\nDownload error present: \(downloads.errorMessage != nil)\n\nThis report contains no prayer titles, search terms, activity history, or intention text."
    }
}
