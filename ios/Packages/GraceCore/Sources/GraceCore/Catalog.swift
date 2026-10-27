import Foundation

public struct Catalog: Codable, Sendable {
    public let schemaVersion: Int
    public let revision: String
    public let publishedAt: String
    public let isFixture: Bool
    public let items: [Prayer]
    public let collections: [PrayerCollection]
    public let journeys: [Journey]
    public let passages: [Passage]
    public let calendar: [CalendarEntry]
    public let withdrawnIDs: [String]

    public func item(_ id: String) -> Prayer? { items.first { $0.id == id } }
    public func passage(on date: Date, timeZone: TimeZone = .current) -> Passage? {
        let key = LocalDay.key(date, timeZone: timeZone)
        return passages.first { $0.date == key }
    }
    public func calendarEntry(on date: Date, timeZone: TimeZone = .current) -> CalendarEntry? {
        let key = LocalDay.key(date, timeZone: timeZone)
        return calendar.first { $0.date == key }
    }
    public func validate() throws {
        guard schemaVersion == 1 else { throw CatalogError.unsupportedVersion }
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard !revision.isEmpty, publishedAt.hasSuffix("Z"),
              timestamp.date(from: publishedAt) != nil || ISO8601DateFormatter().date(from: publishedAt) != nil else { throw CatalogError.invalid("Invalid publication metadata") }
        guard !items.isEmpty, Set(items.map(\.id)).count == items.count,
              Set(collections.map(\.id)).count == collections.count,
              Set(journeys.map(\.id)).count == journeys.count,
              Set(passages.map(\.id)).count == passages.count,
              Set(passages.map(\.date)).count == passages.count,
              Set(calendar.map(\.date)).count == calendar.count else { throw CatalogError.invalid("Duplicate identifiers or empty library") }
        let ids = Set(items.map(\.id))
        for item in items {
            guard !item.id.isEmpty, !item.title.isEmpty, !item.text.isEmpty, !item.credits.isEmpty,
                  item.language == "en", item.revision > 0, ["Pray", "Reflect", "Rest", "Learn"].contains(item.category),
                  ["general", "family", "adult"].contains(item.suitability), item.durationSeconds.isFinite, item.durationSeconds > 0 else { throw CatalogError.invalid("Incomplete prayer") }
            if let asset = item.audio {
                guard asset.bytes > 0, asset.mimeType == "audio/mp4", !asset.revision.isEmpty,
                      asset.sha256.count == 64, asset.sha256.allSatisfy({ "0123456789abcdef".contains($0) }), !item.transcript.isEmpty,
                      asset.url.hasPrefix("bundle:") || URL(string: asset.url)?.scheme == "https" || asset.url.hasPrefix("media/") else {
                    throw CatalogError.invalid("Invalid media asset")
                }
                if !isFixture && asset.url != "media/\(asset.sha256).m4a" { throw CatalogError.invalid("Production media must be immutable") }
            }
            var end = 0.0
            for cue in item.cues ?? [] {
                guard cue.start >= end, cue.end > cue.start, cue.end <= item.durationSeconds + 0.1,
                      item.transcript.indices.contains(cue.paragraph) else { throw CatalogError.invalid("Invalid transcript cue") }
                end = cue.end
            }
            end = 0
            for cue in item.rosaryCues ?? [] {
                guard let set = item.rosarySet.flatMap(RosaryMysteries.init(rawValue:)), RosaryGuide.steps(for: set).indices.contains(cue.step),
                      cue.start >= end, cue.end > cue.start, cue.end <= item.durationSeconds + 0.1 else { throw CatalogError.invalid("Invalid Rosary cue") }
                end = cue.end
            }
        }
        for collection in collections {
            guard !collection.id.isEmpty, collection.revision > 0, collection.language == "en", !collection.title.isEmpty,
                  Set(collection.itemIDs).count == collection.itemIDs.count, collection.itemIDs.allSatisfy(ids.contains) else { throw CatalogError.invalid("Unknown collection item") }
        }
        for journey in journeys {
            guard !journey.id.isEmpty, journey.revision > 0, journey.language == "en", !journey.title.isEmpty,
                  journey.itemIDs.count == 7, Set(journey.itemIDs).count == 7, journey.itemIDs.allSatisfy(ids.contains) else { throw CatalogError.invalid("Invalid beginner journey") }
        }
        for passage in passages {
            guard !passage.id.isEmpty, passage.revision > 0, passage.language == "en", LocalDay.isValid(passage.date), !passage.verses.isEmpty, !passage.translation.isEmpty,
                  !passage.credit.isEmpty, passage.audioItemID.map(ids.contains) ?? true,
                  passage.verseNumbers.map({ $0.count == passage.verses.count && $0.allSatisfy { !$0.isEmpty } }) ?? true else { throw CatalogError.invalid("Invalid passage") }
        }
        guard calendar.allSatisfy({ LocalDay.isValid($0.date) && $0.id == "calendar:\($0.date)" && $0.revision > 0 && $0.language == "en" && $0.region == "US" && $0.rite == "roman" }),
              Set(withdrawnIDs).count == withdrawnIDs.count, withdrawnIDs.allSatisfy({ !ids.contains($0) }) else { throw CatalogError.invalid("Invalid calendar or withdrawal") }
    }
}

