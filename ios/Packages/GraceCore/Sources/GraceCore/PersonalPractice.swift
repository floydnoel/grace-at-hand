import Foundation

public enum PrayerPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case anytime, morning, midday, evening
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public static func at(_ date: Date, calendar: Calendar = .current) -> Self {
        switch calendar.component(.hour, from: date) {
        case 5..<12: .morning
        case 12..<17: .midday
        default: .evening
        }
    }
}

public struct PrayerRoutine: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var period: PrayerPeriod
    public var weekdays: [Int]
    public var prayerIDs: [String]
    public var enabled: Bool
    public init(id: UUID = UUID(), title: String, period: PrayerPeriod = .morning, weekdays: [Int] = [2, 3, 4, 5, 6], prayerIDs: [String] = [], enabled: Bool = true) {
        self.id = id; self.title = title; self.period = period; self.weekdays = weekdays; self.prayerIDs = prayerIDs; self.enabled = enabled
    }
    public func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        enabled && weekdays.contains(calendar.component(.weekday, from: date))
    }
}

public struct PrayerGoal: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var daysPerWeek: Int
    public var period: PrayerPeriod
    public var enabled: Bool
    public init(id: UUID = UUID(), title: String, daysPerWeek: Int = 3, period: PrayerPeriod = .anytime, enabled: Bool = true) {
        self.id = id; self.title = title; self.daysPerWeek = daysPerWeek; self.period = period; self.enabled = enabled
    }
}

public enum PracticeSource: String, Codable, Sendable { case audio, reading, silence, manual, routine }

public struct PracticeSession: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    /// Retain the day and time of day where prayer happened, including after travel.
    public var day: String
    public var period: PrayerPeriod
    public var title: String
    public var durationSeconds: Double
    public var source: PracticeSource
    public var sourceID: String
    public var prayerID: String?
    public var routineID: UUID?
    public init(id: UUID = UUID(), date: Date = .now, title: String, durationSeconds: Double, source: PracticeSource, sourceID: String = UUID().uuidString, prayerID: String? = nil, routineID: UUID? = nil, calendar: Calendar = .current) {
        self.id = id; self.date = date; day = LocalDay.key(date, timeZone: calendar.timeZone)
        period = .at(date, calendar: calendar); self.title = title; self.durationSeconds = durationSeconds
        self.source = source; self.sourceID = sourceID; self.prayerID = prayerID; self.routineID = routineID
    }
}

public enum JournalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case reflection, gratitude, writing
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}
public struct JournalLink: Codable, Equatable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case prayer, passage, session }
    public var kind: Kind
    public var id: String
    public var title: String
    public init(kind: Kind, id: String, title: String) { self.kind = kind; self.id = id; self.title = title }
}
public struct JournalEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var title: String
    public var body: String
    public var kind: JournalKind
    public var tags: [String]
    public var link: JournalLink?
    public init(id: UUID = UUID(), date: Date = .now, title: String, body: String, kind: JournalKind = .writing, tags: [String] = [], link: JournalLink? = nil) {
        self.id = id; self.date = date; self.title = title; self.body = body; self.kind = kind; self.tags = tags; self.link = link
    }
    public func matches(_ query: String) -> Bool {
        PracticeRules.matches(query, in: [title, body, kind.title, link?.title ?? ""] + tags)
    }
}

