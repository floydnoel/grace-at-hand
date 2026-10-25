import Foundation
import Observation
import CryptoKit
import Network
import GraceCore

struct AppConfiguration {
    let environment: String
    let contentBaseURL: URL?
    let supportURL: URL?
    let privacyURL: URL?
    let helpEmail: String?
    var isProduction: Bool { environment == "production" }
    init(bundle: Bundle = .main) {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String,
                  !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
            return raw
        }
        environment = value("GraceEnvironment") ?? "fixture"
        contentBaseURL = environment == "fixture" ? nil : value("GraceContentBaseURL").flatMap(URL.init(string:))
        supportURL = value("GraceSupportURL").flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
        privacyURL = value("GracePrivacyURL").flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
        helpEmail = value("GraceHelpEmail")
    }
}

enum Integrity {
    nonisolated static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    nonisolated static func fileHash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

struct CachedCatalog: Codable {
    let generation: Int64
    let catalog: Catalog
}

@MainActor @Observable final class CatalogRepository {
    private(set) var catalog: Catalog
    private(set) var refreshing = false
    private(set) var errorMessage: String?
    private(set) var isOffline = false
    private let cache: URL
    let configuration: AppConfiguration
    private let monitor = NWPathMonitor()
    private var generation: Int64 = 0

    init(configuration: AppConfiguration, root: URL? = nil) throws {
        self.configuration = configuration
        let folder = try PrivateFiles.directory("PublicCatalog", root: root)
        cache = folder.appendingPathComponent("catalog-cache.json")
        guard let bundledURL = Bundle.main.url(forResource: "catalog", withExtension: "json") else { throw CatalogError.invalid("Missing bundled catalog") }
        let bundled = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: bundledURL)); try bundled.validate()
        if configuration.isProduction && bundled.isFixture { throw CatalogError.invalid("Production build contains fixture content") }
        catalog = bundled
        if let bytes = try? Data(contentsOf: cache), let cached = try? JSONDecoder().decode(CachedCatalog.self, from: bytes),
           cached.generation >= 0, (try? cached.catalog.validate()) != nil,
           !configuration.isProduction || !cached.catalog.isFixture { catalog = cached.catalog; generation = cached.generation }
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "GraceConnectivity"))
    }
    func mediaURL(_ asset: MediaAsset) -> URL? {
        if asset.url.hasPrefix("bundle:") {
            let name = String(asset.url.dropFirst(7))
            guard !name.contains("/"), !name.contains("..") else { return nil }
            return Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Media") ?? Bundle.main.url(forResource: name, withExtension: nil)
        }
        guard let base = configuration.contentBaseURL,
              let url = URL(string: asset.url, relativeTo: base)?.absoluteURL,
              allowed(url, base: base) else { return nil }
        return url
    }
    private func allowed(_ url: URL, base: URL) -> Bool {
        let local = configuration.environment == "preview" && ["localhost", "127.0.0.1"].contains(url.host ?? "")
        return url.host == base.host && url.port == base.port && (url.scheme == "https" || (local && url.scheme == "http"))
    }
    func refresh() async {
        guard !refreshing, let base = configuration.contentBaseURL else { return }
        refreshing = true; defer { refreshing = false }
        do {
            guard allowed(base, base: base) else { throw CatalogError.invalid("Insecure content host") }
            let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 45
            let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
            let (pointerData, pointerResponse) = try await session.data(from: base.appendingPathComponent("latest.json"))
            guard let pointerURL = pointerResponse.url, allowed(pointerURL, base: base),
                  (pointerResponse as? HTTPURLResponse)?.statusCode == 200, pointerData.count < 32_768 else { throw CatalogError.invalid("Invalid publication pointer") }
            let pointer = try JSONDecoder().decode(CatalogPointer.self, from: pointerData)
            guard pointer.schemaVersion == 1 else { throw CatalogError.unsupportedVersion }
            guard pointer.generation > generation else { errorMessage = nil; return }
            guard let url = URL(string: pointer.catalogURL, relativeTo: base)?.absoluteURL, allowed(url, base: base) else { throw CatalogError.invalid("Invalid catalog host") }
            let (data, response) = try await session.data(from: url)
            guard let responseURL = response.url, allowed(responseURL, base: base),
                  (response as? HTTPURLResponse)?.statusCode == 200, data.count < 20_000_000, Integrity.sha256(data) == pointer.sha256 else { throw CatalogError.invalid("Catalog verification failed") }
            let next = try JSONDecoder().decode(Catalog.self, from: data); try next.validate()
            if configuration.isProduction && next.isFixture { throw CatalogError.invalid("Fixture content") }
            try PrivateFiles.write(CachedCatalog(generation: pointer.generation, catalog: next), to: cache)
            catalog = next; generation = pointer.generation; errorMessage = nil
        } catch { errorMessage = "Fresh content could not load. Your saved library and downloaded prayers are still here." }
    }
}
