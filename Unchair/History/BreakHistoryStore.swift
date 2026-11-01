import Foundation

protocol BreakHistoryStoring: AnyObject {
    var records: [BreakHistoryRecord] { get }
    func append(_ record: BreakHistoryRecord)
    func clearAll()
}

/// JSON file under Application Support. Local only — no network, no account.
final class FileBreakHistoryStore: BreakHistoryStoring {
    static let schemaVersion = 1
    static let fileName = "break-history.v1.json"

    private struct Envelope: Codable {
        var schemaVersion: Int
        var records: [BreakHistoryRecord]
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cached: [BreakHistoryRecord]

    var records: [BreakHistoryRecord] { cached }

    init(directory: URL) {
        fileURL = directory.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        cached = []
        cached = loadFromDisk()
    }

    convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Unchair", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(directory: dir)
    }

    func append(_ record: BreakHistoryRecord) {
        cached.append(record)
        persist()
    }

    func clearAll() {
        cached = []
        persist()
    }

    private func loadFromDisk() -> [BreakHistoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else { return [] }
        guard envelope.schemaVersion == Self.schemaVersion else { return [] }
        return envelope.records
    }

    private func persist() {
        let envelope = Envelope(schemaVersion: Self.schemaVersion, records: cached)
        guard let data = try? encoder.encode(envelope) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

final class InMemoryBreakHistoryStore: BreakHistoryStoring {
    private(set) var records: [BreakHistoryRecord] = []

    func append(_ record: BreakHistoryRecord) {
        records.append(record)
    }

    func clearAll() {
        records = []
    }
}
