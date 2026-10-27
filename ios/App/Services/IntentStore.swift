import Foundation
import Observation
import UIKit
import GraceCore

@MainActor @Observable final class IntentStore {
    private(set) var entries: [PrayerIntention] = []
    private(set) var isLocked = false
    private(set) var errorMessage: String?
    private let file: URL
    private var loaded = false
    private let accessAllowed: () -> Bool
    init(root: URL? = nil, accessAllowed: @escaping () -> Bool = { UIApplication.shared.isProtectedDataAvailable }) throws {
        self.accessAllowed = accessAllowed
        file = try PrivateFiles.directory("PrivateIntentions", root: root, protection: .complete).appendingPathComponent("intentions.json")
        load()
    }
    func load() {
        guard accessAllowed() else { lock(); return }
        do {
            entries = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode([PrayerIntention].self, from: Data(contentsOf: file)) : []
            loaded = true; isLocked = false; errorMessage = nil
        } catch { loaded = false; entries = []; errorMessage = "Your intentions could not be opened. Your stored file has not been changed." }
    }
    func lock() { entries = []; loaded = false; isLocked = true }
    @discardableResult func upsert(id: UUID?, title: String, note: String, tags: [String] = [], status: IntentionStatus = .active, followUpDate: Date? = nil, quietStart: Int = 0, quietEnd: Int = 0) -> Bool {
        guard loaded, accessAllowed() else { errorMessage = "Unlock your private space to edit intentions."; return false }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        var next = entries
        let followUp = status == .active ? followUpDate : nil
        if let followUp, followUp <= .now { errorMessage = "Choose a follow-up time in the future."; return false }
        if followUp != nil, entries.filter({ entry in
            guard entry.id != id, entry.status == .active, let date = entry.followUpDate,
                  let actual = ReminderRules.snoozeDate(after: date, minutes: 0, quietStart: quietStart, quietEnd: quietEnd) else { return false }
            return actual > .now
        }).count >= 10 {
            errorMessage = "You can keep up to ten intention follow-ups. Remove one before adding another."; return false
        }
        if let id, let index = next.firstIndex(where: { $0.id == id }) {
            next[index].title = title; next[index].note = note; next[index].tags = tags; next[index].status = status; next[index].followUpDate = followUp
        } else { next.insert(.init(id: id ?? UUID(), title: title, note: note, tags: tags, status: status, followUpDate: followUp), at: 0) }
        return persist(next)
    }
    @discardableResult func addUpdate(_ id: UUID, text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        var next = entries; next[index].updates.append(.init(text: text)); return persist(next)
    }
    @discardableResult func deleteUpdate(_ update: UUID, intention: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == intention }) else { return false }
        var next = entries; next[index].updates.removeAll { $0.id == update }; return persist(next)
    }
    func delete(_ id: UUID) { _ = persist(entries.filter { $0.id != id }) }
    @discardableResult func clear() -> Bool {
        guard accessAllowed(), !isLocked else { errorMessage = "Unlock your private space to clear intentions."; return false }
        do {
            try PrivateFiles.write([PrayerIntention](), to: file, complete: true)
            entries = []; loaded = true; errorMessage = nil; return true
        } catch { errorMessage = "Your intentions could not be cleared. Please try again."; return false }
    }
    private func persist(_ next: [PrayerIntention]) -> Bool {
        guard loaded, accessAllowed() else { errorMessage = "Unlock your private space to change intentions."; return false }
        do { try PrivateFiles.write(next, to: file, complete: true); entries = next; errorMessage = nil; return true }
        catch { errorMessage = "Your intention could not be saved. Please try again."; return false }
    }
}
