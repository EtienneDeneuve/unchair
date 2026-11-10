import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Branded weekly Human Runtime surface (#85). Export lives in the Today footer when embedded.
struct HumanRuntimeWeeklyPanel: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String = "github.com/EtienneDeneuve/unchair"
    /// When false, Copy/Save are expected from the parent footer.
    var showsExport: Bool = true

    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Human Runtime · Week \(summary.weekNumber)")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Human Runtime, week \(summary.weekNumber)")

            if summary.isEmpty {
                Text("No break history this week yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    metric(
                        "Sitting SLO",
                        HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent),
                        accessibility: "Sitting SLO \(HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))"
                    )
                    metric(
                        "Debt peak",
                        HumanStatusFormatting.compactOrDash(summary.movementDebtPeakSeconds),
                        accessibility: "Movement debt peak \(HumanStatusFormatting.compactOrDash(summary.movementDebtPeakSeconds))"
                    )
                    metric(
                        "Completed",
                        "\(summary.completedCount)",
                        accessibility: "\(summary.completedCount) completed"
                    )
                    metric(
                        "Postponed",
                        "\(summary.postponedCount)",
                        accessibility: "\(summary.postponedCount) postponed"
                    )
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        metric(
                            "MTTB",
                            HumanStatusFormatting.friendlyDuration(mttb),
                            accessibility: "Mean time to butt-off \(HumanStatusFormatting.friendlyDuration(mttb))"
                        )
                    }
                }

                if let sev = summary.sevLine {
                    Text(sev)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                        .accessibilityLabel(sev)
                }
            }

            if showsExport {
                HStack(spacing: 10) {
                    Button("Copy Image") {
                        exportStatus = HumanRuntimeWeeklyExportActions.copyPNG(summary: summary, projectURL: projectURL)
                            ? "Copied" : "Failed"
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(summary.isEmpty)

                    Button("Save PNG…") {
                        exportStatus = HumanRuntimeWeeklyExportActions.savePNG(summary: summary, projectURL: projectURL)
                            ? "Saved" : "Cancelled"
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(summary.isEmpty)

                    if let exportStatus {
                        Text(exportStatus)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func metric(_ label: String, _ value: String, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }
}

@available(*, deprecated, renamed: "HumanRuntimeWeeklyPanel")
typealias HumanRuntimeWeeklySection = HumanRuntimeWeeklyPanel
@available(*, deprecated, renamed: "HumanRuntimeWeeklyPanel")
typealias HumanRuntimeWeeklyCardView = HumanRuntimeWeeklyPanel

/// Shared export helpers — UI chrome stays out of the PNG.
enum HumanRuntimeWeeklyExportActions {
    @MainActor
    static func copyPNG(summary: HumanRuntimeWeeklySummary, projectURL: String = "github.com/EtienneDeneuve/unchair") -> Bool {
        guard let image = HumanRuntimeWeeklyCardExporter.image(
            summary: summary,
            projectURL: projectURL,
            size: CGSize(width: 840, height: 520)
        ),
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setData(png, forType: .png)
    }

    @MainActor
    static func savePNG(summary: HumanRuntimeWeeklySummary, projectURL: String = "github.com/EtienneDeneuve/unchair") -> Bool {
        guard let image = HumanRuntimeWeeklyCardExporter.image(
            summary: summary,
            projectURL: projectURL,
            size: CGSize(width: 840, height: 520)
        ),
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else { return false }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "unchair-human-runtime-week-\(summary.weekNumber).png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try png.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

/// Shareable export canvas — readable when scaled; same metrics, no Form chrome.
struct HumanRuntimeWeeklyCardCanvas: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Human Runtime")
                        .font(.title2.weight(.semibold))
                    Text(weekRangeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text("Week \(summary.weekNumber)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            if summary.isEmpty {
                Text("No break history this week.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 14
                ) {
                    exportMetric("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                    exportMetric(
                        "Movement debt peak",
                        HumanStatusFormatting.compactOrDash(summary.movementDebtPeakSeconds)
                    )
                    exportMetric("Breaks completed", "\(summary.completedCount)")
                    exportMetric("Breaks postponed", "\(summary.postponedCount)")
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        exportMetric("MTTB", HumanStatusFormatting.friendlyDuration(mttb))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                if let sev = summary.sevLine {
                    Text(sev)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 16)
                }
            }

            Spacer(minLength: 16)

            HStack {
                Text("Unchair")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(projectURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var weekRangeLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: summary.weekStart) ?? summary.weekStart
        let startText = summary.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText)–\(endText)"
    }

    private func exportMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum HumanRuntimeWeeklyCardExporter {
    @MainActor
    static func image(summary: HumanRuntimeWeeklySummary, projectURL: String, size: CGSize) -> NSImage? {
        let view = HumanRuntimeWeeklyCardCanvas(summary: summary, projectURL: projectURL)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
