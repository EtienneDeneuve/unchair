import XCTest
@testable import Unchair

final class OpenMetricsTests: XCTestCase {
    func testMetricNamesMatchContract() {
        let expected = [
            "unchair_breaks_completed_total",
            "unchair_breaks_skipped_total",
            "unchair_breaks_postponed_total",
            "unchair_movement_seconds_total",
            "unchair_movement_debt_seconds",
            "unchair_current_sitting_seconds",
            "unchair_sitting_slo_ratio",
            "unchair_presentation_mode",
        ]
        XCTAssertEqual(OpenMetricsRegistry.Name.allCases.map(\.rawValue), expected)
    }

    func testEventSinkIncrementsCountersWithoutLabels() {
        let registry = OpenMetricsRegistry()
        let sink = OpenMetricsEventSink(registry: registry)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        sink.receive(
            DomainEvent(
                name: .breakCompleted,
                occurredAt: now,
                breakID: UUID(),
                payload: .breakCompleted(stoodForSeconds: 90, motionScore: 0.8, failedOpen: false)
            )
        )
        sink.receive(
            DomainEvent(name: .breakSkipped, occurredAt: now, breakID: nil, payload: .breakSkipped)
        )
        sink.receive(
            DomainEvent(
                name: .breakPostponed,
                occurredAt: now,
                breakID: nil,
                payload: .breakPostponed(until: now.addingTimeInterval(900))
            )
        )

        XCTAssertEqual(registry.counterValue(.breaksCompletedTotal), 1)
        XCTAssertEqual(registry.counterValue(.breaksSkippedTotal), 1)
        XCTAssertEqual(registry.counterValue(.breaksPostponedTotal), 1)
        XCTAssertEqual(registry.counterValue(.movementSecondsTotal), 90)

        let text = OpenMetricsTextEncoder.encode(registry.snapshot())
        XCTAssertTrue(text.contains("unchair_breaks_completed_total 1"))
        XCTAssertTrue(text.contains("unchair_movement_seconds_total 90"))
        XCTAssertFalse(text.contains("{"))
        XCTAssertTrue(text.contains("# TYPE unchair_breaks_completed_total counter"))
        XCTAssertTrue(text.contains("# EOF"))
    }

    @MainActor
    func testSittingSLORatioUsesTodayCounts() {
        let controller = OpenMetricsController(configuration: .default)
        controller.refreshGauges(
            debtSeconds: 120,
            sittingSeconds: 600,
            presentationEnabled: true,
            todayCompleted: 3,
            todaySkipped: 1
        )
        let snap = controller.registry.snapshot()
        XCTAssertEqual(snap.gauges[.movementDebtSeconds], 120)
        XCTAssertEqual(snap.gauges[.currentSittingSeconds], 600)
        XCTAssertEqual(snap.gauges[.presentationMode], 1)
        XCTAssertEqual(snap.gauges[.sittingSLORatio]!, 0.75, accuracy: 0.0001)
    }

    func testConfigurationDefaultsAreSafe() {
        let config = OpenMetricsConfiguration.default
        XCTAssertFalse(config.isEnabled)
        XCTAssertEqual(config.port, 9108)
        XCTAssertFalse(config.allowLANExposure)
        XCTAssertEqual(config.bindHost, "127.0.0.1")
    }
}
