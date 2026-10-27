import Foundation
import Observation
import GraceCore

enum TransferState: String, Codable { case downloading, verifying, available, failed }
struct DownloadRecord: Codable, Identifiable {
    var id: String { prayer.id }
    var prayer: Prayer
    var pendingPrayer: Prayer?
    var state: TransferState
    var progress: Double
    var taskID: Int?
    var message: String?
    var target: Prayer { pendingPrayer ?? prayer }
}
struct DownloadedRecording {
    let prayer: Prayer
    let url: URL
}

@MainActor @Observable final class DownloadManager: NSObject {
    static let sessionIdentifier = "org.graceathand.downloads.v1"
    private(set) var records: [DownloadRecord] = []
    private(set) var needsRecovery = false
    var errorMessage: String?
    private let directory: URL
    nonisolated let stagingDirectory: URL
    private let metadataURL: URL
    private var session: URLSession!
    private var fixtureTasks: [String: Task<Void, Never>] = [:]
    private var backgroundCompletion: (() -> Void)?
    private var pendingVerifications = 0
    private var finishedBackgroundEvents = false
    var wifiOnly = true
    var resolveMedia: ((MediaAsset) -> URL?)?
    private let recoveryMessage = "Download records could not be opened. Try again, or reset downloads to rebuild this library. Your saved favorites have not changed."

