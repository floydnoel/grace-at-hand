import XCTest
import GraceCore
@testable import GraceAtHand

@MainActor final class ReadingLibraryTests: XCTestCase {
    func testBundledMarkdownAndTopicSearchWorkWithoutNetwork() async throws {
        let repository = ReadingLibraryRepository()
        let library = try XCTUnwrap(repository.library, repository.errorMessage ?? "Missing bundled library")
        XCTAssertEqual(library.works.filter { $0.kind == .bible }.count, 73)
        let section = try XCTUnwrap(library.section("drb-psa-22"))
        let blocks = try await repository.blocks(for: section)
        XCTAssertTrue(blocks.contains { $0.id == "verse-1" && $0.text.contains("The Lord ruleth me") })
        let results = try await repository.search("suffering", kind: nil, author: nil, offlineOnly: false)
        XCTAssertTrue(results.contains { $0.sectionID == "papal-ben16-spe-salvi-text" && $0.excerpt != nil })
        XCTAssertTrue(results.contains { $0.sectionID == "drb-rom-8" })
        let offline = try await repository.search("sorrow", kind: nil, author: nil, offlineOnly: true)
        XCTAssertTrue(offline.allSatisfy { $0.sectionID != nil })
        XCTAssertFalse(offline.isEmpty)
        XCTAssertTrue(library.works.allSatisfy(\.isOffline))
        let papal = try XCTUnwrap(library.section("papal-ben16-spe-salvi-text"))
        let papalBlocks = try await repository.blocks(for: papal)
        XCTAssertTrue(papalBlocks.contains { $0.text.localizedCaseInsensitiveContains("in hope we were saved") })
    }

    func testReadingShelfReopensAndClearingActivityPreservesBookmarks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ReadingShelfStore(root: root)
        store.toggleSaved("drb-rom-8"); store.remember("drb-rom-8")
        let reopened = try ReadingShelfStore(root: root)
        XCTAssertEqual(reopened.shelf.savedIDs, ["drb-rom-8"])
        XCTAssertEqual(reopened.shelf.lastSectionID, "drb-rom-8")
        reopened.clearActivity()
        let cleared = try ReadingShelfStore(root: root)
        XCTAssertEqual(cleared.shelf.savedIDs, ["drb-rom-8"]); XCTAssertNil(cleared.shelf.lastSectionID)
        let file = root.appendingPathComponent("PrivateReading/shelf.json")
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.protectionKey] as? FileProtectionType, .complete)
        #endif
    }

    func testLockedAndUnreadableReadingShelvesPreserveStoredBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var allowed = true
        let store = try ReadingShelfStore(root: root, accessAllowed: { allowed })
        store.toggleSaved("drb-rom-8")
        let file = root.appendingPathComponent("PrivateReading/shelf.json")
        let before = try Data(contentsOf: file)
        allowed = false; store.lock(); store.toggleSaved("another-reading")
        XCTAssertTrue(store.shelf.savedIDs.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), before)
        allowed = true; store.load(); XCTAssertEqual(store.shelf.savedIDs, ["drb-rom-8"])
        let broken = Data("{unreadable".utf8); try broken.write(to: file)
        store.load(); store.toggleSaved("another-reading"); store.remember("another-reading")
        XCTAssertTrue(store.needsRecovery); XCTAssertEqual(try Data(contentsOf: file), broken)
        XCTAssertTrue(store.reset()); XCTAssertFalse(store.needsRecovery)
    }

    func testMarkdownIntegrityAndPathBoundariesFailClosed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("changed".utf8).write(to: directory.appendingPathComponent("chapter.md"))
        func file(_ path: String) throws -> ReadingFile {
            let object: [String: Any] = ["path": path, "sha256": String(repeating: "0", count: 64), "bytes": 7]
            return try JSONDecoder().decode(ReadingFile.self, from: JSONSerialization.data(withJSONObject: object))
        }
        XCTAssertThrowsError(try ReadingLibraryRepository.verifiedFile(file("chapter.md"), in: directory))
        XCTAssertThrowsError(try ReadingLibraryRepository.verifiedFile(file("../outside.md"), in: directory))
    }
}
