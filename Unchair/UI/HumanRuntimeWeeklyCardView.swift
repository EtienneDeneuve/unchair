import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Branded weekly Human Runtime surface + secondary export actions (#85).
struct HumanRuntimeWeeklyPanel: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String = "github.com/EtienneDeneuve/unchair"

    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Human Runtime · Week \(summary.weekNumber)")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            if summary.isEmpty {
                Text("No break history this week yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    weekRow("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                    Divider().opacity(0.25)
                    weekRow(
                        "Debt peak",
                        HumanStatusFormatting.friendlyDuration(summary.movementDebtPeakSeconds)
                    )
                    Divider().opacity(0.25)
                    weekRow("Completed", "\(summary.completedCount)")
                    Divider().opacity(0.25)
                    weekRow("Postponed", "\(summary.postponedCount)")
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        Divider().opacity(0.25)
                        weekRow("MTTB", HumanStatusFormatting.friendlyDuration(mttb))
                    }
                }

                if let sev = summary.sevLine {
                    Text(sev)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 10) {
                Button("Copy Image") {
                    exportStatus = copyPNG() ? "Copied" : "Failed"
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(summary.isEmpty)

                Button("Save PNG…") {
                    exportStatus = savePNG() ? "Saved" : "Cancelled"
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(summary.isEmpty)

                if let exportStatus {
                    Text(exportStatus)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func weekRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 6)
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

@available(*, deprecated, renamed: "HumanRuntimeWeeklyPanel")
typealias HumanRuntimeWeeklySection = HumanRuntimeWeeklyPanel
@available(*, deprecated, renamed: "HumanRuntimeWeeklyPanel")
typealias HumanRuntimeWeeklyCardView = HumanRuntimeWeeklyPanel

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
                VStack(spacing: 0) {
                    exportRow("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                    Divider().opacity(0.35)
                    exportRow(
                        "Movement debt peak",
                        HumanStatusFormatting.friendlyDuration(summary.movementDebtPeakSeconds)
                    )
                    Divider().opacity(0.35)
                    exportRow("Breaks completed", "\(summary.completedCount)")
                    Divider().opacity(0.35)
                    exportRow("Breaks postponed", "\(summary.postponedCount)")
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        Divider().opacity(0.35)
                        exportRow("MTTB", HumanStatusFormatting.friendlyDuration(mttb))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
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

    private func exportRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