    init(root: URL? = nil, testing: Bool = false) throws {
        directory = try PrivateFiles.directory("Downloads", root: root)
        stagingDirectory = try PrivateFiles.directory("Transfers", root: root)
        metadataURL = directory.appendingPathComponent("records.json")
        super.init()
        // No verification task survives process death; URLSession owns in-flight temporary files elsewhere.
        for file in (try? FileManager.default.contentsOfDirectory(at: stagingDirectory, includingPropertiesForKeys: nil)) ?? [] { try? FileManager.default.removeItem(at: file) }
        loadRecords()
        let config = testing ? URLSessionConfiguration.default : URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = !testing
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        reconcileTransfers()
    }
    private func loadRecords() {
        do {
            records = try JSONDecoder().decode([DownloadRecord].self, from: Data(contentsOf: metadataURL))
            needsRecovery = false; errorMessage = nil
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            records = []; needsRecovery = false; errorMessage = nil
        } catch { needsRecovery = true; errorMessage = recoveryMessage }
    }
    func retryLoading() { loadRecords(); reconcileTransfers() }
    func record(_ id: String) -> DownloadRecord? { records.first { $0.id == id } }
    private func fileURL(_ prayer: Prayer) -> URL? {
        guard let asset = prayer.audio else { return nil }
        return directory.appendingPathComponent(asset.sha256 + ".m4a")
    }
    func isAvailable(_ prayer: Prayer) -> Bool {
        guard !needsRecovery, let record = record(prayer.id), let url = fileURL(record.prayer),
              record.prayer.audio?.revision == prayer.audio?.revision else { return false }
        return FileManager.default.fileExists(atPath: url.path) && (record.state == .available || record.pendingPrayer != nil)
    }
    var available: [Prayer] { records.filter { isAvailable($0.prayer) }.map(\.prayer) }
    var totalBytes: Int64 { available.compactMap(\.audio?.bytes).reduce(0, +) }
    func localURL(for prayer: Prayer) async -> URL? {
        guard isAvailable(prayer) else { return nil }
        guard let recording = await localRecording(for: prayer), recording.prayer.audio == prayer.audio else { return nil }
        return recording.url
    }
    func localRecording(for prayer: Prayer) async -> DownloadedRecording? {
        // A retained recording must travel with its own text, credits and resume revision.
        // Retry once if a replacement finishes while the old file is being verified.
        for _ in 0..<2 {
            guard !needsRecovery, let saved = record(prayer.id)?.prayer, isAvailable(saved),
                  let url = fileURL(saved), let asset = saved.audio else { return nil }
            do {
                let hash = try await Task.detached(priority: .utility) { try Integrity.fileHash(url) }.value
                guard record(prayer.id)?.prayer.audio == asset else { continue }
                guard hash == asset.sha256 else { throw URLError(.cannotDecodeContentData) }
                guard isAvailable(saved) else { return nil }
                return DownloadedRecording(prayer: saved, url: url)
            } catch {
                guard let index = records.firstIndex(where: { $0.id == prayer.id }) else { return nil }
                guard records[index].prayer.audio == asset else { continue }
                if records[index].pendingPrayer == nil { records[index].state = .failed }
                records[index].message = "This download could not be verified. Download it again."; persist()
                return nil
            }
        }
        return nil
    }
    func start(_ prayer: Prayer) {
        guard !needsRecovery else { errorMessage = recoveryMessage; return }
        guard let asset = prayer.audio, let source = resolveMedia?(asset) else { errorMessage = "This recording is not available to download. You can still read the prayer."; return }
        if let record = record(prayer.id), record.state == .downloading || record.state == .verifying { return }
        do {
            let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage, available < asset.bytes + 20_000_000 {
                errorMessage = "There isn’t enough space for this download. Remove a download and try again."; return
            }
        } catch { /* The transfer itself still reports disk-space failures. */ }
        let previous = record(prayer.id)
        let replacing = previous.map { isAvailable($0.prayer) && $0.prayer.audio?.revision != asset.revision } ?? false
        let next = DownloadRecord(prayer: replacing ? previous!.prayer : prayer, pendingPrayer: replacing ? prayer : nil, state: .downloading, progress: 0, taskID: nil, message: nil)
        records.removeAll { $0.id == prayer.id }; records.append(next); persist()
        if source.isFileURL {
            fixtureTasks[prayer.id] = Task { [weak self] in
                guard let self else { return }
                let staged = stagingDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.copyItem(at: source, to: staged)
                    try Task.checkCancellation()
                    await finishFile(staged, itemID: prayer.id, taskID: nil)
                } catch {
                    try? FileManager.default.removeItem(at: staged)
                    if !Task.isCancelled { fail(prayer.id, message: "This recording could not be copied. Please try again.") }
                }
                fixtureTasks[prayer.id] = nil
            }
        } else {
            var request = URLRequest(url: source)
            request.allowsCellularAccess = !wifiOnly
            request.allowsExpensiveNetworkAccess = !wifiOnly
            let task = session.downloadTask(with: request)
            task.taskDescription = prayer.id
            if let index = records.firstIndex(where: { $0.id == prayer.id }) { records[index].taskID = task.taskIdentifier; persist() }
            task.resume()
        }
    }
    func cancel(_ id: String) {
        guard !needsRecovery else { return }
        fixtureTasks[id]?.cancel(); fixtureTasks[id] = nil
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let taskID = records[index].taskID
        if let taskID { session.getAllTasks { tasks in tasks.first { $0.taskIdentifier == taskID }?.cancel() } }
        records[index].taskID = nil
        if records[index].pendingPrayer != nil { records[index].pendingPrayer = nil; records[index].state = .available; records[index].message = "Update cancelled." }
        else { records[index].state = .failed; records[index].message = "Download cancelled. You can try again." }
        persist()
    }
    @discardableResult func remove(_ id: String) -> Bool {
        guard !needsRecovery else { errorMessage = recoveryMessage; return false }
        errorMessage = nil
        cancel(id)
        let old = record(id)
        if let prayer = old?.prayer, let url = fileURL(prayer),
           !records.contains(where: { $0.id != id && $0.prayer.audio?.sha256 == prayer.audio?.sha256 }), FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.removeItem(at: url) }
            catch { errorMessage = "This download could not be removed. Please try again."; return false }
        }
        records.removeAll { $0.id == id }; persist()
        return errorMessage == nil
    }
    @discardableResult func clear() -> Bool {
        if needsRecovery {
            do {
                for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where file.pathExtension == "m4a" { try FileManager.default.removeItem(at: file) }
                try PrivateFiles.write([DownloadRecord](), to: metadataURL)
                records = []; needsRecovery = false; errorMessage = nil
                session.getAllTasks { [weak self] tasks in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let newTasks = Set(records.compactMap(\.taskID))
                        for task in tasks where !newTasks.contains(task.taskIdentifier) { task.cancel() }
                    }
                }
                return true
            } catch { errorMessage = "Downloads could not be reset. Please try again."; return false }
        }
        var success = true
        for id in records.map(\.id) { if !remove(id) { success = false } }
        do {
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where file.pathExtension == "m4a" { try FileManager.default.removeItem(at: file) }
        } catch { success = false }
        if !success { errorMessage = "Some downloaded files could not be removed. Please try again." }
        return success
    }
    func updatePolicy(wifiOnly: Bool) {
        self.wifiOnly = wifiOnly
        let active = records.filter { $0.state == .downloading }.map(\.target)
        for prayer in active { cancel(prayer.id); start(prayer) }
    }
    func reconcileCatalog(_ catalog: Catalog) {
        guard !needsRecovery else { return }
        for id in catalog.withdrawnIDs { remove(id) }
        for record in records where record.state == .available {
            if let updated = catalog.item(record.id), updated.audio?.revision != record.prayer.audio?.revision { start(updated) }
        }
    }
    private func reconcileTransfers() {
        guard !needsRecovery else { return }
        let pending = records.filter { $0.state == .downloading || $0.state == .verifying }
        session.getAllTasks { [weak self] tasks in
            let active = Set(tasks.map(\.taskIdentifier))
            Task { @MainActor [weak self] in
                guard let self, !needsRecovery else { return }
                for index in records.indices where records[index].state == .downloading || records[index].state == .verifying {
                    if pending.contains(where: { $0.id == records[index].id && $0.taskID == records[index].taskID }),
                       fixtureTasks[records[index].id] == nil, pendingVerifications == 0,
                       !active.contains(records[index].taskID ?? -1) {
                        records[index].state = records[index].pendingPrayer == nil ? .failed : .available
                        records[index].pendingPrayer = nil; records[index].taskID = nil
                        records[index].message = "The transfer was interrupted. Please try again."
                    }
                }
                persist()
            }
        }
    }
    private func persist() {
        guard !needsRecovery else { return }
        do { try PrivateFiles.write(records, to: metadataURL) }
        catch { errorMessage = "Download status could not be saved. Please try again." }
    }
    private func fail(_ id: String, message: String, taskID: Int? = nil) {
        guard let index = records.firstIndex(where: { $0.id == id }), taskID == nil || records[index].taskID == taskID else { return }
        records[index].state = records[index].pendingPrayer == nil ? .failed : .available
        records[index].pendingPrayer = nil; records[index].taskID = nil; records[index].message = message; persist()
    }
    private func finishFile(_ staged: URL, itemID: String, taskID: Int?) async {
        pendingVerifications += 1
        defer { pendingVerifications -= 1; try? FileManager.default.removeItem(at: staged); finishBackgroundIfReady() }
        guard let index = records.firstIndex(where: { $0.id == itemID }), records[index].taskID == taskID,
              records[index].state == .downloading, let asset = records[index].target.audio else { return }
        let target = records[index].target
        records[index].state = .verifying; records[index].progress = 1
        do {
            let hash = try await Task.detached(priority: .utility) { try Integrity.fileHash(staged) }.value
            let size = try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard hash == asset.sha256, Int64(size ?? -1) == asset.bytes else { throw URLError(.cannotDecodeContentData) }
            guard let current = records.firstIndex(where: { $0.id == itemID }), records[current].state == .verifying,
                  records[current].taskID == taskID, !Task.isCancelled, let final = fileURL(target) else { return }
            let oldFile = fileURL(records[current].prayer)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: staged.path)
            if FileManager.default.fileExists(atPath: final.path) { _ = try FileManager.default.replaceItemAt(final, withItemAt: staged) }
            else { try FileManager.default.moveItem(at: staged, to: final) }
            records[current].prayer = target; records[current].pendingPrayer = nil; records[current].state = .available
            records[current].progress = 1; records[current].taskID = nil; records[current].message = nil; persist()
            if let oldFile, oldFile != final, !records.contains(where: { fileURL($0.prayer) == oldFile }) { try? FileManager.default.removeItem(at: oldFile) }
        } catch { fail(itemID, message: "This download could not be verified. Please try again.", taskID: taskID) }
    }
    func handleBackgroundEvents(completion: @escaping () -> Void) { backgroundCompletion = completion; finishBackgroundIfReady() }
    private func finishBackgroundIfReady() {
        guard finishedBackgroundEvents, pendingVerifications == 0, let completion = backgroundCompletion else { return }
        backgroundCompletion = nil; finishedBackgroundEvents = false; completion()
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        Task { @MainActor [weak self] in
            guard let self, let index = records.firstIndex(where: { $0.taskID == taskID }) else { return }
            records[index].progress = min(1, max(0, progress))
        }
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier, id = downloadTask.taskDescription ?? ""
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { Task { @MainActor [weak self] in self?.fail(id, message: "The recording could not be downloaded. You can still read its text.", taskID: taskID) }; return }
        let staged = stagingDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: staged)
            Task { @MainActor [weak self] in await self?.finishFile(staged, itemID: id, taskID: taskID) }
        } catch { Task { @MainActor [weak self] in self?.fail(id, message: "The download could not be saved. Check device storage and try again.", taskID: taskID) } }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard error != nil else { return }
        let id = task.taskDescription ?? "", taskID = task.taskIdentifier
        Task { @MainActor [weak self] in self?.fail(id, message: "Connection lost. Try again when you’re connected.", taskID: taskID) }
    }
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor [weak self] in self?.finishedBackgroundEvents = true; self?.finishBackgroundIfReady() }
    }
}
