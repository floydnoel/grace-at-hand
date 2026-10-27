import Foundation

public enum RosaryMysteries: String, CaseIterable, Identifiable, Sendable {
    case joyful, sorrowful, glorious, luminous
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized + " Mysteries" }
    public var mysteries: [String] {
        switch self {
        case .joyful: ["The Annunciation", "The Visitation", "The Nativity", "The Presentation", "Finding Jesus in the Temple"]
        case .sorrowful: ["The Agony in the Garden", "The Scourging at the Pillar", "The Crowning with Thorns", "The Carrying of the Cross", "The Crucifixion"]
        case .glorious: ["The Resurrection", "The Ascension", "The Descent of the Holy Spirit", "The Assumption", "The Coronation of Mary"]
        case .luminous: ["The Baptism in the Jordan", "The Wedding at Cana", "The Proclamation of the Kingdom", "The Transfiguration", "The Institution of the Eucharist"]
        }
    }
    public static func suggested(on date: Date, calendar: Calendar = .current) -> Self {
        switch calendar.component(.weekday, from: date) {
        case 2, 7: .joyful
        case 3, 6: .sorrowful
        case 5: .luminous
        default: .glorious
        }
    }
}

public struct RosaryStep: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let text: String
    public let decade: Int?
    public let bead: Int?
}

public enum TraditionalPrayer {
    public static let ourFather = "Our Father, who art in heaven, hallowed be thy name; thy kingdom come; thy will be done on earth as it is in heaven. Give us this day our daily bread; and forgive us our trespasses as we forgive those who trespass against us; and lead us not into temptation, but deliver us from evil. Amen."
    public static let hailMary = "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
    public static let gloryBe = "Glory be to the Father, and to the Son, and to the Holy Spirit. As it was in the beginning, is now, and ever shall be, world without end. Amen."
    public static let creed = "I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, his only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, suffered under Pontius Pilate, was crucified, died and was buried; he descended into hell; on the third day he rose again from the dead; he ascended into heaven, and is seated at the right hand of God the Father almighty; from there he will come to judge the living and the dead. I believe in the Holy Spirit, the holy catholic Church, the communion of saints, the forgiveness of sins, the resurrection of the body, and life everlasting. Amen."
    public static let hailHolyQueen = "Hail, holy Queen, Mother of mercy, our life, our sweetness and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious advocate, thine eyes of mercy toward us; and after this our exile show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary."
}

public enum RosaryGuide {
    public static func steps(for set: RosaryMysteries) -> [RosaryStep] {
        var result: [RosaryStep] = []
        func add(_ title: String, _ text: String, decade: Int? = nil, bead: Int? = nil) {
            result.append(.init(id: result.count, title: title, text: text, decade: decade, bead: bead))
        }
        add("Sign of the Cross", "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.")
        add("Apostles’ Creed", TraditionalPrayer.creed)
        add("Our Father", TraditionalPrayer.ourFather)
        for virtue in ["faith", "hope", "charity"] { add("For \(virtue)", TraditionalPrayer.hailMary) }
        add("Glory Be", TraditionalPrayer.gloryBe)
        for (index, mystery) in set.mysteries.enumerated() {
            add(mystery, "Pause to reflect on this mystery.\n\n" + TraditionalPrayer.ourFather, decade: index + 1)
            for bead in 1...10 { add(mystery, TraditionalPrayer.hailMary, decade: index + 1, bead: bead) }
            add("Glory Be", TraditionalPrayer.gloryBe, decade: index + 1)
        }
        add("Hail, Holy Queen", TraditionalPrayer.hailHolyQueen)
        add("Closing prayer", "Pray for us, O holy Mother of God, that we may be made worthy of the promises of Christ.\n\nIn the name of the Father, and of the Son, and of the Holy Spirit. Amen.")
        return result
    }
}

public enum ReminderRules {
    /// A start-inclusive, end-exclusive quiet interval. Equal endpoints disable it.
    public static func isQuiet(minute: Int, start: Int, end: Int) -> Bool {
        guard start != end else { return false }
        return start < end ? (start..<end).contains(minute) : minute >= start || minute < end
    }
    public static func snoozeDate(after date: Date, minutes: Int = 10, quietStart: Int, quietEnd: Int, calendar: Calendar = .current) -> Date? {
        guard let proposed = calendar.date(byAdding: .minute, value: minutes, to: date) else { return nil }
        let minute = calendar.component(.hour, from: proposed) * 60 + calendar.component(.minute, from: proposed)
        if !isQuiet(minute: minute, start: quietStart, end: quietEnd) { return proposed }
        return calendar.nextDate(after: proposed, matching: DateComponents(hour: quietEnd / 60, minute: quietEnd % 60), matchingPolicy: .nextTime)
    }
}

public struct ResumeCheckpoint: Codable, Sendable, Equatable {
    public let itemID: String
    public let assetRevision: String
    public let seconds: Double
    public init(itemID: String, assetRevision: String, seconds: Double) {
        self.itemID = itemID; self.assetRevision = assetRevision; self.seconds = seconds
    }
    public func position(for item: Prayer) -> Double {
        guard item.id == itemID, item.audio?.revision == assetRevision, seconds.isFinite else { return 0 }
        guard seconds < item.durationSeconds - 0.5 else { return 0 }
        return min(max(0, seconds), max(0, item.durationSeconds - 1))
    }
}

public enum PrayerRecommendations {
    public static func featured(from prayers: [Prayer], interests: [String], availableMinutes: Int, on date: Date, calendar: Calendar = .current) -> Prayer? {
        let fitting = prayers.filter { $0.durationSeconds <= Double(max(1, availableMinutes)) * 60 }
        guard !fitting.isEmpty else { return prayers.min { $0.durationSeconds < $1.durationSeconds } }
        let interests = Set(interests.map { $0.lowercased() })
        let hour = calendar.component(.hour, from: date)
        let usualID = hour >= 18 || hour < 5 ? "evening-surrender" : "morning-offering"
        func score(_ prayer: Prayer) -> Int {
            let topics = Set(prayer.topics.map { $0.lowercased() })
            return interests.filter { interest in
                switch interest {
                case "beginner": topics.contains("beginner") || prayer.category == "Learn"
                case "family": prayer.suitability == "family"
                case "rest": prayer.category == "Rest"
                case "rosary": prayer.rosarySet != nil
                case "morning", "scripture": topics.contains(interest)
                default: false
                }
            }.count
        }
        return fitting.enumerated().max { lhs, rhs in
            let left = score(lhs.element), right = score(rhs.element)
            if left != right { return left < right }
            if (lhs.element.id == usualID) != (rhs.element.id == usualID) { return rhs.element.id == usualID }
            return lhs.offset > rhs.offset
        }?.element
    }
}
