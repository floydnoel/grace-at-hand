import Foundation
import Observation
import GraceCore

@MainActor @Observable final class ReadingLibraryRepository {
    private(set) var library: ReadingLibrary?
    private(set) var errorMessage: String?
    private let directory: URL?
    @ObservationIgnored private var engineTask: Task<ReadingSearchEngine, Error>?

    init(bundle: Bundle = .main, directory: URL? = nil) {
        self.directory = directory ?? bundle.url(forResource: "ReadingLibrary", withExtension: nil)
        do {
            guard let directory = self.directory else { throw ReadingLibraryError.invalid }
            let data = try Data(contentsOf: directory.appendingPathComponent("library.json"))
            let library = try JSONDecoder().decode(ReadingLibrary.self, from: data)
            try library.validate()
            if AppConfiguration(bundle: bundle).isProduction && library.isDevelopment { throw ReadingLibraryError.invalid }
            self.library = library
        } catch { errorMessage = error.localizedDescription }
    }
    func search(_ query: String, kind: ReadingKind?, author: String?, offlineOnly: Bool) async throws -> [ReadingSearchResult] {
        guard let library, let directory else { throw ReadingLibraryError.invalid }
        if engineTask == nil {
            engineTask = Task.detached(priority: .userInitiated) {
                let data = try Self.verifiedFile(library.searchIndex, in: directory)
                let documents = try JSONDecoder().decode([ReadingSearchDocument].self, from: data)
                return try ReadingSearchEngine(library: library, documents: documents)
            }
        }
        guard let task = engineTask else { throw ReadingLibraryError.invalid }
        do {
            let engine = try await task.value
            try Task.checkCancellation()
            let search = Task.detached(priority: .userInitiated) { engine.search(query, kind: kind, author: author, offlineOnly: offlineOnly) }
            return await withTaskCancellationHandler { await search.value } onCancel: { search.cancel() }
        } catch { if !Task.isCancelled { engineTask = nil }; throw error }
    }
    func blocks(for section: ReadingSection) async throws -> [ReadingBlock] {
        guard let directory else { throw ReadingLibraryError.invalid }
        return try await Task.detached(priority: .userInitiated) {
            let data = try Self.verifiedFile(section.file, in: directory)
            guard let markdown = String(data: data, encoding: .utf8) else { throw ReadingLibraryError.invalid }
            return ReadingBlock.parse(markdown)
        }.value
    }
    nonisolated static func verifiedFile(_ file: ReadingFile, in directory: URL) throws -> Data {
        guard file.isValid, file.bytes <= 64_000_000 else { throw ReadingLibraryError.invalid }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let url = root.appendingPathComponent(file.path).resolvingSymlinksInPath().standardizedFileURL
        guard url.path.hasPrefix(root.path + "/") else { throw ReadingLibraryError.invalid }
        let data = try Data(contentsOf: url)
        guard data.count == file.bytes, Integrity.sha256(data) == file.sha256 else { throw ReadingLibraryError.integrity }
        return data
    }
}

@MainActor @Observable final class ReadingShelfStore {
    private(set) var shelf = ReadingShelf()
    private(set) var errorMessage: String?
    private(set) var isLocked = false
    private(set) var needsRecovery = false
    private let file: URL
    private let accessAllowed: @MainActor () -> Bool
    init(root: URL? = nil, accessAllowed: @escaping @MainActor () -> Bool = { true }) throws {
        file = try PrivateFiles.directory("PrivateReading", root: root, protection: .complete).appendingPathComponent("shelf.json")
        self.accessAllowed = accessAllowed
        load()
    }
    func load() {
        guard accessAllowed() else { lock(); return }
        do {
            let next = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode(ReadingShelf.self, from: Data(contentsOf: file)) : ReadingShelf()
            try next.validate(); shelf = next; isLocked = false; needsRecovery = false; errorMessage = nil
        } catch { shelf = ReadingShelf(); isLocked = false; needsRecovery = true; errorMessage = "Saved readings could not be opened. Your file has not been changed." }
    }
    func lock() { shelf = ReadingShelf(); isLocked = true }
    func toggleSaved(_ id: String) {
        var next = shelf
        if next.savedIDs.contains(id) { next.savedIDs.removeAll { $0 == id } } else { next.savedIDs.append(id) }
        _ = persist(next)
    }
    func remember(_ sectionID: String) { var next = shelf; next.lastSectionID = sectionID; _ = persist(next) }
    func clearActivity() { var next = shelf; next.lastSectionID = nil; _ = persist(next) }
    @discardableResult func reset() -> Bool {
        guard accessAllowed() else { errorMessage = "Unlock your device to clear saved readings."; return false }
        do { try PrivateFiles.write(ReadingShelf(), to: file, complete: true); shelf = ReadingShelf(); needsRecovery = false; isLocked = false; errorMessage = nil; return true }
        catch { errorMessage = "Saved readings could not be cleared. Please try again."; return false }
    }
    private func persist(_ next: ReadingShelf) -> Bool {
        guard accessAllowed(), !isLocked, !needsRecovery else { errorMessage = needsRecovery ? "Try opening saved readings again before changing them." : "Unlock your device to save readings."; return false }
        do { try next.validate(); try PrivateFiles.write(next, to: file, complete: true); shelf = next; errorMessage = nil; return true }
        catch { errorMessage = "Your reading could not be saved. Please try again."; return false }
    }
}
