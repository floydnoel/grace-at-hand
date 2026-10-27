import Foundation
import Testing
@testable import GraceCore

private func fixtureData() throws -> Data {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { root.deleteLastPathComponent() }
    return try Data(contentsOf: root.appendingPathComponent("content/fixtures/catalog.json"))
}
private func fixture() throws -> Catalog { try JSONDecoder().decode(Catalog.self, from: fixtureData()) }

@Test func fixturesMatchTheClientContract() throws {
    let catalog = try fixture(); try catalog.validate()
    #expect(catalog.items.count >= 20)
    #expect(catalog.journeys.first?.itemIDs.count == 7)
    #expect(catalog.items.allSatisfy { $0.audio != nil && !$0.transcript.isEmpty })
}
@Test func unknownSchemaKeepsTheClientFromAcceptingContent() throws {
    var json = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
    json["schemaVersion"] = 2
    let catalog = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(throws: CatalogError.unsupportedVersion) { try catalog.validate() }
}
@Test func duplicateIDsAndMissingTranscriptsAreRejected() throws {
    var json = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
    var items = json["items"] as! [[String: Any]]
    items.append(items[0]); json["items"] = items
    let duplicate = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(throws: (any Error).self) { try duplicate.validate() }
    items.removeLast(); items[0]["transcript"] = [String](); json["items"] = items
    let missing = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(throws: (any Error).self) { try missing.validate() }
}
@Test func localDatesDoNotUseUTCMidnight() throws {
    let date = try #require(ISO8601DateFormatter().date(from: "2026-10-25T02:00:00Z"))
    #expect(LocalDay.key(date, timeZone: TimeZone(identifier: "America/New_York")!) == "2026-10-24")
    #expect(LocalDay.key(date, timeZone: TimeZone(identifier: "Asia/Tokyo")!) == "2026-10-25")
    let catalog = try fixture()
    #expect(catalog.passage(on: date, timeZone: TimeZone(identifier: "America/New_York")!)?.date == "2026-10-24")
    #expect(LocalDay.isValid("2024-02-29"))
    #expect(!LocalDay.isValid("2026-02-29"))
    #expect(!LocalDay.isValid("2026-13-01"))
}
@Test func resumePositionIsTiedToAudioRevision() throws {
    let prayer = try #require(fixture().items.first)
    #expect(ResumeCheckpoint(itemID: prayer.id, assetRevision: prayer.audio!.revision, seconds: 12).position(for: prayer) == 12)
    #expect(ResumeCheckpoint(itemID: prayer.id, assetRevision: "replaced", seconds: 12).position(for: prayer) == 0)
    #expect(ResumeCheckpoint(itemID: prayer.id, assetRevision: prayer.audio!.revision, seconds: -.infinity).position(for: prayer) == 0)
}
@Test func completedRecordingsRestartWhileUnfinishedRecordingsResume() throws {
    let prayer = try #require(fixture().items.first)
    for seconds in [prayer.durationSeconds, prayer.durationSeconds - 0.25, prayer.durationSeconds + 5] {
        #expect(ResumeCheckpoint(itemID: prayer.id, assetRevision: prayer.audio!.revision, seconds: seconds).position(for: prayer) == 0)
    }
    #expect(ResumeCheckpoint(itemID: prayer.id, assetRevision: prayer.audio!.revision, seconds: 8).position(for: prayer) == 8)
}
@Test func unsupportedPrayerLanguagesAreRejected() throws {
    var json = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
    var items = json["items"] as! [[String: Any]]
    for language in ["es", "EN", ""] {
        items[0]["language"] = language; json["items"] = items
        let catalog = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(throws: (any Error).self) { try catalog.validate() }
    }
}
@Test func audienceLabelsDistinguishAdultsFromGeneralAndFamilyPrayer() throws {
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture().items[0])) as! [String: Any]
    for (value, label) in [("adult", "For adults"), ("general", "General audience"), ("family", "Family prayer · children participate with an adult")] {
        json["suitability"] = value
        let prayer = try JSONDecoder().decode(Prayer.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(prayer.suitabilityLabel == label)
    }
}
@Test func featuredPrayerUsesInterestsWithStableTimeOfDayDefaults() throws {
    let prayers = try fixture().items
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 9)))
    let evening = try #require(calendar.date(byAdding: .hour, value: 12, to: morning))
    #expect(PrayerRecommendations.featured(from: prayers, interests: [], availableMinutes: 10, on: morning, calendar: calendar)?.id == "morning-offering")
    #expect(PrayerRecommendations.featured(from: prayers, interests: [], availableMinutes: 10, on: evening, calendar: calendar)?.id == "evening-surrender")
    for (interest, id) in [("Scripture", "lectio-divina"), ("Rosary", "rosary-joyful"), ("Beginner", "begin-with-gratitude"), ("Rest", "evening-surrender")] {
        #expect(PrayerRecommendations.featured(from: prayers, interests: [interest], availableMinutes: 5, on: morning, calendar: calendar)?.id == id)
    }
    #expect(PrayerRecommendations.featured(from: prayers, interests: ["Family"], availableMinutes: 5, on: morning, calendar: calendar)?.suitability == "family")
    #expect(PrayerRecommendations.featured(from: prayers, interests: ["Morning", "Scripture", "Scripture"], availableMinutes: 5, on: morning, calendar: calendar)?.id == "morning-offering")
}
@Test func availableTimeLimitsSuggestionsAndFallsBackToTheShortestPrayer() throws {
    var json = try JSONSerialization.jsonObject(with: fixtureData()) as! [String: Any]
    var items = json["items"] as! [[String: Any]]
    items = Array(items.prefix(2)); items[0]["durationSeconds"] = 720; items[1]["durationSeconds"] = 240; json["items"] = items
    let prayers = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json)).items
    #expect(PrayerRecommendations.featured(from: prayers, interests: ["Morning"], availableMinutes: 5, on: .now)?.id == "our-father")
    #expect(PrayerRecommendations.featured(from: prayers, interests: ["Morning"], availableMinutes: 20, on: .now)?.id == "morning-offering")
    #expect(PrayerRecommendations.featured(from: prayers, interests: ["Morning"], availableMinutes: 1, on: .now)?.id == "our-father")
    #expect(PrayerRecommendations.featured(from: [], interests: [], availableMinutes: 5, on: .now) == nil)
}
@Test func rosaryGuidesHaveFiveCompleteDecades() {
    for set in RosaryMysteries.allCases {
        let steps = RosaryGuide.steps(for: set)
        #expect(steps.filter { $0.bead != nil }.count == 50)
        #expect(Set(steps.compactMap(\.decade)) == Set(1...5))
        #expect(steps.first?.title == "Sign of the Cross")
        #expect(steps.last?.title == "Closing prayer")
    }
}
@Test func mysterySuggestionsFollowTheLocalWeekday() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 12)))
    #expect(RosaryMysteries.suggested(on: monday, calendar: calendar) == .joyful)
    #expect(RosaryMysteries.suggested(on: calendar.date(byAdding: .day, value: 3, to: monday)!, calendar: calendar) == .luminous)
}
@Test func quietHoursHandleMidnightAndBoundaries() {
    #expect(ReminderRules.isQuiet(minute: 1260, start: 1260, end: 420))
    #expect(ReminderRules.isQuiet(minute: 90, start: 1260, end: 420))
    #expect(!ReminderRules.isQuiet(minute: 420, start: 1260, end: 420))
    #expect(!ReminderRules.isQuiet(minute: 120, start: 100, end: 100))
    #expect(ReminderRules.isQuiet(minute: 720, start: 600, end: 900))
}
@Test func snoozeRespectsQuietHoursAcrossDaylightSaving() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 20, minute: 55)))
    let next = try #require(ReminderRules.snoozeDate(after: evening, quietStart: 1260, quietEnd: 420, calendar: calendar))
    #expect(calendar.component(.day, from: next) == 8)
    #expect(calendar.component(.hour, from: next) == 7)
    #expect(next.timeIntervalSince(evening) < 11 * 60 * 60)
}
