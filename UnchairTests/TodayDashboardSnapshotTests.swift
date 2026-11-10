import AppKit
import SwiftUI
import XCTest
@testable import Unchair

/// Renders a fixture Today dashboard PNG for PR visual review (#85 density pass).
final class TodayDashboardSnapshotTests: XCTestCase {
    @MainActor
    func testRenderDensityPassFixturePNG() throws {
        let weekStart = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        let week = HumanRuntimeWeeklySummary(
            weekNumber: 46,
            weekStart: weekStart,
            weekEndExclusive: weekStart.addingTimeInterval(7 * 86_400),
            completedCount: 0,
            postponedCount: 0,
            skippedCount: 1, // matches live before-shot; keeps week panel non-empty
            movementDebtPeakSeconds: 0,
            meanTimeToButtOffSeconds: nil,
            sittingSLOPercent: 0
        )
        // Match the live before-screenshot numbers for an honest before/after.
        let model = TodayDashboardModel(
            heroEyebrow: "Movement debt",
            heroValue: "50h 38m",
            heroCaption: "Postpone keeps debt. Complete clears it.",
            nextAction: "Next break in 16 min",
            todayCompleted: 0,
            todaySkipped: 1,
            todayMovedMinutes: 0,
            todayLongest: "50h 38m",
            week: week,
            dayLabel: "Tue 10 Nov"
        )

        let view = TodayDashboardLayout(model: model, onCopyImage: { nil }, onSavePNG: { nil })
            .frame(width: 420)
            .fixedSize(horizontal: true, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor))

        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: CGSize(width: 420, height: max(size.height, 1)))

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("No bitmap rep")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG encode failed")
            return
        }

        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UnchairTests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("docs/assets/today-ui", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let out = outDir.appendingPathComponent("today-after.png")
        try png.write(to: out, options: .atomic)

        XCTAssertGreaterThan(png.count, 1_000)
        XCTAssertLessThan(hosting.bounds.height, 620, "Dashboard should stay within ~500–600px intentional height")
        XCTAssertGreaterThan(hosting.bounds.height, 360)
    }
}