public enum CatalogError: Error, LocalizedError, Equatable {
    case unsupportedVersion
    case invalid(String)
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This library needs a newer app. Your saved library is still available."
        case .invalid: "The new library could not be verified. Your saved library is still available."
        }
    }
}

public struct Prayer: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let revision: Int
    public let title: String
    public let subtitle: String
    public let category: String
    public let topics: [String]
    public let language: String
    public let suitability: String
    public let durationSeconds: Double
    public let text: [String]
    public let transcript: [String]
    public let credits: [String]
    public let artwork: String
    public let symbol: String
    public let howTo: String
    public let audio: MediaAsset?
    public let cues: [TranscriptCue]?
    public let rosarySet: String?
    public let rosaryCues: [RosaryCue]?
    public var durationLabel: String {
        durationSeconds < 60 ? "\(Int(durationSeconds.rounded())) sec" : "\(Int(ceil(durationSeconds / 60))) min"
    }
    public var suitabilityLabel: String {
        switch suitability {
        case "family": "Family prayer · children participate with an adult"
        case "general": "General audience"
        case "adult": "For adults"
        default: "Audience information unavailable"
        }
    }
}

public struct MediaAsset: Codable, Hashable, Sendable {
    public let revision: String
    public let url: String
    public let bytes: Int64
    public let sha256: String
    public let mimeType: String
}
public struct TranscriptCue: Codable, Hashable, Sendable {
    public let paragraph: Int
    public let start: Double
    public let end: Double
}
public struct RosaryCue: Codable, Hashable, Sendable {
    public let step: Int
    public let start: Double
    public let end: Double
}
public struct PrayerCollection: Codable, Identifiable, Sendable {
    public let id: String
    public let revision: Int
    public let language: String
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let itemIDs: [String]
}
public struct Journey: Codable, Identifiable, Sendable {
    public let id: String
    public let revision: Int
    public let language: String
    public let title: String
    public let subtitle: String
    public let itemIDs: [String]
}
public struct Passage: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let revision: Int
    public let language: String
    public let date: String
    public let title: String
    public let reference: String
    public let translation: String
    public let numberingNote: String?
    public let verses: [String]
    public let verseNumbers: [String]?
    public let credit: String
    public let reflection: String
    public let audioItemID: String?
}
public struct CalendarEntry: Codable, Sendable {
    public let id: String
    public let revision: Int
    public let language: String
    public let date: String
    public let region: String
    public let rite: String
    public let season: String
    public let observance: String
}
public struct CatalogPointer: Codable, Sendable {
    public let schemaVersion: Int
    public let generation: Int64
    public let catalogURL: String
    public let sha256: String
}

public enum LocalDay {
    public static func key(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    public static func isValid(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}
