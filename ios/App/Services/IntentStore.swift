import Foundation
import Observation
import UIKit

struct PrayerIntention: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var note: String
    let createdAt: Date
}

@MainActor @Observable final class IntentStore {
    private(set) var entries: [PrayerIntention] = []
    private(set) var isLocked = false
    private(set) var errorMessage: String?
    private let file: URL
    private var loaded = false
    init(root: URL? = nil) throws {
        file = try PrivateFiles.directory("PrivateIntentions", root: root, protection: .complete).appendingPathComponent("intentions.json")
        load()
    }
    func load() {
        guard UIApplication.shared.isProtectedDataAvailable else { lock(); return }
        do {
            entries = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode([PrayerIntention].self, from: Data(contentsOf: file)) : []
            loaded = true; isLocked = false; errorMessage = nil
        } catch { loaded = false; entries = []; errorMessage = "Your intentions could not be opened. Your stored file has not been changed." }
    }
    func lock() { entries = []; loaded = false; isLocked = true }
    @discardableResult func upsert(id: UUID?, title: String, note: String) -> Bool {
        guard loaded, UIApplication.shared.isProtectedDataAvailable else { errorMessage = "Unlock your device to edit intentions."; return false }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        var next = entries
        if let id, let index = next.firstIndex(where: { $0.id == id }) { next[index].title = title; next[index].note = note }
        else { next.insert(.init(id: UUID(), title: title, note: note, createdAt: .now), at: 0) }
        return persist(next)
    }
    func delete(_ id: UUID) { _ = persist(entries.filter { $0.id != id }) }
    @discardableResult func clear() -> Bool {
        guard UIApplication.shared.isProtectedDataAvailable, !isLocked else { errorMessage = "Unlock your device to clear intentions."; return false }
        do {
            try PrivateFiles.write([PrayerIntention](), to: file, complete: true)
            entries = []; loaded = true; errorMessage = nil; return true
        } catch { errorMessage = "Your intentions could not be cleared. Please try again."; return false }
    }
    private func persist(_ next: [PrayerIntention]) -> Bool {
        guard loaded, UIApplication.shared.isProtectedDataAvailable else { errorMessage = "Unlock your device to change intentions."; return false }
        do { try PrivateFiles.write(next, to: file, complete: true); entries = next; errorMessage = nil; return true }
        catch { errorMessage = "Your intention could not be saved. Please try again."; return false }
    }
}
