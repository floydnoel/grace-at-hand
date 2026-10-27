import Foundation

public enum IntentionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active, answered, archived
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}
public struct IntentionUpdate: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var date: Date
    public var text: String
    public init(id: UUID = UUID(), date: Date = .now, text: String) { self.id = id; self.date = date; self.text = text }
}
public struct PrayerIntention: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var note: String
    public let createdAt: Date
    public var tags: [String]
    public var status: IntentionStatus
    public var followUpDate: Date?
    public var updates: [IntentionUpdate]
    public init(id: UUID = UUID(), title: String, note: String, createdAt: Date = .now, tags: [String] = [], status: IntentionStatus = .active, followUpDate: Date? = nil, updates: [IntentionUpdate] = []) {
        self.id = id; self.title = title; self.note = note; self.createdAt = createdAt
        self.tags = tags; self.status = status; self.followUpDate = followUpDate; self.updates = updates
    }
    private enum CodingKeys: String, CodingKey { case id, title, note, createdAt, tags, status, followUpDate, updates }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id); title = try values.decode(String.self, forKey: .title)
        note = try values.decode(String.self, forKey: .note); createdAt = try values.decode(Date.self, forKey: .createdAt)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        status = try values.decodeIfPresent(IntentionStatus.self, forKey: .status) ?? .active
        followUpDate = try values.decodeIfPresent(Date.self, forKey: .followUpDate)
        updates = try values.decodeIfPresent([IntentionUpdate].self, forKey: .updates) ?? []
    }
    public func matches(_ query: String) -> Bool { PracticeRules.matches(query, in: [title, note, status.title] + tags + updates.map(\.text)) }
}
public enum IntentionExport {
    public static func text(_ entries: [PrayerIntention]) -> String {
        (["Grace at Hand · Private intentions", "This export contains private writing."] + entries.map { entry in
            (["\n---", entry.title, entry.status.title, ISO8601DateFormatter().string(from: entry.createdAt),
              entry.tags.isEmpty ? nil : "Tags: \(entry.tags.joined(separator: ", "))", entry.followUpDate.map { "Follow-up: \(ISO8601DateFormatter().string(from: $0))" }, "", entry.note].compactMap { $0 } + entry.updates.sorted { $0.date < $1.date }.map { "\n\(ISO8601DateFormatter().string(from: $0.date))\n\($0.text)" }).joined(separator: "\n")
        }).joined(separator: "\n\n")
    }
}
