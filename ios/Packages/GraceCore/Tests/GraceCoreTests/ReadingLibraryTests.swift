import Foundation
import Testing
@testable import GraceCore

private func readingsRoot() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("content/readings")
}
private func readingsData() throws -> Data { try Data(contentsOf: readingsRoot().appendingPathComponent("library.json")) }
private func readings() throws -> ReadingLibrary { try JSONDecoder().decode(ReadingLibrary.self, from: readingsData()) }

@Test func readingLibraryContainsTheCatholicCanonAndTraditionalNumbering() throws {
    let library = try readings(); try library.validate()
    let books = library.works.filter { $0.kind == .bible }
    #expect(books.count == 73)
    #expect(books.flatMap(\.sections).count == 1334)
    #expect(books.flatMap(\.sections).compactMap(\.verseCount).reduce(0, +) == 35811)
    #expect(library.work("drb-est")?.sections.count == 16)
    #expect(library.work("drb-dan")?.sections.count == 14)
    #expect(library.work("drb-tob") != nil && library.work("drb-wis") != nil && library.work("drb-2ma") != nil)
    let psalm = try #require(library.section("drb-psa-22"))
    let markdown = try String(contentsOf: readingsRoot().appendingPathComponent(psalm.file.path), encoding: .utf8)
    #expect(markdown.contains("The Lord ruleth me"))
    #expect(ReadingBlock.parse(markdown).contains { $0.id == "verse-1" })
}

@Test func papalSummarySectionsPreserveSourceIdentityLanguageDatesAndTypes() throws {
    let library = try readings(); try library.validate()
    #expect(library.schemaVersion == 2)
    #expect(library.works.count == 645)
    #expect(library.works.flatMap(\.sections).count == 2629)
    let papalWorks = library.works.filter { [.encyclical, .papalDocument, .apostolicLetter].contains($0.kind) }
    #expect(papalWorks.count == 569)
    for work in papalWorks {
        #expect(work.sections.count == 2)
        let body = try #require(work.sections.first { $0.id == "\(work.id)-text" })
        let summary = try #require(work.editorialSummary)
        #expect(body.order == 1)
        #expect(!work.isEditorialSummary(body))
        #expect(summary.id == "\(work.id)-summary")
        #expect(summary.order == 2)
        #expect(summary.title == "English editorial summary")
        #expect(summary.reference == "\(work.title) · English editorial summary")
        #expect(work.isEditorialSummary(summary))
        #expect(work.rights.status == .developmentOnly)
    }
    #expect(papalWorks.filter { $0.language == "en" }.count == 394)
    #expect(papalWorks.filter { $0.language == "it" }.count == 162)
    #expect(papalWorks.filter { $0.language == "la" }.count == 13)
    #expect(library.work("papal-greg16-in-consistorio")?.date == "1843-04-06")
    #expect(library.work("papal-greg16-maximis-angustiis")?.date == "1844-04-27")
    for (id, originalType) in [
        ("papal-pius09-aeterni-patris", "bull"),
        ("papal-pius09-apostolici-ministerii", "brief"),
        ("papal-pius09-dogmatica-dei-filius", "apostolic-constitution"),
        ("papal-pius12-guiding-principles-of-the-lay-apostolate", "address")
    ] {
        #expect(library.work(id)?.originalType == originalType)
        #expect(library.work(id)?.kind == .papalDocument)
    }
    let latin = try #require(library.work("papal-ben14-sollicita-ac-provida"))
    let anotherSummary = try #require(library.work("papal-ben16-spe-salvi")?.editorialSummary)
    #expect(!latin.isEditorialSummary(anotherSummary))
    #expect(library.work("drb-rom")?.editorialSummary == nil)
}

