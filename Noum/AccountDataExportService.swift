import Foundation

enum AccountDataExportError: LocalizedError, Equatable {
    case noActiveAccount
    case unsafeArchivePath(String)
    case entryTooLarge(String)
    case sourceUnavailable(String)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noActiveAccount:
            return "Noum couldn't identify an account to export."
        case .unsafeArchivePath, .entryTooLarge, .sourceUnavailable, .writeFailed:
            return "Noum couldn't prepare your export. Nothing was shared. Try again."
        }
    }
}

struct AccountDataExportManifest: Codable, Equatable {
    struct FileRecord: Codable, Equatable {
        let path: String
        let participantID: String
        let scope: AccountDataScope
    }

    let schemaVersion: Int
    let generatedAt: Date
    let accountID: String
    let participantIDs: [String]
    let files: [FileRecord]
    let keychainIncluded: Bool
    let photosLibraryIncluded: Bool
    let limitations: [String]
}

@MainActor
final class AccountDataExportService {
    private let registry: AccountDataRegistry
    private let fileManager: FileManager
    private let exportRoot: URL
    private let now: () -> Date
    private var managedExportDirectories: Set<URL> = []

    init(
        registry: AccountDataRegistry,
        fileManager: FileManager = .default,
        exportRoot: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.registry = registry
        self.fileManager = fileManager
        self.exportRoot = exportRoot
            ?? fileManager.temporaryDirectory
                .appendingPathComponent("NoumAccountExports", isDirectory: true)
        self.now = now
        // A prior process may have died while the share sheet was open.
        try? fileManager.removeItem(at: self.exportRoot)
    }

