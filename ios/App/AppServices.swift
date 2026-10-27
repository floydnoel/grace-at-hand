import Foundation
import Observation
import GraceCore
import StoreKit
import UIKit

@MainActor @Observable final class AppServices {
    let configuration: AppConfiguration
    let local: LocalStore
    let intentions: IntentStore
    let catalog: CatalogRepository
    let downloads: DownloadManager
    let playback: PlaybackService
    let reminders: ReminderService
    let practice: PracticeStore
    let appLock: AppLockService
    var privatePresentationID = UUID()
    var pendingIntentionID: String?
    private var pendingSessions: [PracticeSession] = []
    var privateEditorFlushers: [UUID: () -> Void] = [:]
    var showPlayer = false
    var storefrontCountry: String?
    var alertMessage: String?
    private var requestID = UUID()
    var canSupport: Bool { configuration.supportURL != nil && storefrontCountry == "USA" }

    init(testing: Bool = false, root: URL? = nil, inMemory: Bool? = nil) throws {
        configuration = AppConfiguration()
        let root = root ?? (testing ? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) : nil)
        local = try LocalStore(inMemory: inMemory ?? testing, root: root)
        let lock = try AppLockService(root: root)
        appLock = lock
        let access = { @MainActor [weak lock] in lock?.isUnlocked == true && UIApplication.shared.isProtectedDataAvailable }
        intentions = try IntentStore(root: root, accessAllowed: access)
        practice = try PracticeStore(root: root, accessAllowed: access)
        catalog = try CatalogRepository(configuration: configuration, root: root)
        downloads = try DownloadManager(root: root, testing: testing)
        playback = PlaybackService()
        reminders = try ReminderService(root: root)
        applyPreferences()
        downloads.resolveMedia = { [weak catalog] asset in catalog?.mediaURL(asset) }
        playback.persist = { [weak self] prayer, position, complete in
            guard let self else { return }
            local.savePlayback(prayer, seconds: position, completed: complete)
            if complete {
                recordPractice(PracticeSession(title: prayer.title, durationSeconds: prayer.durationSeconds, source: .audio,
                                              sourceID: "audio:\(playback.sessionID)", prayerID: prayer.id, routineID: playback.routineID))
            }
        }
        if let recent = local.recent.first, let prayer = self.prayer(recent.itemID) {
            let restoreRequest = requestID
            Task { [weak self] in
                guard let self else { return }
                let downloaded = await downloads.localRecording(for: prayer)
                guard requestID == restoreRequest, playback.current == nil, !catalog.catalog.withdrawnIDs.contains(prayer.id),
                      let url = downloaded?.url ?? prayer.audio.flatMap(catalog.mediaURL) else { return }
                let selected = downloaded?.prayer ?? prayer
                playback.prepare(selected, url: url, position: local.checkpoint(for: selected), autoplay: false)
            }
        }
    }
    func prayer(_ id: String) -> Prayer? {
        guard !catalog.catalog.withdrawnIDs.contains(id) else { return nil }
        return catalog.catalog.item(id) ?? downloads.record(id)?.prayer
    }
    func play(_ prayer: Prayer, routineID: UUID? = nil) async {
        guard !catalog.catalog.withdrawnIDs.contains(prayer.id) else { alertMessage = "This prayer is no longer available in the current library."; return }
        let request = UUID(); requestID = request
        let downloaded = await downloads.localRecording(for: prayer)
        guard requestID == request, !catalog.catalog.withdrawnIDs.contains(prayer.id) else { return }
        guard let url = downloaded?.url ?? prayer.audio.flatMap(catalog.mediaURL) else { alertMessage = "This recording is unavailable. You can still read the prayer."; return }
        let selected = downloaded?.prayer ?? prayer
        if playback.current?.id == selected.id && playback.current?.audio?.revision == selected.audio?.revision && playback.currentURL == url && playback.errorMessage == nil { playback.play() }
        else { playback.prepare(selected, url: url, position: local.checkpoint(for: selected)) }
        playback.routineID = routineID
        showPlayer = true
    }
    func refresh() async {
        await catalog.refresh()
        downloads.reconcileCatalog(catalog.catalog)
        if let id = playback.current?.id, catalog.catalog.withdrawnIDs.contains(id) { playback.dismissCurrent(); showPlayer = false }
        await reminders.refreshAuthorization()
        if !intentions.isLocked, intentions.errorMessage == nil { await reminders.syncFollowUps(intentions.entries) }
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
        guard practice.reset() else { alertMessage = practice.errorMessage; return }
        guard appLock.resetUnlocked() else { alertMessage = appLock.errorMessage; return }
        pendingSessions = []; pendingIntentionID = nil
        requestID = UUID(); playback.dismissCurrent(); showPlayer = false
        guard downloads.clear() else { alertMessage = downloads.errorMessage; return }
        guard reminders.clear() else { alertMessage = reminders.errorMessage; return }
        local.reset()
        applyPreferences()
        if let error = local.errorMessage { alertMessage = error }
    }
    func lockPrivateData() {
        for flush in privateEditorFlushers.values { flush() }
        privateEditorFlushers = [:]
        appLock.lock(); intentions.lock(); practice.lock(); privatePresentationID = UUID()
    }
    func loadPrivateData() {
        guard appLock.isUnlocked, UIApplication.shared.isProtectedDataAvailable else { return }
        intentions.load(); practice.load()
        if !practice.needsRecovery {
            let queued = pendingSessions; pendingSessions = []
            for session in queued { recordPractice(session) }
        }
    }
    func unlockPrivateSpace() async { if await appLock.unlock() { loadPrivateData() } }
    func recordPractice(_ session: PracticeSession) {
        guard local.preferences.keepHistory else { return }
        if practice.isLocked {
            if !pendingSessions.contains(where: { $0.sourceID == session.sourceID }) { pendingSessions.append(session) }
        } else { _ = practice.log(session) }
    }
    func completeReading(_ prayer: Prayer, routineID: UUID? = nil) {
        guard local.preferences.keepHistory else { local.markComplete(prayer); return }
        if let routineID {
            if practice.completedIDs(for: routineID).contains(prayer.id) { practice.undoRoutinePrayer(prayer.id, routineID: routineID) }
            else {
                if local.record(prayer.id)?.completed != true { local.markComplete(prayer) }
                recordPractice(PracticeSession(title: prayer.title, durationSeconds: 0, source: .reading,
                                              sourceID: "routine-reading:\(routineID):\(prayer.id):\(LocalDay.key(.now))", prayerID: prayer.id, routineID: routineID))
            }
            return
        }
        let source = "reading:\(prayer.id):\(LocalDay.key(.now))"
        if !practice.document.sessions.contains(where: { $0.sourceID == source }) {
            if local.record(prayer.id)?.completed != true { local.markComplete(prayer) }
            recordPractice(PracticeSession(title: prayer.title, durationSeconds: 0, source: .reading,
                                          sourceID: source, prayerID: prayer.id))
        } else {
            for session in practice.document.sessions where session.sourceID == source { practice.deleteSession(session.id) }
            if local.record(prayer.id)?.completed == true { local.markComplete(prayer) }
        }
    }
    func clearActivity() {
        pendingSessions = []; playback.dismissCurrent(); local.clearHistory()
        if !practice.clearActivity() { alertMessage = practice.errorMessage }
    }
    @discardableResult func resetPracticeRecords() -> Bool {
        guard practice.reset() else { return false }
        pendingSessions = []; return true
    }
    private func applyPreferences() {
        downloads.wifiOnly = local.preferences.wifiOnly
        reminders.quietStart = local.preferences.quietStart
        reminders.quietEnd = local.preferences.quietEnd
    }
    var diagnosticReport: String {
        "Grace at Hand support report\nApp version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")\nEnvironment: \(configuration.environment)\nCatalog revision: \(catalog.catalog.revision)\nConnectivity: \(catalog.isOffline ? "offline" : "available")\nPlayback error present: \(playback.errorMessage != nil)\nDownload error present: \(downloads.errorMessage != nil)\n\nThis report contains no prayer titles, search terms, activity history, or intention text."
    }
}