@Test func recoveredPapalBodyAndEnglishSummarySearchUseLocalMarkdown() throws {
    let library = try readings()
    let recovered = try #require(library.work("papal-pius12-guiding-principles-of-the-lay-apostolate"))
    let latin = try #require(library.work("papal-ben14-sollicita-ac-provida"))
    let body = try #require(recovered.sections.first { $0.id == "\(recovered.id)-text" })
    let recoveredSummary = try #require(recovered.editorialSummary)
    let englishSummary = try #require(latin.editorialSummary)
    let selected: [(ReadingWork, ReadingSection)] = [(recovered, body), (recovered, recoveredSummary), (latin, englishSummary)]
    let documents = try selected.map { work, section in
        let data = try Data(contentsOf: readingsRoot().appendingPathComponent(section.file.path))
        #expect(data.count == section.file.bytes)
        let markdown = try #require(String(data: data, encoding: .utf8))
        let blocks = ReadingBlock.parse(markdown)
        #expect(!blocks.isEmpty)
        if section.id == body.id {
            #expect(markdown.split(whereSeparator: \.isWhitespace).count > 8000)
            #expect(blocks.contains { $0.text.contains("Principle of Subsidiarity") })
            #expect(blocks.contains { $0.text.contains("European Coal and Steel Authority") })
        }
        return ReadingSearchDocument(id: section.id, workID: work.id, sectionID: section.id, text: markdown)
    }
    let engine = try ReadingSearchEngine(library: library, documents: documents)
    #expect(engine.search("European Coal and Steel Authority", offlineOnly: true).map(\.sectionID) == [body.id])
    let results = engine.search("procedural safeguards", author: latin.author, offlineOnly: true)
    #expect(results.map(\.sectionID) == [englishSummary.id])
    #expect(results.first?.reason == "Text matches your search")
    #expect(results.first?.excerpt?.contains("procedural safeguards") == true)
    #expect(latin.language == "la")
}

@Test func topicSearchConnectsScriptureClassicsAndOfflinePapalReadings() throws {
    let library = try readings()
    let wanted = ["drb-rom-8", "imitation-book-2-chapter-12", "papal-ben16-spe-salvi-text"]
    let documents = try wanted.map { id in
        let section = try #require(library.section(id))
        let work = try #require(library.works.first { $0.sections.contains { $0.id == id } })
        return ReadingSearchDocument(id: id, workID: work.id, sectionID: id,
            text: try String(contentsOf: readingsRoot().appendingPathComponent(section.file.path), encoding: .utf8))
    }
    let engine = try ReadingSearchEngine(library: library, documents: documents)
    for query in ["suffering", "sorrow", "affliction"] {
        let results = engine.search(query)
        #expect(Set(results.map(\.workID)) == ["drb-rom", "imitation", "papal-ben16-spe-salvi"])
        #expect(results.first(where: { $0.workID == "papal-ben16-spe-salvi" })?.excerpt != nil)
    }
    #expect(engine.search("suffering", offlineOnly: true).count == 3)
    #expect(engine.search("suffering", kind: .encyclical).map(\.workID) == ["papal-ben16-spe-salvi"])
    #expect(engine.search("suffering", author: "Saint Augustine of Hippo").isEmpty)
    #expect(engine.search("nonsense-with-no-matches").isEmpty)
    #expect(engine.search("Romans 8:18").map(\.anchor) == ["verse-18"])
    #expect(engine.search("Rom8:18").first?.sectionID == "drb-rom-8")
    #expect(engine.search("Romans 8:999").isEmpty)
    #expect(engine.search("Romans 99").isEmpty)
}

@Test func readingContractRejectsTraversalUnknownVersionsAndUnclearedOfflineBodies() throws {
    let original = try JSONSerialization.jsonObject(with: readingsData()) as! [String: Any]
    func decode(_ json: [String: Any]) throws -> ReadingLibrary { try JSONDecoder().decode(ReadingLibrary.self, from: JSONSerialization.data(withJSONObject: json)) }
    var changed = original; changed["schemaVersion"] = 99
    #expect(throws: (any Error).self) { try decode(changed).validate() }
    for path in ["../outside.md", "/tmp/outside.md", "markdown/../outside.md", "markdown\\outside.md", "https://example.org/file.md"] {
        var works = original["works"] as! [[String: Any]]
        var sections = works[0]["sections"] as! [[String: Any]]
        var file = sections[0]["file"] as! [String: Any]; file["path"] = path
        sections[0]["file"] = file; works[0]["sections"] = sections; changed = original; changed["works"] = works
        #expect(throws: (any Error).self) { try decode(changed).validate() }
    }
    var works = original["works"] as! [[String: Any]]
    var rights = works[0]["rights"] as! [String: Any]; rights["status"] = "linkOnly"
    works[0]["rights"] = rights; changed = original; changed["works"] = works
    #expect(throws: (any Error).self) { try decode(changed).validate() }
    works[0]["sections"] = []; changed["works"] = [works[0]]; changed["guides"] = []
    let library = try decode(changed)
    let leaked = ReadingSearchDocument(id: "source-text", workID: library.works[0].id, sectionID: nil, text: "A source-only document body")
    #expect(throws: (any Error).self) { try ReadingSearchEngine(library: library, documents: [leaked]) }
    let hidden = ReadingSearchDocument(id: "hidden-text", workID: library.works[0].id, sectionID: nil, text: "", normalizedText: "a source-only document body")
    #expect(throws: (any Error).self) { try ReadingSearchEngine(library: library, documents: [hidden]) }
}