    func createExport(for rawAccountID: String) async throws -> URL {
        let accountID = rawAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else { throw AccountDataExportError.noActiveAccount }
        cleanupAll()

        let generatedAt = now()
        var entries = try registry.exportEntries(for: accountID)
        let manifest = AccountDataExportManifest(
            schemaVersion: 1,
            generatedAt: generatedAt,
            accountID: accountID,
            participantIDs: registry.coverage.exportParticipantIDs.sorted(),
            files: entries.map {
                .init(path: $0.relativePath, participantID: $0.participantID, scope: $0.scope)
            }.sorted { $0.path < $1.path },
            keychainIncluded: false,
            photosLibraryIncluded: false,
            limitations: [
                "Keychain credentials, provider tokens, and other authentication secrets are excluded.",
                "Recordings saved to Photos are controlled by the Photos library and are not included.",
                "Legacy device-wide records and app-managed fallback recordings cannot be attributed to one account; they are labelled as unattributed in this archive.",
                "Data retained by cloud processors is not copied into this local export.",
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        entries.append(AccountDataExportEntry(
            relativePath: "manifest.json",
            participantID: "manifest",
            scope: .account,
            source: .data(try encoder.encode(manifest))
        ))

        let directory = exportRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        managedExportDirectories.insert(directory)
        let destination = directory.appendingPathComponent(
            "Noum-export-\(Self.dateStamp(generatedAt)).zip"
        )
        do {
            try await Task.detached(priority: .userInitiated) {
                try StoredZIPWriter.write(
                    entries: entries,
                    to: destination,
                    date: generatedAt
                )
            }.value
            return destination
        } catch {
            try? fileManager.removeItem(at: directory)
            managedExportDirectories.remove(directory)
            if let exportError = error as? AccountDataExportError { throw exportError }
            throw AccountDataExportError.writeFailed
        }
    }

    func cleanupExport(at url: URL?) {
        guard let url else { return }
        let directory = url.deletingLastPathComponent().standardizedFileURL
        guard managedExportDirectories.contains(directory) else { return }
        try? fileManager.removeItem(at: directory)
        managedExportDirectories.remove(directory)
    }

    func cleanupAll() {
        for directory in managedExportDirectories {
            try? fileManager.removeItem(at: directory)
        }
        managedExportDirectories.removeAll()
        if fileManager.fileExists(atPath: exportRoot.path) {
            try? fileManager.removeItem(at: exportRoot)
        }
    }

    nonisolated static func dateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum StoredZIPWriter {
    private struct PreparedEntry {
        let pathData: Data
        let crc32: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    static func write(
        entries: [AccountDataExportEntry],
        to destination: URL,
        date: Date
    ) throws {
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: temporary)
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw AccountDataExportError.writeFailed
        }

        do {
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }
            let timestamp = dosTimestamp(date)
            var prepared: [PreparedEntry] = []
            var offset: UInt64 = 0

            for entry in entries.sorted(by: { $0.relativePath < $1.relativePath }) {
                let path = try validatedPath(entry.relativePath)
                let pathData = Data(path.utf8)
                let metadata = try sourceMetadata(entry.source, path: path)
                guard offset <= UInt32.max else {
                    throw AccountDataExportError.entryTooLarge(path)
                }
                var header = Data()
                header.appendLE(UInt32(0x04034b50))
                header.appendLE(UInt16(20))
                header.appendLE(UInt16(0x0800))
                header.appendLE(UInt16(0))
                header.appendLE(timestamp.time)
                header.appendLE(timestamp.date)
                header.appendLE(metadata.crc32)
                header.appendLE(metadata.size)
                header.appendLE(metadata.size)
                header.appendLE(UInt16(pathData.count))
                header.appendLE(UInt16(0))
                try handle.write(contentsOf: header)
                try handle.write(contentsOf: pathData)
                try writeSource(entry.source, to: handle, path: path)
                prepared.append(PreparedEntry(
                    pathData: pathData,
                    crc32: metadata.crc32,
                    size: metadata.size,
                    localHeaderOffset: UInt32(offset)
                ))
                offset += UInt64(header.count + pathData.count) + UInt64(metadata.size)
            }

            let centralOffset = offset
            for entry in prepared {
                var header = Data()
                header.appendLE(UInt32(0x02014b50))
                header.appendLE(UInt16(20))
                header.appendLE(UInt16(20))
                header.appendLE(UInt16(0x0800))
                header.appendLE(UInt16(0))
                header.appendLE(timestamp.time)
                header.appendLE(timestamp.date)
                header.appendLE(entry.crc32)
                header.appendLE(entry.size)
                header.appendLE(entry.size)
                header.appendLE(UInt16(entry.pathData.count))
                header.appendLE(UInt16(0))
                header.appendLE(UInt16(0))
                header.appendLE(UInt16(0))
                header.appendLE(UInt16(0))
                header.appendLE(UInt32(0))
                header.appendLE(entry.localHeaderOffset)
                try handle.write(contentsOf: header)
                try handle.write(contentsOf: entry.pathData)
                offset += UInt64(header.count + entry.pathData.count)
            }
            let centralSize = offset - centralOffset
            guard entries.count <= Int(UInt16.max),
                  centralOffset <= UInt32.max,
                  centralSize <= UInt32.max else {
                throw AccountDataExportError.writeFailed
            }
            var end = Data()
            end.appendLE(UInt32(0x06054b50))
            end.appendLE(UInt16(0))
            end.appendLE(UInt16(0))
            end.appendLE(UInt16(entries.count))
            end.appendLE(UInt16(entries.count))
            end.appendLE(UInt32(centralSize))
            end.appendLE(UInt32(centralOffset))
            end.appendLE(UInt16(0))
            try handle.write(contentsOf: end)
            try handle.synchronize()
            try handle.close()
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func validatedPath(_ value: String) throws -> String {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.contains("\\"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              value.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw AccountDataExportError.unsafeArchivePath(value)
        }
        return value
    }

    private static func sourceMetadata(
        _ source: AccountDataExportSource,
        path: String
    ) throws -> (crc32: UInt32, size: UInt32) {
        switch source {
        case .data(let data):
            guard data.count <= Int(UInt32.max) else {
                throw AccountDataExportError.entryTooLarge(path)
            }
            return (CRC32.checksum(data), UInt32(data.count))
        case .file(let url):
            guard FileManager.default.fileExists(atPath: url.path),
                  let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
                  size.uint64Value <= UInt32.max else {
                throw AccountDataExportError.sourceUnavailable(path)
            }
            return (try CRC32.checksum(file: url), UInt32(size.uint64Value))
        }
    }

    private static func writeSource(
        _ source: AccountDataExportSource,
        to destination: FileHandle,
        path: String
    ) throws {
        switch source {
        case .data(let data):
            try destination.write(contentsOf: data)
        case .file(let url):
            let sourceHandle = try FileHandle(forReadingFrom: url)
            defer { try? sourceHandle.close() }
            while true {
                let chunk = try sourceHandle.read(upToCount: 64 * 1024) ?? Data()
                if chunk.isEmpty { break }
                try destination.write(contentsOf: chunk)
            }
        }
        _ = path
    }

    private static func dosTimestamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max(components.year ?? 1980, 1980), 2107)
        let month = min(max(components.month ?? 1, 1), 12)
        let day = min(max(components.day ?? 1, 1), 31)
        let hour = min(max(components.hour ?? 0, 0), 23)
        let minute = min(max(components.minute ?? 0, 0), 59)
        let second = min(max(components.second ?? 0, 0), 59)
        return (
            UInt16((hour << 11) | (minute << 5) | (second / 2)),
            UInt16(((year - 1980) << 9) | (month << 5) | day)
        )
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xff)]
        }
        return crc ^ UInt32.max
    }

    static func checksum(file: URL) throws -> UInt32 {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var crc = UInt32.max
        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }
            for byte in chunk {
                crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xff)]
            }
        }
        return crc ^ UInt32.max
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
