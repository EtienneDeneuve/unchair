import AppKit
import SwiftUI
import XCTest
@testable import Unchair

/// Renders final #85 gallery PNGs for PR visual review.
final class TodayDashboardSnapshotTests: XCTestCase {
    @MainActor
    func testRenderFinalGallery() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/assets/today-ui", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let cases: [(String, TodayDashboardModel, ColorScheme)] = [
            ("today-light.png", Self.realisticModel(), .light),
            ("today-dark.png", Self.realisticModel(), .dark),
            ("today-realistic.png", Self.realisticModel(), .light),
            ("today-pathological.png", Self.pathologicalModel(), .light),
        ]

        for (name, model, scheme) in cases {
            let png = try Self.render(model: model, scheme: scheme)
            try png.write(to: outDir.appendingPathComponent(name), options: .atomic)
            XCTAssertGreaterThan(png.count, 1_000, name)
        }

        // Keep density-pass filenames current for older PR links.
        let after = outDir.appendingPathComponent("today-after.png")
        try FileManager.default.copyItem(
            at: outDir.appendingPathComponent("today-realistic.png"),
            to: after.appendingPathExtension("tmp")
        )
        _ = try? FileManager.default.removeItem(at: after)
        try FileManager.default.moveItem(
            at: after.appendingPathExtension("tmp"),
            to: after
        )
    }

    @MainActor
    func testPathologicalHeroDoesNotExceedUtilityWidth() throws {
        let hosting = NSHostingView(
            rootView: TodayDashboardLayout(
                model: Self.pathologicalModel(),
                onCopyImage: { nil },
                onSavePNG: { nil }
            )
            .frame(width: 420)
            .fixedSize(horizontal: true, vertical: true)
        )
        let size = hosting.fittingSize
        XCTAssertEqual(size.width, 420, accuracy: 1)
        XCTAssertLessThan(size.height, 620)
    }

    // MARK: - Fixtures

    private static func week(
        number: Int = 46,
        completed: Int,
        postponed: Int,
        skipped: Int,
        debtPeak: TimeInterval,
        mttb: TimeInterval?,
        slo: Double
    ) -> HumanRuntimeWeeklySummary {
        let weekStart = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        return HumanRuntimeWeeklySummary(
            weekNumber: number,
            weekStart: weekStart,
            weekEndExclusive: weekStart.addingTimeInterval(7 * 86_400),
            completedCount: completed,
            postponedCount: postponed,
            skippedCount: skipped,
            movementDebtPeakSeconds: debtPeak,
            meanTimeToButtOffSeconds: mttb,
            sittingSLOPercent: slo
        )
    }

    private static func realisticModel() -> TodayDashboardModel {
        TodayDashboardModel(
            heroEyebrow: "At desk",
            heroValue: "42 min",
            heroCaption: "Longest session 1h 12m",
            nextAction: "Next break in 18 min",
            todayCompleted: 3,
            todaySkipped: 1,
            todayMovedMinutes: 14,
            todayLongest: "1h 12m",
            week: week(
                completed: 8,
                postponed: 3,
                skipped: 2,
                debtPeak: 2 * 3600 + 15 * 60,
                mttb: 7 * 60,
                slo: 80.0
            ),
            dayLabel: "Tue 10 Nov"
        )
    }

    private static func pathologicalModel() -> TodayDashboardModel {
        TodayDashboardModel(
            heroEyebrow: "Movement debt",
            heroValue: "50h 38m",
            heroCaption: "Postpone keeps debt. Complete clears it.",
            nextAction: "Next break in 16 min",
            todayCompleted: 0,
            todaySkipped: 4,
            todayMovedMinutes: 0,
            todayLongest: "50h 38m",
            week: week(
                completed: 1,
                postponed: 12,
                skipped: 6,
                debtPeak: 50 * 3600 + 38 * 60,
                mttb: 48 * 60,
                slo: 14.3
            ),
            dayLabel: "Tue 10 Nov"
        )
    }

    @MainActor
    private static func render(model: TodayDashboardModel, scheme: ColorScheme) throws -> Data {
        let root = TodayDashboardLayout(model: model, onCopyImage: { nil }, onSavePNG: { nil })
            .frame(width: 420)
            .fixedSize(horizontal: true, vertical: true)
            .padding(1)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)

        let hosting = NSHostingView(rootView: root)
        let fitted = hosting.fittingSize
        let size = CGSize(width: 420, height: max(fitted.height, 1))
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw NSError(domain: "TodaySnapshot", code: 1)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "TodaySnapshot", code: 2)
        }
        return png
    }
}
