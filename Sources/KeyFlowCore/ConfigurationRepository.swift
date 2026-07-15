import Foundation

public protocol ConfigurationStoring: Sendable {
    func load() async throws -> KeyFlowConfiguration
    func save(_ configuration: KeyFlowConfiguration) async throws
}

public actor ConfigurationRepository: ConfigurationStoring {
    public enum RepositoryError: LocalizedError {
        case noRecoverableConfiguration(String)

        public var errorDescription: String? {
            switch self {
            case let .noRecoverableConfiguration(message):
                "The configuration could not be loaded and no valid backup was available: \(message)"
            }
        }
    }

    public let fileURL: URL
    public let backupsDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let backupLimit: Int
    private var highestSavedRevision = -1

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        backupLimit: Int = 10
    ) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base =
                fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.fileURL =
                base
                .appendingPathComponent("KeyFlow", isDirectory: true)
                .appendingPathComponent("configuration.json")
        }
        backupsDirectoryURL = self.fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        self.backupLimit = max(1, backupLimit)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> KeyFlowConfiguration {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return KeyFlowConfiguration()
        }
        do {
            let configuration = try decodeConfiguration(at: fileURL)
            highestSavedRevision = configuration.revision
            return configuration
        } catch let error as ConfigurationMigrationError {
            throw error
        } catch {
            guard let recovered = try loadNewestValidBackup() else {
                throw RepositoryError.noRecoverableConfiguration(error.localizedDescription)
            }
            highestSavedRevision = recovered.revision
            return recovered
        }
    }

    public func save(_ configuration: KeyFlowConfiguration) async throws {
        guard configuration.revision >= highestSavedRevision else { return }
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try backUpCurrentConfigurationIfPresent()

        var current = configuration
        current.schemaVersion = KeyFlowConfiguration.currentSchemaVersion
        let data = try encoder.encode(current)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        highestSavedRevision = current.revision
        try pruneBackups()
    }

    private func decodeConfiguration(at url: URL) throws -> KeyFlowConfiguration {
        try ConfigurationMigrator.decode(Data(contentsOf: url), using: decoder)
    }

    private func backUpCurrentConfigurationIfPresent() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let existing = try decodeConfiguration(at: fileURL)
        try fileManager.createDirectory(at: backupsDirectoryURL, withIntermediateDirectories: true)
        let name = String(format: "configuration-r%010d.json", existing.revision)
        let destination = backupsDirectoryURL.appendingPathComponent(name)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: fileURL, to: destination)
    }

    private func loadNewestValidBackup() throws -> KeyFlowConfiguration? {
        guard fileManager.fileExists(atPath: backupsDirectoryURL.path) else { return nil }
        let candidates = try fileManager.contentsOfDirectory(
            at: backupsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent > $1.lastPathComponent }

        for candidate in candidates where candidate.pathExtension == "json" {
            if let configuration = try? decodeConfiguration(at: candidate) {
                return configuration
            }
        }
        return nil
    }

    private func pruneBackups() throws {
        guard fileManager.fileExists(atPath: backupsDirectoryURL.path) else { return }
        let backups = try fileManager.contentsOfDirectory(
            at: backupsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for expired in backups.dropFirst(backupLimit) {
            try fileManager.removeItem(at: expired)
        }
    }
}
