import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Weekly Human Runtime block inside Today — same visual language as the daily metrics.
struct HumanRuntimeWeeklyCardView: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String = "github.com/EtienneDeneuve/unchair"

    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Week \(summary.weekNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if summary.isEmpty {
                Text("No break history this week yet.")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                    GridRow {
                        metric("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                        metric("Debt peak", "\(summary.movementDebtPeakMinutesRounded) min")
                    }
                    GridRow {
                        metric("Completed", "\(summary.completedCount)")
                        metric("Postponed", "\(summary.postponedCount)")
                    }
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        GridRow {
                            metric("MTTB", HumanRuntimeWeeklySummaryFormatting.duration(mttb))
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }

                if let sev = summary.sevLine {
                    Text(sev)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                Button("Copy image") {
                    exportStatus = copyPNG() ? "Copied." : "Copy failed."
                }
                .disabled(summary.isEmpty)

                Button("Save PNG…") {
                    exportStatus = savePNG() ? "Saved." : "Cancelled."
                }
                .disabled(summary.isEmpty)

                if let exportStatus {
                    Text(exportStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Local history only. No camera, health, or identity. Subtle share card for humans who enjoy bad SRE jokes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renderImage() -> NSImage? {
        HumanRuntimeWeeklyCardExporter.image(
            summary: summary,
            projectURL: projectURL,
            size: CGSize(width: 840, height: 520)
        )
    }

    private func copyPNG() -> Bool {
        guard let image = renderImage(),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setData(png, forType: .png)
    }

    private func savePNG() -> Bool {
        guard let image = renderImage(),
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

/// Shareable export canvas — light card, readable when scaled down. Not a fake terminal.
struct HumanRuntimeWeeklyCardCanvas: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: NSColor(calibratedWhite: 0.98, alpha: 1))

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Human Runtime")
                        .font(.system(size: 28, weight: .semibold))
                    Spacer()
                    Text("Week \(summary.weekNumber)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if summary.isEmpty {
                    Text("No break history this week.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        exportRow("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                        exportRow("Movement debt peak", "\(summary.movementDebtPeakMinutesRounded) min")
                        exportRow("Breaks completed", "\(summary.completedCount)")
                        exportRow("Breaks postponed", "\(summary.postponedCount)")
                        if let mttb = summary.meanTimeToButtOffSeconds {
                            exportRow("MTTB", HumanRuntimeWeeklySummaryFormatting.duration(mttb))
                        }
                    }

                    if let sev = summary.sevLine {
                        Text(sev)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Text("Unchair")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(projectURL)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .foregroundStyle(Color.primary)
        }
    }

    private func exportRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
        }
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
