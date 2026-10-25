import Foundation
import SwiftData
import Observation
import GraceCore

@Model final class PrayerRecord {
    @Attribute(.unique) var itemID: String
    var favorite = false
    var completed = false
    var position: Double = 0
    var assetRevision = ""
    var lastPlayed: Date?
    init(itemID: String) { self.itemID = itemID }
}
@Model final class PassageRecord {
    @Attribute(.unique) var id: String
    var payload: Data
    var savedAt: Date
    init(passage: Passage, payload: Data) { id = passage.id; self.payload = payload; savedAt = .now }
}
@Model final class Preferences {
    @Attribute(.unique) var id = "local"
    var welcomed = false
    var appearance = "system"
    var readingScale: Double = 1
    var keepHistory = true
    var wifiOnly = true
    var interests: [String] = []
    var availableMinutes = 10
    var quietStart = 21 * 60
    var quietEnd = 7 * 60
    var silenceDeadline: Date?
    var silenceSound = true
    init() {}
}
enum LocalSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [PrayerRecord.self, PassageRecord.self, Preferences.self] }
}
enum LocalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LocalSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum PrivateFiles {
    static func directory(_ name: String, root: URL? = nil, protection: FileProtectionType = .completeUntilFirstUserAuthentication) throws -> URL {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var url = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.protectionKey: protection])
        try FileManager.default.setAttributes([.protectionKey: protection], ofItemAtPath: url.path)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }
    static func write<T: Encodable>(_ value: T, to url: URL, complete: Bool = false) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: complete ? [.atomic, .completeFileProtection] : [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var target = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try target.setResourceValues(values)
    }
}

@MainActor @Observable final class LocalStore {
    let container: ModelContainer
    let context: ModelContext
    let preferences: Preferences
    private(set) var records: [PrayerRecord] = []
    private(set) var passages: [PassageRecord] = []
    var errorMessage: String?

    init(inMemory: Bool = false, root: URL? = nil) throws {
        let folder = try PrivateFiles.directory("LocalPrayer", root: root)
        let schema = Schema(versionedSchema: LocalSchemaV1.self)
        let configuration = inMemory ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) : ModelConfiguration(schema: schema, url: folder.appendingPathComponent("prayer.store"), cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, migrationPlan: LocalMigrationPlan.self, configurations: [configuration])
        context = ModelContext(container)
        if let stored = try context.fetch(FetchDescriptor<Preferences>()).first { preferences = stored }
        else { preferences = Preferences(); context.insert(preferences); try context.save() }
        try refresh()
    }
    private func refresh() throws {
        records = try context.fetch(FetchDescriptor<PrayerRecord>())
        passages = try context.fetch(FetchDescriptor<PassageRecord>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)]))
    }
    func save() {
        do { try context.save(); try refresh(); errorMessage = nil }
        catch { context.rollback(); errorMessage = "Your change could not be saved. Please try again." }
    }
    func record(_ id: String) -> PrayerRecord? { records.first { $0.itemID == id } }
    private func ensureRecord(_ id: String) -> PrayerRecord {
        if let record = record(id) { return record }
        let record = PrayerRecord(itemID: id); context.insert(record); return record
    }
    func isFavorite(_ id: String) -> Bool { record(id)?.favorite == true }
    func toggleFavorite(_ id: String) { let r = ensureRecord(id); r.favorite.toggle(); save() }
    func isSaved(_ passage: Passage) -> Bool { passages.contains { $0.id == passage.id } }
    func togglePassage(_ passage: Passage) {
        if let record = passages.first(where: { $0.id == passage.id }) { context.delete(record); save() }
        else {
            do { context.insert(PassageRecord(passage: passage, payload: try JSONEncoder().encode(passage))); save() }
            catch { errorMessage = "This passage could not be saved." }
        }
    }
    var savedPassages: [Passage] { passages.compactMap { try? JSONDecoder().decode(Passage.self, from: $0.payload) } }
    var recent: [PrayerRecord] { records.filter { $0.lastPlayed != nil }.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) } }
    func checkpoint(for prayer: Prayer) -> Double {
        guard let record = record(prayer.id) else { return 0 }
        return ResumeCheckpoint(itemID: prayer.id, assetRevision: record.assetRevision, seconds: record.position).position(for: prayer)
    }
    func savePlayback(_ prayer: Prayer, seconds: Double, completed: Bool = false) {
        guard preferences.keepHistory, seconds.isFinite else { return }
        let record = ensureRecord(prayer.id)
        record.position = max(0, seconds); record.assetRevision = prayer.audio?.revision ?? ""
        record.lastPlayed = .now
        if completed { record.completed = true }
        save()
    }
    func markComplete(_ prayer: Prayer) { let r = ensureRecord(prayer.id); r.completed.toggle(); save() }
    func clearHistory() {
        for record in records { record.position = 0; record.lastPlayed = nil; record.completed = false; record.assetRevision = "" }
        save()
    }
    func removeHistory(_ id: String) {
        guard let r = record(id) else { return }
        r.lastPlayed = nil; r.position = 0; r.completed = false; save()
    }
    func reset() {
        for record in records { context.delete(record) }
        for record in passages { context.delete(record) }
        preferences.welcomed = false; preferences.appearance = "system"; preferences.readingScale = 1
        preferences.keepHistory = true; preferences.wifiOnly = true; preferences.interests = []; preferences.availableMinutes = 10
        preferences.quietStart = 1260; preferences.quietEnd = 420; preferences.silenceDeadline = nil; preferences.silenceSound = true
        save()
    }
}
