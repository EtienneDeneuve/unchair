import XCTest
@testable import Unchair

/// #114 — high-signal privacy/security invariants for Mac standalone.
/// Broader suites stay in their dedicated files; this class locks the v1.0 gate set.
@MainActor
final class PrivacySecurityRegressionTests: XCTestCase {
    private let forbiddenTokens = [
        "landmark",
        "landmarks",
        "joint",
        "joints",
        "pixelbuffer",
        "pixel_buffer",
        "cvpixelbuffer",
        "image",
        "video",
        "audio",
        "frame",
        "mask",
        "biometric",
        "healthkit",
    ]

    func testBreakHistoryVerificationCodableKeysAreScalarsOnly() throws {
        let verification = BreakHistoryVerification(
            stoodForSeconds: 6,
            motionScore: 0.4,
            failedOpen: false
        )
        let data = try JSONEncoder().encode(verification)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            Set(["stoodForSeconds", "motionScore", "failedOpen"])
        )
        assertNoForbiddenTokens(in: String(decoding: data, as: UTF8.self), context: "verification JSON")
    }

    func testBreakHistoryRecordCodableKeysStayAllowlisted() throws {
        let record = BreakHistoryRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            breakID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_100),
            startedAt: Date(timeIntervalSince1970: 1_700_000_200),
            endedAt: Date(timeIntervalSince1970: 1_700_000_300),
            result: .completed,
            durationSeconds: 90,
            verification: BreakHistoryVerification(
                stoodForSeconds: 8,
                motionScore: 0.5,
                failedOpen: false
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(record)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(
            Set(object.keys),
            Set([
                "id",
                "recordedAt",
                "breakID",
                "scheduledAt",
                "startedAt",
                "endedAt",
                "result",
                "durationSeconds",
                "verification",
            ])
        )
        assertNoForbiddenTokens(in: String(decoding: data, as: UTF8.self), context: "history record JSON")
    }

    func testHumanRuntimeExportSurfaceStaysScalar() {
        let summary = HumanRuntimeWeeklySummary(
            weekNumber: 45,
            weekStart: Date(timeIntervalSince1970: 1_699_395_200),
            weekEndExclusive: Date(timeIntervalSince1970: 1_700_000_000),
            completedCount: 4,
            postponedCount: 2,
            skippedCount: 1,
            movementDebtPeakSeconds: 4_200,
            meanTimeToButtOffSeconds: 480,
            sittingSLOPercent: 80
        )
        // Compile/type surface: only the documented scalar fields.
        let fieldNames = Mirror(reflecting: summary).children.compactMap(\.label)
        XCTAssertEqual(
            Set(fieldNames),
            Set([
                "weekNumber",
                "weekStart",
                "weekEndExclusive",
                "completedCount",
                "postponedCount",
                "skippedCount",
                "movementDebtPeakSeconds",
                "meanTimeToButtOffSeconds",
                "sittingSLOPercent",
            ])
        )

        let lines = HumanRuntimeWeeklySummaryFormatting.cardLines(summary).joined(separator: "\n")
        assertNoForbiddenTokens(in: lines, context: "Human Runtime card lines")
        XCTAssertFalse(lines.localizedCaseInsensitiveContains("camera"))
        XCTAssertFalse(lines.localizedCaseInsensitiveContains("pose"))
        XCTAssertTrue(lines.contains("Sitting SLO"))
        XCTAssertTrue(lines.contains("Breaks completed"))
    }

    func testMQTTForbiddenCommandsNeverDispatch() {
        let router = MQTTCommandRouter()
        let performer = RejectRecordingPerformer()
        router.performer = performer

        for command in ["complete", "fake_movement", "verify", "mark_complete"] {
            let payload = Data(#"{"contractVersion":1,"command":"\#(command)"}"#.utf8)
            router.handle(payload: payload)
        }

        XCTAssertTrue(performer.commands.isEmpty)
        XCTAssertEqual(router.rejectedCount, 4)
    }

    func testMQTTPasswordNeverEncodedInConfigurationJSON() throws {
        var config = MQTTConfiguration.default
        config.isEnabled = true
        config.host = "broker.local"
        config.username = "ha"
        // Configuration is Codable without a password field — encode must stay clean.
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.localizedCaseInsensitiveContains("password"))
        assertNoForbiddenTokens(in: text, context: "MQTT configuration JSON")
    }

    func testPrivacyDocsAndRegressionMapStayAligned() throws {
        let privacy = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/PRIVACY.md")), encoding: .utf8)
        let map = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("docs/privacy-security-regression.md")),
            encoding: .utf8
        )

        for needle in [
            "Keychain",
            "allowlist",
            "failedOpen",
            "Human Runtime",
            "Degraded path",
        ] {
            XCTAssertTrue(
                privacy.localizedCaseInsensitiveContains(needle),
                "PRIVACY.md should mention \(needle)"
            )
        }

        for suite in [
            "FramePipelineTests",
            "BreakHistoryStoreTests",
            "MQTTCommandTests",
            "MQTTClientTests",
            "HumanRuntimeWeeklySummaryTests",
            "PrivacySecurityRegressionTests",
        ] {
            XCTAssertTrue(map.contains(suite), "regression map should list \(suite)")
        }
    }

    func testThreatModelMentionsLocalCompletionNotMQTT() throws {
        let privacy = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/PRIVACY.md")), encoding: .utf8)
        XCTAssertTrue(privacy.localizedCaseInsensitiveContains("mark complete"))
        XCTAssertTrue(privacy.localizedCaseInsensitiveContains("MQTT"))
        XCTAssertTrue(privacy.localizedCaseInsensitiveContains("power-suspend"))
        XCTAssertTrue(privacy.localizedCaseInsensitiveContains("Keychain"))
        XCTAssertTrue(privacy.localizedCaseInsensitiveContains("fake_movement")
            || privacy.localizedCaseInsensitiveContains("fake verification"))
    }

    // MARK: - Helpers

    private func assertNoForbiddenTokens(in text: String, context: String) {
        let lowered = text.lowercased()
        for token in forbiddenTokens {
            XCTAssertFalse(
                lowered.contains(token),
                "\(context) must not contain \(token)"
            )
        }
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

@MainActor
private final class RejectRecordingPerformer: MQTTCommandPerforming {
    private(set) var commands: [MQTTAcceptedCommand] = []
    func performMQTTCommand(_ command: MQTTAcceptedCommand) {
        commands.append(command)
    }
}