@Test func preparedTextMatchesAccentsAndCancelledSearchesReturnNoResults() async throws {
    let library = try readings()
    let id = "papal-pius08-coelestis-agricola-text"
    let document = ReadingSearchDocument(id: id, workID: "papal-pius08-coelestis-agricola", sectionID: id,
        text: "Carità e speranza per chi soffre.", normalizedText: "carita e speranza per chi soffre")
    let engine = try ReadingSearchEngine(library: library, documents: [document])
    #expect(engine.search("carità").first?.sectionID == id)
    #expect(engine.search("carita").first?.excerpt?.contains("Carità") == true)
    let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return engine.search("carità") }
    let cancelled = await task.value
    #expect(cancelled.isEmpty)
}

@Test func guideReferencesResolveAndShelfCompatibilityFailsClosed() throws {
    let library = try readings()
    let guide = try #require(library.guides.first { $0.id == "guide-suffering" })
    #expect(guide.steps.contains { $0.workID == "papal-ben16-spe-salvi" && $0.sectionID == "papal-ben16-spe-salvi-text" })
    #expect(guide.steps.contains { $0.sectionID == "drb-rom-8" && $0.anchor == "verse-18" })
    var shelf = ReadingShelf(); shelf.savedIDs = ["drb-rom-8"]; shelf.lastSectionID = "drb-rom-8"
    let reopened = try JSONDecoder().decode(ReadingShelf.self, from: JSONEncoder().encode(shelf)); try reopened.validate()
    #expect(reopened == shelf)
    shelf.schemaVersion = 2
    #expect(throws: (any Error).self) { try shelf.validate() }
}

@Test func developmentEditionsCannotBecomeProductionAndVersionOneStillDecodes() throws {
    let original = try JSONSerialization.jsonObject(with: readingsData()) as! [String: Any]
    func decode(_ json: [String: Any]) throws -> ReadingLibrary { try JSONDecoder().decode(ReadingLibrary.self, from: JSONSerialization.data(withJSONObject: json)) }
    var changed = original; changed["isDevelopment"] = false
    #expect(throws: (any Error).self) { try decode(changed).validate() }
    let library = try readings()
    #expect(library.works.allSatisfy { $0.isOffline })
    #expect(library.work("papal-ben14-sollicita-ac-provida")?.language == "la")
    #expect(library.work("papal-ben14-bolla-providas-romanorum")?.rights.edition.contains("DeepL") == true)
    changed = original; changed["schemaVersion"] = 1
    changed["works"] = (original["works"] as! [[String: Any]]).filter { $0["kind"] as? String == "bible" }; changed["guides"] = []
    try decode(changed).validate()
    changed["works"] = original["works"]
    #expect(throws: (any Error).self) { try decode(changed).validate() }
}

@Test func bibleReferencesChooseTheChapterAndRespectTraditionalBookNames() throws {
    let library = try readings()
    let documents = ["drb-psa-22", "drb-psa-122", "drb-1sa-1", "drb-1ki-1"].map { id in
        ReadingSearchDocument(id: id, workID: String(id.split(separator: "-").dropLast().joined(separator: "-")), sectionID: id, text: "Reference test")
    }
    let engine = try ReadingSearchEngine(library: library, documents: documents)
    #expect(engine.search("Psalm 22:1").map(\.sectionID) == ["drb-psa-22"])
    #expect(engine.search("Ps22").map(\.sectionID) == ["drb-psa-22"])
    #expect(engine.search("1 Kings 1").map(\.sectionID) == ["drb-1sa-1"])
    #expect(engine.search("1Samuel1").map(\.sectionID) == ["drb-1sa-1"])
    #expect(engine.search("3 Kings 1").map(\.sectionID) == ["drb-1ki-1"])
}
