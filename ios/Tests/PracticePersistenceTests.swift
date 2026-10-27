import XCTest
import UIKit
import GraceCore
@testable import GraceAtHand

@MainActor final class PracticePersistenceTests: XCTestCase {
    private func temporaryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testPracticeRoundTripAndSelectiveDeletionPreserveOtherPrivateData() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try PracticeStore(root: root)
        let routine = PrayerRoutine(title: "Synthetic routine", prayerIDs: ["our-father", "hail-mary"])
        let goal = PrayerGoal(title: "Synthetic goal")
        let session = PracticeSession(title: "Synthetic prayer", durationSeconds: 300, source: .manual)
        let entry = JournalEntry(title: "Synthetic entry", body: "Synthetic private writing", tags: ["Family"], link: JournalLink(kind: .session, id: session.id.uuidString, title: session.title))
        XCTAssertTrue(store.saveRoutine(routine)); XCTAssertTrue(store.saveGoal(goal)); XCTAssertTrue(store.log(session)); XCTAssertTrue(store.saveEntry(entry))
        let reopened = try PracticeStore(root: root)
        XCTAssertEqual(reopened.document.routines, [routine]); XCTAssertEqual(reopened.document.goals, [goal])
        XCTAssertEqual(reopened.document.sessions, [session]); XCTAssertEqual(reopened.document.journal, [entry])
        XCTAssertTrue(reopened.clearActivity()); XCTAssertEqual(reopened.document.journal, [entry])
        XCTAssertTrue(reopened.clearJournal()); XCTAssertEqual(reopened.document.routines, [routine]); XCTAssertEqual(reopened.document.goals, [goal])
        let folder = try PrivateFiles.directory("PrivatePractice", root: root, protection: .complete)
        XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let file = folder.appendingPathComponent("practice.json")
        XCTAssertEqual(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.protectionKey] as? FileProtectionType, .complete)
        #endif
    }
    func testCorruptAndFuturePracticeFilesArePreservedUntilExplicitReset() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = try PrivateFiles.directory("PrivatePractice", root: root, protection: .complete)
        let file = folder.appendingPathComponent("practice.json")
        for bytes in [Data("unreadable synthetic record".utf8), try JSONEncoder().encode(futureDocument())] {
            try bytes.write(to: file)
            let store = try PracticeStore(root: root)
            XCTAssertTrue(store.needsRecovery)
            XCTAssertFalse(store.saveEntry(JournalEntry(title: "Synthetic", body: "New writing")))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            XCTAssertTrue(store.reset()); XCTAssertFalse(store.needsRecovery)
        }
    }
    private func futureDocument() -> PracticeDocument { var data = PracticeDocument(); data.schemaVersion = 99; return data }

    func testLockedPrivatePracticeCannotOverwriteOrExposeWriting() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        var allowed = true
        let store = try PracticeStore(root: root, accessAllowed: { allowed })
        let entry = JournalEntry(title: "Synthetic", body: "Protected synthetic writing")
        XCTAssertTrue(store.saveEntry(entry))
        allowed = false; store.lock()
        XCTAssertTrue(store.document.journal.isEmpty); XCTAssertFalse(store.clearJournal()); XCTAssertFalse(store.reset())
        allowed = true; store.load(); XCTAssertEqual(store.document.journal, [entry])
    }
    func testJournalDraftIsRetainedBeforeLockAndDoesNotReplaceSavedWriting() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let services = try AppServices(testing: true, root: root)
        let saved = JournalEntry(title: "Synthetic saved", body: "Original synthetic writing")
        XCTAssertTrue(services.practice.saveEntry(saved))
        var draft = saved; draft.body = "Unfinished synthetic edits"
        services.privateEditorFlushers[UUID()] = { services.practice.saveJournalDraft(draft) }
        services.lockPrivateData()
        XCTAssertTrue(services.practice.document.journalWithDrafts.isEmpty)
        services.loadPrivateData()
        XCTAssertEqual(services.practice.document.journal, [saved])
        XCTAssertEqual(services.practice.document.journalWithDrafts, [draft])
        XCTAssertTrue(services.practice.discardJournalDraft(saved.id))
        XCTAssertEqual(services.practice.document.journalWithDrafts, [saved])
    }
    func testCompletionIsIdempotentButNewPlaybackSessionsCanCount() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let services = try AppServices(testing: true, root: root)
        defer { services.playback.dismissCurrent() }
        let prayer = try XCTUnwrap(services.catalog.catalog.items.first)
        let url = try XCTUnwrap(prayer.audio.flatMap(services.catalog.mediaURL))
        services.playback.prepare(prayer, url: url, autoplay: false)
        services.playback.persist?(prayer, prayer.durationSeconds, true)
        services.playback.persist?(prayer, prayer.durationSeconds, true)
        XCTAssertEqual(services.practice.document.sessions.count, 1)
        services.playback.prepare(prayer, url: url, autoplay: false)
        services.playback.persist?(prayer, prayer.durationSeconds, true)
        XCTAssertEqual(services.practice.document.sessions.count, 2)
        services.local.preferences.keepHistory = false
        services.clearActivity()
        services.playback.persist?(prayer, prayer.durationSeconds, true)
        XCTAssertTrue(services.practice.document.sessions.isEmpty)
        XCTAssertFalse(services.diagnosticReport.contains(prayer.title))
    }
    func testManualBackfillEditsAndFutureDateRejection() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try PracticeStore(root: root)
        var session = PracticeSession(date: Date.now.addingTimeInterval(-172_800), title: "Synthetic manual", durationSeconds: 300, source: .manual)
        XCTAssertTrue(store.saveManual(session)); session.title = "Edited synthetic manual"
        XCTAssertTrue(store.saveManual(session)); XCTAssertEqual(store.document.sessions.count, 1)
        let future = PracticeSession(date: Date.now.addingTimeInterval(3600), title: "Future", durationSeconds: 300, source: .manual)
        XCTAssertFalse(store.saveManual(future)); XCTAssertEqual(store.document.sessions.first?.title, session.title)
    }
    func testRoutineReadingCompletionIsScopedAndCanBeUndone() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let services = try AppServices(testing: true, root: root)
        let prayer = try XCTUnwrap(services.catalog.catalog.items.first)
        let first = UUID(), second = UUID()
        services.completeReading(prayer, routineID: first)
        XCTAssertEqual(services.practice.completedIDs(for: first), [prayer.id])
        XCTAssertTrue(services.practice.completedIDs(for: second).isEmpty)
        services.completeReading(prayer, routineID: second)
        services.completeReading(prayer, routineID: first)
        XCTAssertTrue(services.practice.completedIDs(for: first).isEmpty)
        XCTAssertEqual(services.practice.completedIDs(for: second), [prayer.id])
    }
    func testOriginalIntentionsUpgradeWithUpdatesTagsAndSelectiveDeletion() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = try PrivateFiles.directory("PrivateIntentions", root: root, protection: .complete)
        let id = UUID()
        let original: [[String: Any]] = [["id": id.uuidString, "title": "Synthetic old hope", "note": "Original synthetic note", "createdAt": 800000000]]
        try JSONSerialization.data(withJSONObject: original).write(to: folder.appendingPathComponent("intentions.json"))
        let store = try IntentStore(root: root)
        XCTAssertEqual(store.entries.first?.note, "Original synthetic note")
        XCTAssertTrue(store.upsert(id: id, title: "Synthetic old hope", note: "Original synthetic note", tags: ["Family"], followUpDate: Date.now.addingTimeInterval(3600)))
        XCTAssertTrue(store.addUpdate(id, text: "Synthetic answered reflection"))
        let reopened = try IntentStore(root: root)
        XCTAssertEqual(reopened.entries.first?.tags, ["Family"]); XCTAssertEqual(reopened.entries.first?.updates.count, 1)
        XCTAssertTrue(reopened.upsert(id: id, title: "Synthetic old hope", note: "Original synthetic note", tags: ["Family"], status: .answered))
        XCTAssertNil(reopened.entries.first?.followUpDate); XCTAssertEqual(reopened.entries.first?.updates.count, 1)
        XCTAssertTrue(reopened.deleteUpdate(try XCTUnwrap(reopened.entries.first?.updates.first?.id), intention: id))
        XCTAssertEqual(reopened.entries.first?.note, "Original synthetic note")
    }
    func testAppLockPersistsRejectsFailedAuthenticationAndRelocks() async throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let lock = try AppLockService(root: root, authenticate: { true })
        let enabled = await lock.setEnabled(true); XCTAssertTrue(enabled); lock.lock(); XCTAssertFalse(lock.isUnlocked)
        let reopened = try AppLockService(root: root, authenticate: { false })
        XCTAssertTrue(reopened.enabled); XCTAssertFalse(reopened.isUnlocked)
        let failed = await reopened.unlock(); XCTAssertFalse(failed); XCTAssertFalse(reopened.isUnlocked)
        let failedDisable = await reopened.setEnabled(false); XCTAssertFalse(failedDisable); XCTAssertTrue(reopened.enabled)
        let success = await lock.unlock(); XCTAssertTrue(success); XCTAssertTrue(lock.isUnlocked)
        let disabled = await lock.setEnabled(false); XCTAssertTrue(disabled)
        XCTAssertFalse(try AppLockService(root: root).enabled)
    }
    func testExistingV1FavoritesAndPassagesSurviveNewPracticeStore() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let catalog = try CatalogRepository(configuration: AppConfiguration(), root: root)
        let prayer = try XCTUnwrap(catalog.catalog.items.first), passage = try XCTUnwrap(catalog.catalog.passages.first)
        do {
            let original = try LocalStore(root: root); original.toggleFavorite(prayer.id); original.togglePassage(passage); original.savePlayback(prayer, seconds: 3)
        }
        let services = try AppServices(testing: true, root: root, inMemory: false)
        XCTAssertTrue(services.local.isFavorite(prayer.id)); XCTAssertTrue(services.local.isSaved(passage)); XCTAssertEqual(services.local.checkpoint(for: prayer), 3)
        XCTAssertTrue(services.practice.document.journal.isEmpty)
        services.playback.dismissCurrent()
    }
}
