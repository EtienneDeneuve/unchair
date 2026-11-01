import XCTest
@testable import Unchair

final class BreakHistoryStoreTests: XCTestCase {
    func testAppendPersistsAcrossStoreReload() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unchair-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = FileBreakHistoryStore(directory: dir)
        let record = BreakHistoryRecord(
            id: UUID(),
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            breakID: UUID(),
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_000 - 3_000),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000 - 90),
            endedAt: Date(timeIntervalSince1970: 1_700_000_000),
            result: .completed,
            durationSeconds: 90,
            verification: BreakHistoryVerification(
                stoodForSeconds: 12,
                motionScore: 0.4,
                failedOpen: false
            )
        )
        store.append(record)

        let reloaded = FileBreakHistoryStore(directory: dir)
        XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertEqual(reloaded.records[0].result, .completed)
        XCTAssertEqual(reloaded.records[0].verification?.motionScore, 0.4)
        XCTAssertEqual(reloaded.records[0].id, record.id)
    }

    func testClearAllWipesDisk() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unchair-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = FileBreakHistoryStore(directory: dir)
        store.append(
            BreakHistoryRecord(
                id: UUID(),
                recordedAt: Date(),
                breakID: nil,
                scheduledAt: nil,
                startedAt: nil,
                endedAt: Date(),
                result: .skipped,
                durationSeconds: 0,
                verification: nil
            )
        )
        store.clearAll()

        let reloaded = FileBreakHistoryStore(directory: dir)
        XCTAssertTrue(reloaded.records.isEmpty)
    }

    func testRecorderWritesCompletedSkippedAndPostponed() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let store = InMemoryBreakHistoryStore()
        let recorder = BreakHistoryRecorder(store: store, clock: clock)
        let breakID = UUID()

        recorder.noteBreakPrompted(breakID: breakID, scheduledAt: clock.now)
        recorder.recordPostponed()
        XCTAssertEqual(store.records.last?.result, .postponed)
        XCTAssertEqual(store.records.last?.breakID, breakID)

        clock.advance(by: 60)
        recorder.noteTimedBreakStarted(breakID: breakID, scheduledAt: clock.now.addingTimeInterval(-60))
        clock.advance(by: 45)
        recorder.recordCompleted(
            verification: BreakHistoryVerification(
                stoodForSeconds: 10,
                motionScore: 0.3,
                failedOpen: false
            )
        )
        XCTAssertEqual(store.records.last?.result, .completed)
        XCTAssertEqual(store.records.last?.durationSeconds ?? -1, 45, accuracy: 0.001)

        recorder.noteBreakPrompted(breakID: UUID(), scheduledAt: clock.now)
        recorder.recordSkipped()
        XCTAssertEqual(store.records.last?.result, .skipped)
        XCTAssertEqual(store.records.count, 3)
    }

    func testSchemaForbidsMediaFieldsByConstruction() {
        // Compile-time / type-level guarantee: BreakHistoryRecord only carries
        // the documented scalar fields. This test locks the Codable keys.
        let record = BreakHistoryRecord(
            id: UUID(),
            recordedAt: Date(),
            breakID: nil,
            scheduledAt: nil,
            startedAt: nil,
            endedAt: Date(),
            result: .cancelled,
            durationSeconds: 0,
            verification: BreakHistoryVerification(
                stoodForSeconds: nil,
                motionScore: nil,
                failedOpen: true
            )
        )
        let data = try! JSONEncoder().encode(record)
        let json = String(decoding: data, as: UTF8.self)
        for forbidden in ["image", "video", "audio", "landmark", "joint", "frame", "pixel"] {
            XCTAssertFalse(
                json.lowercased().contains(forbidden),
                "history JSON must not mention \(forbidden)"
            )
        }
    }
}
