import Foundation

public enum ReadingKind: String, Codable, CaseIterable, Hashable, Sendable {
    case bible, encyclical, apostolicLetter, papalDocument, spiritualClassic, churchFather
    public var title: String {
        switch self {
        case .bible: "Bible"
        case .encyclical: "Encyclicals"
        case .apostolicLetter: "Apostolic letters"
        case .papalDocument: "Other papal writings"
        case .spiritualClassic: "Spiritual classics"
        case .churchFather: "Church Fathers"
        }
    }
}

public struct ReadingFile: Codable, Hashable, Sendable {
    public let path: String
    public let sha256: String
    public let bytes: Int
    public var isValid: Bool {
        !path.hasPrefix("/") && !path.contains("\\") && !path.contains(":") &&
        path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." } &&
        sha256.count == 64 && sha256.allSatisfy { "0123456789abcdef".contains($0) } && bytes > 0
    }
}

public struct ReadingRights: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable { case publicDomain, licensed, linkOnly, developmentOnly }
    public let status: Status
    public let edition: String
    public let statement: String
    public let evidenceURL: String
    public let territory: String
    public var supportsLocalText: Bool { status != .linkOnly }
}

public struct ReadingSection: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let reference: String
    public let order: Int
    public let topics: [String]
    public let file: ReadingFile
    public let verseCount: Int?
}

public struct ReadingWork: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let kind: ReadingKind
    public let language: String
    public let date: String?
    public let summary: String
    public let aliases: [String]
    public let topics: [String]
    public let sourceURL: String
    public let sourceIsDirectory: Bool?
    public let sourceLanguage: String?
    public let originalType: String?
    public let rights: ReadingRights
    public let sections: [ReadingSection]
    public let bibleCode: String?
    public var isOffline: Bool { !sections.isEmpty && rights.supportsLocalText }
}

public struct ReadingTopic: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let aliases: [String]
    public let description: String
}

public struct ReadingGuideStep: Codable, Identifiable, Hashable, Sendable {
    public var id: String { workID + ":" + (sectionID ?? "source") + ":" + (anchor ?? "start") }
    public let title: String
    public let workID: String
    public let sectionID: String?
    public let anchor: String?
    public let note: String
}

public struct ReadingGuide: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let introduction: String
    public let topics: [String]
    public let steps: [ReadingGuideStep]
}

public struct ReadingLibrary: Codable, Sendable {
    public let schemaVersion: Int
    public let revision: String
    public let isDevelopment: Bool
    public let coverage: String
    public let works: [ReadingWork]
    public let topics: [ReadingTopic]
    public let guides: [ReadingGuide]
    public let searchIndex: ReadingFile

    public func work(_ id: String) -> ReadingWork? { works.first { $0.id == id } }
    public func section(_ id: String) -> ReadingSection? { works.lazy.flatMap(\.sections).first { $0.id == id } }
    public func validate() throws {
        func require(_ value: Bool) throws { if !value { throw ReadingLibraryError.invalid } }
        func https(_ value: String) -> Bool { let url = URL(string: value); return url?.scheme == "https" && url?.host != nil && url?.user == nil && url?.password == nil }
        guard schemaVersion == 1 || schemaVersion == 2 else { throw ReadingLibraryError.unsupportedVersion }
        let topicIDs = Set(topics.map(\.id))
        let sections = works.flatMap(\.sections)
        try require(!revision.isEmpty && !works.isEmpty && searchIndex.isValid && searchIndex.path == "search-index.json")
        try require(Set(works.map(\.id)).count == works.count && topicIDs.count == topics.count)
        try require(Set(sections.map(\.id)).count == sections.count && Set(guides.map(\.id)).count == guides.count)
        for work in works {
            try require(!work.id.isEmpty && !work.title.isEmpty && !work.author.isEmpty && (schemaVersion == 1 ? work.language == "en" : ["en", "it", "la"].contains(work.language)))
            try require(https(work.sourceURL) && https(work.rights.evidenceURL) && !work.rights.edition.isEmpty && !work.rights.statement.isEmpty && !work.rights.territory.isEmpty)
            try require(work.sections.isEmpty || work.rights.supportsLocalText)
            try require(work.rights.status != .developmentOnly || (schemaVersion == 2 && isDevelopment))
            try require(work.topics.allSatisfy(topicIDs.contains))
            try require(Set(work.sections.map(\.order)).count == work.sections.count)
            for section in work.sections {
                try require(section.file.isValid && section.file.path.hasPrefix("markdown/") && section.file.path.hasSuffix(".md"))
                try require(!section.id.isEmpty && !section.title.isEmpty && section.order > 0 && section.topics.allSatisfy(topicIDs.contains))
                if work.kind == .bible { try require((section.verseCount ?? 0) > 0) }
            }
        }
        for topic in topics { try require(!topic.id.isEmpty && !topic.title.isEmpty) }
        for guide in guides {
            try require(!guide.steps.isEmpty && guide.topics.allSatisfy(topicIDs.contains))
            for step in guide.steps {
                guard let work = work(step.workID) else { throw ReadingLibraryError.invalid }
                try require(step.sectionID.map { id in work.sections.contains { $0.id == id } } ?? (step.anchor == nil))
            }
        }
    }
}

