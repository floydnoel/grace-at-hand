import XCTest
import UIKit
import GraceCore
@testable import GraceAtHand

@MainActor final class PersistenceTests: XCTestCase {
    func testPreviewCatalogAndHTTPDownload() async throws {
        guard AppConfiguration().environment == "preview" else { throw XCTSkip("Run make test-network with make preview running to test HTTP delivery.") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalog = try CatalogRepository(configuration: AppConfiguration(), root: root)
        await catalog.refresh()
        XCTAssertNil(catalog.errorMessage)
        let prayer = try XCTUnwrap(catalog.catalog.items.first)
        XCTAssertTrue(prayer.audio?.url.hasPrefix("media/") == true)
        let downloads = try DownloadManager(root: root, testing: true)
        downloads.resolveMedia = { catalog.mediaURL($0) }
        downloads.start(prayer)
        for _ in 0..<200 where !downloads.isAvailable(prayer) { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(downloads.isAvailable(prayer), downloads.record(prayer.id)?.message ?? "No verified HTTP download")
        let localURL = await downloads.localURL(for: prayer)
        XCTAssertTrue(localURL?.isFileURL == true)
        let reopened = try DownloadManager(root: root, testing: true)
        let restored = await reopened.localURL(for: prayer)
        XCTAssertEqual(restored, localURL)
    }
    func testAdaptiveColorsCanResolveOnTheRenderingThread() async {
        let component = await Task.detached {
            let color = UIColor(GraceColor.ink).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return red
        }.value
        XCTAssertEqual(component, 244.0 / 255, accuracy: 0.01)
    }
    func testV1StoreReopensAndClearingHistoryPreservesFavorites() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalogURL = try XCTUnwrap(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))
        let prayer = try XCTUnwrap(catalog.items.first)
        do {
            let store = try LocalStore(root: root)
            store.toggleFavorite(prayer.id); store.savePlayback(prayer, seconds: 10, completed: true)
            XCTAssertTrue(store.isFavorite(prayer.id))
        }
        let reopened = try LocalStore(root: root)
        XCTAssertTrue(reopened.isFavorite(prayer.id))
        XCTAssertEqual(reopened.checkpoint(for: prayer), 10)
        reopened.clearHistory()
        XCTAssertTrue(reopened.isFavorite(prayer.id)); XCTAssertTrue(reopened.recent.isEmpty)
        XCTAssertEqual(reopened.checkpoint(for: prayer), 0)
        let values = try root.appendingPathComponent("LocalPrayer").resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
    func testIntentionsPersistAndDeletionDoesNotRestoreOldText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try IntentStore(root: root)
        XCTAssertTrue(store.upsert(id: nil, title: "Test intention", note: "Private test text"))
        let id = try XCTUnwrap(store.entries.first?.id)
        let reopened = try IntentStore(root: root)
        XCTAssertEqual(reopened.entries.first?.note, "Private test text")
        reopened.delete(id)
        XCTAssertTrue(try IntentStore(root: root).entries.isEmpty)
        let file = root.appendingPathComponent("PrivateIntentions/intentions.json")
        #if !targetEnvironment(simulator)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }
    func testLockedIntentionsCannotOverwriteStoredData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try IntentStore(root: root)
        XCTAssertTrue(store.upsert(id: nil, title: "Keep this", note: ""))
        store.lock()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(store.upsert(id: nil, title: "Should not save", note: ""))
        store.load()
        XCTAssertEqual(store.entries.map(\.title), ["Keep this"])
    }
    func testBundledMediaCanBeDownloadedAndVerified() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try CatalogRepository(configuration: AppConfiguration(), root: root)
        let manager = try DownloadManager(root: root, testing: true)
        manager.resolveMedia = { repository.mediaURL($0) }
        let prayer = try XCTUnwrap(repository.catalog.items.first)
        manager.start(prayer)
        for _ in 0..<100 where !manager.isAvailable(prayer) { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(manager.isAvailable(prayer))
        let localURL = await manager.localURL(for: prayer)
        let url = try XCTUnwrap(localURL)
        try Data("corrupted".utf8).write(to: url)
        let corrupted = await manager.localURL(for: prayer)
        XCTAssertNil(corrupted)
        XCTAssertEqual(manager.record(prayer.id)?.state, .failed)
        manager.remove(prayer.id)
        XCTAssertNil(manager.record(prayer.id))
    }
    func testRestoreUsesDownloadedAudioAndRemainsPaused() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try CatalogRepository(configuration: AppConfiguration(), root: root)
        let prayer = try XCTUnwrap(repository.catalog.items.first)
        let downloads = try DownloadManager(root: root, testing: true)
        downloads.resolveMedia = { repository.mediaURL($0) }
        downloads.start(prayer)
        for _ in 0..<100 where !downloads.isAvailable(prayer) { try await Task.sleep(for: .milliseconds(50)) }
        let localURL = await downloads.localURL(for: prayer)
        XCTAssertNotNil(localURL)
        do { let store = try LocalStore(root: root); store.savePlayback(prayer, seconds: 8) }
        let restored = try AppServices(testing: true, root: root, inMemory: false)
        for _ in 0..<100 where restored.playback.current == nil { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertEqual(restored.playback.currentURL, localURL)
        XCTAssertFalse(restored.playback.isPlaying)
        XCTAssertEqual(restored.local.checkpoint(for: prayer), 8, accuracy: 0.1)
        restored.playback.dismissCurrent()
    }
    func testInterruptedTransferReconcilesWithoutRemovingTextOrFavorite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try CatalogRepository(configuration: AppConfiguration(), root: root)
        let prayer = try XCTUnwrap(repository.catalog.items.first)
        let folder = try PrivateFiles.directory("Downloads", root: root)
        let record = DownloadRecord(prayer: prayer, pendingPrayer: nil, state: .downloading, progress: 0.4, taskID: 9999, message: nil)
        try PrivateFiles.write([record], to: folder.appendingPathComponent("records.json"))
        let local = try LocalStore(inMemory: true, root: root); local.toggleFavorite(prayer.id)
        let manager = try DownloadManager(root: root, testing: true)
        for _ in 0..<100 where manager.record(prayer.id)?.state == .downloading { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertEqual(manager.record(prayer.id)?.state, .failed)
        XCTAssertEqual(manager.record(prayer.id)?.prayer.text, prayer.text)
        XCTAssertTrue(local.isFavorite(prayer.id))
    }
    func testCorruptIntentionsArePreservedUntilExplicitReset() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try PrivateFiles.directory("PrivateIntentions", root: root, protection: .complete)
        let file = folder.appendingPathComponent("intentions.json")
        let corrupt = Data("unreadable private data".utf8); try corrupt.write(to: file)
        let store = try IntentStore(root: root)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.upsert(id: nil, title: "Do not overwrite", note: ""))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        XCTAssertTrue(store.clear())
        XCTAssertTrue(try IntentStore(root: root).entries.isEmpty)
    }
    func testInvalidCatalogCacheFallsBackToBundledText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try CatalogRepository(configuration: AppConfiguration(), root: root)
        let folder = try PrivateFiles.directory("PublicCatalog", root: root)
        let file = folder.appendingPathComponent("catalog-cache.json")
        try PrivateFiles.write(CachedCatalog(generation: 42, catalog: repository.catalog), to: file)
        XCTAssertEqual(try CatalogRepository(configuration: AppConfiguration(), root: root).catalog.revision, repository.catalog.revision)
        var envelope = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        var catalog = envelope["catalog"] as! [String: Any]; catalog["schemaVersion"] = 999; envelope["catalog"] = catalog
        try JSONSerialization.data(withJSONObject: envelope).write(to: file)
        let fallback = try CatalogRepository(configuration: AppConfiguration(), root: root)
        XCTAssertEqual(fallback.catalog.schemaVersion, 1)
        XCTAssertFalse(fallback.catalog.items[0].text.isEmpty)
    }
}
