import Foundation
import Observation
import UIKit
import GraceCore

@MainActor @Observable final class PracticeStore {
    private(set) var document = PracticeDocument()
    private(set) var isLocked = false
    private(set) var needsRecovery = false
    private(set) var errorMessage: String?
    private var loaded = false
    private let file: URL
    private let accessAllowed: () -> Bool

    init(root: URL? = nil, accessAllowed: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable }) throws {
        self.accessAllowed = accessAllowed
        file = try PrivateFiles.directory("PrivatePractice", root: root, protection: .complete).appendingPathComponent("practice.json")
        load()
    }
    func load() {
        guard accessAllowed() else { lock(); return }
        do {
            let next = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode(PracticeDocument.self, from: Data(contentsOf: file)) : PracticeDocument()
            try next.validate()
            document = next; loaded = true; isLocked = false; needsRecovery = false; errorMessage = nil
        } catch {
            document = PracticeDocument(); loaded = false; isLocked = false; needsRecovery = true
            errorMessage = "Your practice records could not be opened. The stored file has not been changed. Try again or explicitly reset these records."
        }
    }
    func lock() { document = PracticeDocument(); loaded = false; isLocked = true }
    @discardableResult private func change(_ edit: (inout PracticeDocument) -> Void) -> Bool {
        guard loaded, accessAllowed() else { errorMessage = "Unlock your private space before changing practice records."; return false }
        var next = document; edit(&next)
        return write(next)
    }
    private func write(_ next: PracticeDocument) -> Bool {
        do {
            try next.validate(); try PrivateFiles.write(next, to: file, complete: true)
            document = next; loaded = true; isLocked = false; needsRecovery = false; errorMessage = nil; return true
        } catch { errorMessage = "Your practice change could not be saved. Please try again."; return false }
    }
    @discardableResult func reset() -> Bool {
        guard accessAllowed() else { errorMessage = "Unlock your private space before resetting practice records."; return false }
        return write(PracticeDocument())
    }
    @discardableResult func saveRoutine(_ routine: PrayerRoutine) -> Bool {
        change { data in data.routines.removeAll { $0.id == routine.id }; data.routines.append(routine) }
    }
    @discardableResult func deleteRoutine(_ id: UUID) -> Bool { change { $0.routines.removeAll { $0.id == id } } }
    @discardableResult func saveGoal(_ goal: PrayerGoal) -> Bool {
        change { data in data.goals.removeAll { $0.id == goal.id }; data.goals.append(goal) }
    }
    @discardableResult func deleteGoal(_ id: UUID) -> Bool { change { $0.goals.removeAll { $0.id == id } } }
    @discardableResult func setStreaks(_ enabled: Bool) -> Bool { change { $0.showStreaks = enabled } }
    @discardableResult func setProgressVisible(_ enabled: Bool) -> Bool { change { $0.showProgress = enabled } }
    @discardableResult func beginSilence(_ session: PracticeSession?) -> Bool { change { $0.silenceSession = session } }
    @discardableResult func log(_ session: PracticeSession, now: Date = .now) -> Bool {
        guard session.date <= now else { errorMessage = "Choose a prayer time in the past or present."; return false }
        guard !document.sessions.contains(where: { $0.sourceID == session.sourceID }) else { return true }
        return change { $0.sessions.append(session) }
    }
    @discardableResult func saveManual(_ session: PracticeSession, now: Date = .now) -> Bool {
        guard session.source == .manual, session.date <= now else { errorMessage = "Choose a prayer time in the past or present."; return false }
        return change { data in data.sessions.removeAll { $0.id == session.id }; data.sessions.append(session) }
    }
    @discardableResult func deleteSession(_ id: UUID) -> Bool { change { $0.sessions.removeAll { $0.id == id } } }
    @discardableResult func clearActivity() -> Bool { change { $0.sessions = [] } }
    @discardableResult func saveEntry(_ entry: JournalEntry) -> Bool {
        change { data in data.journal.removeAll { $0.id == entry.id }; data.journalDrafts.removeAll { $0.id == entry.id }; data.journal.append(entry) }
    }
    @discardableResult func saveJournalDraft(_ entry: JournalEntry) -> Bool {
        change { $0.journalDrafts.removeAll { $0.id == entry.id }; $0.journalDrafts.append(entry) }
    }
    @discardableResult func discardJournalDraft(_ id: UUID) -> Bool { change { $0.journalDrafts.removeAll { $0.id == id } } }
    @discardableResult func deleteEntry(_ id: UUID) -> Bool { change { $0.journal.removeAll { $0.id == id }; $0.journalDrafts.removeAll { $0.id == id } } }
    @discardableResult func clearJournal() -> Bool { change { $0.journal = []; $0.journalDrafts = [] } }
    func completedIDs(for routine: UUID, on date: Date = .now) -> Set<String> {
        let day = LocalDay.key(date)
        return Set(document.sessions.filter { $0.routineID == routine && $0.day == day }.compactMap(\.prayerID))
    }
    @discardableResult func undoRoutinePrayer(_ prayerID: String, routineID: UUID, on date: Date = .now) -> Bool {
        let day = LocalDay.key(date)
        return change { $0.sessions.removeAll { $0.routineID == routineID && $0.prayerID == prayerID && $0.day == day } }
    }
}