public struct PracticeDocument: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var routines: [PrayerRoutine] = []
    public var goals: [PrayerGoal] = []
    public var sessions: [PracticeSession] = []
    public var journal: [JournalEntry] = []
    public var journalDrafts: [JournalEntry] = []
    public var showStreaks = false
    public var showProgress = true
    public var silenceSession: PracticeSession?
    public init() {}
    private enum CodingKeys: String, CodingKey { case schemaVersion, routines, goals, sessions, journal, journalDrafts, showStreaks, showProgress, silenceSession }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        routines = try values.decode([PrayerRoutine].self, forKey: .routines)
        goals = try values.decode([PrayerGoal].self, forKey: .goals)
        sessions = try values.decode([PracticeSession].self, forKey: .sessions)
        journal = try values.decode([JournalEntry].self, forKey: .journal)
        journalDrafts = try values.decodeIfPresent([JournalEntry].self, forKey: .journalDrafts) ?? []
        showStreaks = try values.decode(Bool.self, forKey: .showStreaks)
        showProgress = try values.decodeIfPresent(Bool.self, forKey: .showProgress) ?? true
        silenceSession = try values.decodeIfPresent(PracticeSession.self, forKey: .silenceSession)
    }
    public func validate() throws {
        guard schemaVersion == 1 else { throw PracticeError.invalid }
        func unique<T: Identifiable>(_ values: [T]) -> Bool where T.ID: Hashable { Set(values.map(\.id)).count == values.count }
        guard unique(routines), unique(goals), unique(sessions), unique(journal), unique(journalDrafts),
              Set(sessions.map(\.sourceID)).count == sessions.count,
              routines.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.weekdays.isEmpty && $0.weekdays.allSatisfy { (1...7).contains($0) } && !$0.prayerIDs.isEmpty && Set($0.prayerIDs).count == $0.prayerIDs.count }),
              goals.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...7).contains($0.daysPerWeek) }),
              sessions.allSatisfy({ LocalDay.isValid($0.day) && !$0.title.isEmpty && !$0.sourceID.isEmpty && $0.durationSeconds.isFinite && $0.durationSeconds >= 0 && $0.durationSeconds <= 86_400 }),
              (journal + journalDrafts).allSatisfy({ !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw PracticeError.invalid }
    }
    public var journalWithDrafts: [JournalEntry] {
        let draftIDs = Set(journalDrafts.map(\.id))
        return journal.filter { !draftIDs.contains($0.id) } + journalDrafts
    }
}
public enum PracticeError: Error { case invalid }

public enum PracticeRules {
    public static func tags(_ input: String) -> [String] {
        var seen = Set<String>()
        return input.split(separator: ",").compactMap {
            let tag = String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
            guard !tag.isEmpty, seen.insert(tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))).inserted else { return nil }
            return tag
        }.prefix(20).map { $0 }
    }
    public static func matches(_ query: String, in values: [String]) -> Bool {
        let haystack = values.joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { haystack.localizedStandardContains(String($0)) }
    }
    /// Monday–Sunday is explicit rather than changing when device region changes.
    public static func weekDays(containing date: Date, calendar: Calendar = .current) -> [String] {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offset, to: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }.map { LocalDay.key($0, timeZone: calendar.timeZone) }
    }
    public static func progress(for goal: PrayerGoal, sessions: [PracticeSession], on date: Date = .now, calendar: Calendar = .current) -> Int {
        let week = Set(weekDays(containing: date, calendar: calendar))
        return Set(sessions.filter { week.contains($0.day) && (goal.period == .anytime || goal.period == $0.period) }.map(\.day)).count
    }
    public static func streak(sessions: [PracticeSession], on date: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(sessions.map(\.day))
        var cursor = calendar.startOfDay(for: date)
        if !days.contains(LocalDay.key(cursor, timeZone: calendar.timeZone)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(LocalDay.key(cursor, timeZone: calendar.timeZone)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
    public static func journalExport(_ entries: [JournalEntry]) -> String {
        (["Grace at Hand · Private journal", "Dates include the time zone. This export contains private writing."] + entries.sorted { $0.date < $1.date }.map { entry in
            ["\n---", entry.title.isEmpty ? entry.kind.title : entry.title, ISO8601DateFormatter().string(from: entry.date), entry.kind.title,
             entry.tags.isEmpty ? nil : "Tags: \(entry.tags.joined(separator: ", "))", entry.link.map { "Connected to: \($0.title)" }, "", entry.body].compactMap { $0 }.joined(separator: "\n")
        }).joined(separator: "\n\n")
    }
}