public enum ReadingLibraryError: Error, LocalizedError {
    case unsupportedVersion, invalid, integrity
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This reading library needs a newer app."
        case .invalid: "The reading library could not be opened. Your prayer library is still available."
        case .integrity: "This reading could not be verified. Please reinstall the library from a trusted source."
        }
    }
}

public struct ReadingSearchDocument: Codable, Sendable {
    public let id: String
    public let workID: String
    public let sectionID: String?
    public let text: String
    public let normalizedText: String?
    public init(id: String, workID: String, sectionID: String?, text: String, normalizedText: String? = nil) {
        self.id = id; self.workID = workID; self.sectionID = sectionID; self.text = text; self.normalizedText = normalizedText
    }
}

public struct ReadingSearchResult: Identifiable, Sendable {
    public let id: String
    public let workID: String
    public let sectionID: String?
    public let anchor: String?
    public let title: String
    public let reason: String
    public let excerpt: String?
    public let score: Int
}

/// Full-text and curated-topic search is local and deterministic. It does not infer doctrine.
public struct ReadingSearchEngine: Sendable {
    private struct Entry: Sendable {
        let document: ReadingSearchDocument
        let work: ReadingWork
        let section: ReadingSection?
        let metadata: String
        let body: String
        let topicIDs: Set<String>
    }
    private let entries: [Entry]
    private let topics: [ReadingTopic]
    public init(library: ReadingLibrary, documents: [ReadingSearchDocument]) throws {
        try library.validate()
        topics = library.topics
        let works = Dictionary(uniqueKeysWithValues: library.works.map { ($0.id, $0) })
        var seen = Set<String>()
        entries = try documents.map { document in
            guard seen.insert(document.id).inserted, let work = works[document.workID] else { throw ReadingLibraryError.invalid }
            let section = document.sectionID.flatMap { id in work.sections.first { $0.id == id } }
            guard document.sectionID == nil || section != nil,
                  work.rights.supportsLocalText || (document.text.isEmpty && (document.normalizedText?.isEmpty ?? true)) else { throw ReadingLibraryError.invalid }
            return Entry(document: document, work: work, section: section,
                         metadata: Self.normalize(([work.title, work.author, section?.reference ?? "", section?.title ?? ""] + work.aliases).joined(separator: " ")),
                         body: document.normalizedText ?? Self.normalize(document.text), topicIDs: Set(work.topics + (section?.topics ?? [])))
        }
    }
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    public func search(_ query: String, topicID: String? = nil, kind: ReadingKind? = nil, author: String? = nil, offlineOnly: Bool = false, limit: Int = 80) -> [ReadingSearchResult] {
        let reference = bibleReference(query)
        let query = Self.normalize(query)
        let words = query.split(separator: " ").map(String.init)
        let matchingTopics = topics.filter { topic in
            !query.isEmpty && ([topic.title, topic.id] + topic.aliases).contains { Self.normalize($0) == query }
        }
        let topicMatches = Set(matchingTopics.map(\.id))
        let expanded = matchingTopics.flatMap { [$0.title] + $0.aliases }.map(Self.normalize)
        var matches: [(entry: Entry, score: Int, reason: String)] = []
        for entry in entries {
            if Task.isCancelled { return [] }
            guard kind == nil || entry.work.kind == kind, author == nil || entry.work.author == author,
                  !offlineOnly || entry.work.isOffline, topicID.map(entry.topicIDs.contains) ?? true else { continue }
            if let reference {
                guard reference.works.contains(entry.work.id), entry.section?.order == reference.chapter,
                      reference.verse.map({ $0 > 0 && $0 <= (entry.section?.verseCount ?? 0) }) ?? true else { continue }
            }
            let curated = !entry.topicIDs.isDisjoint(with: topicMatches)
            let metadataMatch = !words.isEmpty && words.allSatisfy { entry.metadata.contains($0) }
            let bodyMatch = !words.isEmpty && words.allSatisfy { entry.body.range(of: $0, options: .literal) != nil }
            let related = expanded.contains { !($0.isEmpty) && entry.body.range(of: $0, options: .literal) != nil }
            guard reference != nil || query.isEmpty || curated || metadataMatch || bodyMatch || related else { continue }
            let score = (reference != nil ? 300 : 0) + (curated ? 100 : 0) + (metadataMatch ? 70 : 0) + (bodyMatch ? 30 : 0) + (related ? 10 : 0)
            let reason = reference != nil ? "Bible reference" : curated ? "Selected for \(matchingTopics.first?.title.lowercased() ?? "this topic")" : metadataMatch ? "Title, author, or reference" : bodyMatch ? "Text matches your search" : related ? "Related topic wording" : entry.work.isOffline ? "Available offline" : "Source link"
            matches.append((entry, score, reason))
        }
        // Format excerpts only for the returned page, after ranking the matches.
        return matches.sorted { lhs, rhs in lhs.score == rhs.score ? lhs.entry.document.id < rhs.entry.document.id : lhs.score > rhs.score }
            .prefix(max(0, limit)).compactMap { candidate -> ReadingSearchResult? in
            guard !Task.isCancelled else { return nil }
            let entry = candidate.entry
            let original = entry.document.text
            let match = ([query] + expanded).lazy.filter { !$0.isEmpty }.compactMap { original.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) }.first
            let start = match.map { original.index($0.lowerBound, offsetBy: -65, limitedBy: original.startIndex) ?? original.startIndex } ?? original.startIndex
            let end = original.index(start, offsetBy: 210, limitedBy: original.endIndex) ?? original.endIndex
            let excerpt = original.isEmpty ? nil : (start > original.startIndex ? "…" : "") + String(original[start..<end]) + (end < original.endIndex ? "…" : "")
            return ReadingSearchResult(id: entry.document.id, workID: entry.work.id, sectionID: entry.section?.id,
                                       anchor: reference?.verse.map { "verse-\($0)" },
                                       title: (entry.section?.reference ?? entry.work.title) + (reference?.verse.map { ":\($0)" } ?? ""), reason: candidate.reason, excerpt: excerpt, score: candidate.score)
        }
    }
    private func bibleReference(_ query: String) -> (works: Set<String>, chapter: Int, verse: Int?)? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(.+?[A-Za-z.])\s*(\d{1,3})(?::(\d{1,3})(?:[-–]\d{1,3})?)?\s*$"#),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let bookRange = Range(match.range(at: 1), in: query), let chapterRange = Range(match.range(at: 2), in: query),
              let chapter = Int(query[chapterRange]) else { return nil }
        func bookKey(_ text: String) -> String { Self.normalize(text).replacingOccurrences(of: " ", with: "") }
        let book = bookKey(String(query[bookRange]))
        let books = entries.map(\.work).filter { $0.kind == .bible }
        // Traditional names win when a modern alias names a different historical book.
        let primary = Set(books.filter { bookKey(String($0.title.split(separator: "(").first ?? "")) == book }.map(\.id))
        let aliases = Set(books.filter { work in work.aliases.contains { bookKey($0) == book } || (work.bibleCode == "PSA" && ["ps", "psalm"].contains(book)) }.map(\.id))
        let selected = primary.isEmpty ? aliases : primary
        guard !selected.isEmpty else { return nil }
        let verse = Range(match.range(at: 3), in: query).flatMap { Int(query[$0]) }
        return (selected, chapter, verse)
    }
}

public struct ReadingShelf: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var savedIDs: [String] = []
    public var lastSectionID: String?
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1, Set(savedIDs).count == savedIDs.count,
              savedIDs.allSatisfy({ !$0.isEmpty }), lastSectionID.map({ !$0.isEmpty }) ?? true else { throw ReadingLibraryError.invalid }
    }
}

public struct ReadingBlock: Identifiable, Hashable, Sendable {
    public let id: String
    public let headingLevel: Int
    public let text: String
    public static func parse(_ markdown: String) -> [ReadingBlock] {
        var blocks: [ReadingBlock] = []
        for paragraph in markdown.components(separatedBy: "\n\n") {
            let text = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let level = text.prefix(while: { $0 == "#" }).count
            let content = level > 0 ? String(text.dropFirst(level)).trimmingCharacters(in: .whitespaces) : text
            let verse = text.range(of: #"^\*\*(\d+)\.?\*\*"#, options: .regularExpression)
                .map { String(text[$0]).filter(\.isNumber) }
            blocks.append(ReadingBlock(id: verse.map { "verse-\($0)" } ?? "block-\(blocks.count)", headingLevel: min(6, level), text: content))
        }
        return blocks
    }
}
