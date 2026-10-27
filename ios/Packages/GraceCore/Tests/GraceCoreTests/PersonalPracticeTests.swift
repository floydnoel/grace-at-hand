import Foundation
import Testing
@testable import GraceCore

private func easternCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!; return calendar
}
private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

@Test func weeklyGoalsCountDistinctLocalDaysAndRespectPeriodAcrossDST() {
    let calendar = easternCalendar()
    let dates = ["2026-10-26T12:00:00Z", "2026-10-26T13:00:00Z", "2026-11-01T13:00:00Z", "2026-11-02T13:00:00Z"]
    var sessions = dates.map { PracticeSession(date: instant($0), title: "Synthetic prayer", durationSeconds: 300, source: .manual, calendar: calendar) }
    sessions.append(PracticeSession(date: instant("2026-10-27T23:00:00Z"), title: "Synthetic evening", durationSeconds: 300, source: .reading, calendar: calendar))
    let goal = PrayerGoal(title: "Three mornings", period: .morning)
    #expect(PracticeRules.progress(for: goal, sessions: sessions, on: instant("2026-11-01T18:00:00Z"), calendar: calendar) == 2)
    #expect(PracticeRules.weekDays(containing: instant("2026-11-01T18:00:00Z"), calendar: calendar) == ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
}

@Test func recordedDayAndPeriodDoNotChangeWhenTraveling() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
    let session = PracticeSession(date: instant("2026-10-28T08:00:00Z"), title: "Synthetic evening", durationSeconds: 60, source: .manual, calendar: calendar)
    let reopened = try JSONDecoder().decode(PracticeSession.self, from: JSONEncoder().encode(session))
    #expect(reopened.day == "2026-10-27"); #expect(reopened.period == .evening)
}

@Test func streakAllowsTodayToRemainOpenAndIncludesBackfilledPrayer() {
    let calendar = easternCalendar(), today = instant("2026-11-02T17:00:00Z")
    var sessions = ["2026-10-31T12:00:00Z", "2026-11-01T13:00:00Z"].map { PracticeSession(date: instant($0), title: "Synthetic prayer", durationSeconds: 60, source: .manual, calendar: calendar) }
    #expect(PracticeRules.streak(sessions: sessions, on: today, calendar: calendar) == 2)
    sessions.append(PracticeSession(date: today, title: "Synthetic prayer", durationSeconds: 60, source: .manual, calendar: calendar))
    #expect(PracticeRules.streak(sessions: sessions, on: today, calendar: calendar) == 3)
    #expect(PracticeRules.streak(sessions: [], on: today, calendar: calendar) == 0)
}

@Test func routinesUseChosenWeekdaysAndCanBePaused() {
    let calendar = easternCalendar()
    var routine = PrayerRoutine(title: "Synthetic morning", weekdays: [2], prayerIDs: ["our-father", "hail-mary"])
    #expect(routine.isScheduled(on: instant("2026-10-26T12:00:00Z"), calendar: calendar))
    #expect(!routine.isScheduled(on: instant("2026-10-27T12:00:00Z"), calendar: calendar))
    routine.enabled = false
    #expect(!routine.isScheduled(on: instant("2026-10-26T12:00:00Z"), calendar: calendar))
}

@Test func originalIntentionFilesDecodeWithoutLosingWriting() throws {
    let original = Data(#"{"id":"0A281865-1AD1-4B5B-A47E-3E9C9F5C8746","title":"Synthetic hope","note":"Original synthetic writing","createdAt":800000000}"#.utf8)
    let value = try JSONDecoder().decode(PrayerIntention.self, from: original)
    #expect(value.title == "Synthetic hope"); #expect(value.note == "Original synthetic writing")
    #expect(value.status == .active); #expect(value.tags.isEmpty); #expect(value.updates.isEmpty); #expect(value.followUpDate == nil)
    #expect(try JSONDecoder().decode(PrayerIntention.self, from: JSONEncoder().encode(value)) == value)
}

@Test func practiceRejectsFutureVersionsInvalidGoalsAndDuplicateEvents() throws {
    var data = PracticeDocument(); data.schemaVersion = 2
    #expect(throws: PracticeError.self) { try data.validate() }
    data = PracticeDocument(); data.goals = [PrayerGoal(title: "Invalid", daysPerWeek: 8)]
    #expect(throws: PracticeError.self) { try data.validate() }
    data = PracticeDocument()
    let session = PracticeSession(title: "Synthetic prayer", durationSeconds: 1, source: .audio, sourceID: "same-event")
    data.sessions = [session, session]
    #expect(throws: PracticeError.self) { try data.validate() }
}

@Test func searchTagsAndReadableExportsRetainPrivateWritingAndLinks() {
    let tags = PracticeRules.tags(" Family, family, gratitude, , GRATITUDE ")
    #expect(tags == ["Family", "gratitude"])
    let entry = JournalEntry(title: "Synthetic reflection", body: "First line\nSecond line", kind: .gratitude, tags: tags, link: JournalLink(kind: .passage, id: "synthetic-passage", title: "Synthetic passage"))
    #expect(entry.matches("family second")); #expect(!entry.matches("missing"))
    let export = PracticeRules.journalExport([entry])
    #expect(export.contains("First line\nSecond line")); #expect(export.contains("Connected to: Synthetic passage"))
    let intention = PrayerIntention(title: "Synthetic hope", note: "Synthetic note", tags: tags, status: .answered, updates: [.init(text: "Synthetic update")])
    #expect(intention.matches("gratitude update")); #expect(IntentionExport.text([intention]).contains("Synthetic update"))
    #expect(!PracticeDocument().showStreaks)
}
