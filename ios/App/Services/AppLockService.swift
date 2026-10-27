import Foundation
import Observation
import LocalAuthentication

@MainActor @Observable final class AppLockService {
    private struct Configuration: Codable { var enabled: Bool }
    private(set) var enabled: Bool
    private(set) var isUnlocked: Bool
    private(set) var authenticating = false
    private(set) var errorMessage: String?
    private let file: URL
    private let authenticate: () async throws -> Bool
    private var generation = UUID()

    init(root: URL? = nil, authenticate: (() async throws -> Bool)? = nil) throws {
        file = try PrivateFiles.directory("AppLock", root: root).appendingPathComponent("configuration.json")
        let storedEnabled: Bool
        if FileManager.default.fileExists(atPath: file.path) {
            storedEnabled = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: file)).enabled
        } else { storedEnabled = false }
        enabled = storedEnabled; isUnlocked = !storedEnabled
        self.authenticate = authenticate ?? {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Open your private prayer space.")
        }
    }
    @discardableResult func unlock() async -> Bool {
        guard enabled else { isUnlocked = true; return true }
        guard !authenticating else { return false }
        authenticating = true; defer { authenticating = false }
        let request = generation
        do {
            guard try await authenticate(), request == generation else { errorMessage = "Your prayer space is still locked. Try again with Face ID, Touch ID, or your device passcode."; return false }
            isUnlocked = true; errorMessage = nil; return true
        } catch { errorMessage = "Your prayer space is still locked. You can try again when you’re ready."; return false }
    }
    @discardableResult func setEnabled(_ value: Bool) async -> Bool {
        guard !authenticating else { return false }
        authenticating = true; defer { authenticating = false }
        let request = generation
        do {
            guard try await authenticate(), request == generation else { errorMessage = "Set a device passcode and authenticate to change the app lock."; return false }
            try PrivateFiles.write(Configuration(enabled: value), to: file)
            enabled = value; isUnlocked = true; errorMessage = nil; return true
        } catch { errorMessage = "The app lock could not be changed. Your previous setting remains in place."; return false }
    }
    func lock() { generation = UUID(); if enabled { isUnlocked = false } }
    @discardableResult func resetUnlocked() -> Bool {
        guard isUnlocked else { return false }
        do { try PrivateFiles.write(Configuration(enabled: false), to: file); enabled = false; errorMessage = nil; return true }
        catch { errorMessage = "Your app lock setting could not be reset."; return false }
    }
}
