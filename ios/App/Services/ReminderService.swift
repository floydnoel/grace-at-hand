import Foundation
import Observation
@preconcurrency import UserNotifications
import GraceCore

struct PrayerReminder: Codable, Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var weekdays: [Int]
    var prayerID: String
    var enabled: Bool
}
extension Notification.Name { static let graceOpenPrayer = Notification.Name("GraceOpenPrayer") }

@MainActor @Observable final class ReminderService: NSObject {
    private(set) var reminders: [PrayerReminder] = []
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    var errorMessage: String?
    var quietStart = 1260
    var quietEnd = 420
    private let file: URL
    private let center = UNUserNotificationCenter.current()
    init(root: URL? = nil) throws {
        file = try PrivateFiles.directory("Reminders", root: root).appendingPathComponent("reminders.json")
        super.init()
        if let data = try? Data(contentsOf: file) {
            do { reminders = try JSONDecoder().decode([PrayerReminder].self, from: data) }
            catch { errorMessage = "Saved reminders could not be opened." }
        }
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(identifier: "PRAYER", actions: [UNNotificationAction(identifier: "SNOOZE", title: "Remind me in 10 minutes", options: [])], intentIdentifiers: [])])
    }
    func refreshAuthorization() async { authorization = await center.notificationSettings().authorizationStatus }
    var allowed: Bool { [.authorized, .provisional, .ephemeral].contains(authorization) }
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorization(); return granted
        } catch { errorMessage = "Notification permission could not be requested."; return false }
    }
    func save(_ reminder: PrayerReminder) async -> Bool {
        guard !reminder.weekdays.isEmpty, reminder.weekdays.allSatisfy({ (1...7).contains($0) }), (0...23).contains(reminder.hour), (0...59).contains(reminder.minute) else { errorMessage = "Choose a time and at least one day."; return false }
        guard reminders.count < 7 || reminders.contains(where: { $0.id == reminder.id }) else { errorMessage = "You can keep up to seven reminders. Edit an existing reminder to make more room."; return false }
        guard !reminder.enabled || !ReminderRules.isQuiet(minute: reminder.hour * 60 + reminder.minute, start: quietStart, end: quietEnd) else { errorMessage = "Choose a time outside your quiet hours."; return false }
        if reminder.enabled {
            if !(await requestPermission()) { errorMessage = "Reminders are off. You can enable them in Settings."; return false }
        }
        let previous = reminders
        reminders.removeAll { $0.id == reminder.id }; reminders.append(reminder)
        do {
            try PrivateFiles.write(reminders, to: file)
            try await schedule(reminder); errorMessage = nil; return true
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: identifiers(reminder.id))
            reminders = previous; try? PrivateFiles.write(previous, to: file)
            if let old = previous.first(where: { $0.id == reminder.id }) { try? await schedule(old) }
            errorMessage = "This reminder could not be saved. Please try again."; return false
        }
    }
    private func identifiers(_ id: UUID) -> [String] { (1...7).map { "reminder.\(id.uuidString).\($0)" } + ["reminder.\(id.uuidString).snooze"] }
    private func schedule(_ reminder: PrayerReminder) async throws {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(reminder.id))
        guard reminder.enabled, !ReminderRules.isQuiet(minute: reminder.hour * 60 + reminder.minute, start: quietStart, end: quietEnd) else { return }
        for weekday in Set(reminder.weekdays) {
            let content = notificationContent(reminder)
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute, weekday: weekday), repeats: true)
            let request = UNNotificationRequest(identifier: "reminder.\(reminder.id.uuidString).\(weekday)", content: content, trigger: trigger)
            try await center.add(request)
        }
    }
    private func notificationContent(_ reminder: PrayerReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Grace at Hand"; content.body = "A moment for prayer, when you’re ready."
        content.sound = .default; content.categoryIdentifier = "PRAYER"
        content.userInfo = ["reminderID": reminder.id.uuidString, "prayerID": reminder.prayerID]
        return content
    }
    func delete(_ id: UUID) {
        let previous = reminders; reminders.removeAll { $0.id == id }
        do { try PrivateFiles.write(reminders, to: file); center.removePendingNotificationRequests(withIdentifiers: identifiers(id)); center.removeDeliveredNotifications(withIdentifiers: identifiers(id)) }
        catch { reminders = previous; errorMessage = "This reminder could not be deleted." }
    }
    func reschedule() async {
        for reminder in reminders { do { try await schedule(reminder) } catch { errorMessage = "Some reminders could not be updated." } }
    }
    @discardableResult func clear() -> Bool { for id in reminders.map(\.id) { delete(id) }; cancelSilence(); return reminders.isEmpty }
    func scheduleSilence(at deadline: Date, sound: Bool) async {
        guard allowed else { return }
        let content = UNMutableNotificationContent(); content.title = "Your quiet moment"; content.body = "Take a gentle breath and return when you’re ready."
        content.sound = sound ? .default : nil
        do { try await center.add(UNNotificationRequest(identifier: "silence", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false))) }
        catch { errorMessage = "The completion notification could not be scheduled." }
    }
    func cancelSilence() { center.removePendingNotificationRequests(withIdentifiers: ["silence"]); center.removeDeliveredNotifications(withIdentifiers: ["silence"]) }
    private func snooze(_ id: UUID) async {
        guard let reminder = reminders.first(where: { $0.id == id }), reminder.enabled,
              let date = ReminderRules.snoozeDate(after: .now, quietStart: quietStart, quietEnd: quietEnd) else { return }
        try? await center.add(UNNotificationRequest(identifier: "reminder.\(id.uuidString).snooze", content: notificationContent(reminder), trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)))
    }
}
extension ReminderService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let id = response.notification.request.content.userInfo["reminderID"] as? String
        let prayerID = response.notification.request.content.userInfo["prayerID"] as? String
        if action == "SNOOZE", let id, let uuid = UUID(uuidString: id) { await snooze(uuid) }
        else if action == UNNotificationDefaultActionIdentifier, let prayerID {
            await MainActor.run { NotificationCenter.default.post(name: .graceOpenPrayer, object: prayerID) }
        }
    }
}
