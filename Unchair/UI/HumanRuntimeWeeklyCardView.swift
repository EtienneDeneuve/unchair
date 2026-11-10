import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders the weekly Human Runtime card and exports a local PNG (no network).
struct HumanRuntimeWeeklyCardView: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String = "github.com/EtienneDeneuve/unchair"

    @State private var exportStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardPreview
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button("Copy image") {
                    exportStatus = copyPNG() ? "Copied to clipboard." : "Copy failed."
                }
                .disabled(summary.isEmpty)

                Button("Save PNG…") {
                    exportStatus = savePNG() ? "Saved." : "Save cancelled."
                }
                .disabled(summary.isEmpty)

                Spacer()
            }

            if let exportStatus {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Built only from local break history on this Mac. No camera, health, or identity data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardPreview: some View {
        HumanRuntimeWeeklyCardCanvas(summary: summary, projectURL: projectURL)
            .frame(width: 420, height: 280)
    }

    private func renderImage() -> NSImage? {
        HumanRuntimeWeeklyCardExporter.image(summary: summary, projectURL: projectURL, size: CGSize(width: 840, height: 560))
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

struct HumanRuntimeWeeklyCardCanvas: View {
    let summary: HumanRuntimeWeeklySummary
    var projectURL: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: NSColor(calibratedWhite: 0.08, alpha: 1))
            Rectangle()
                .fill(Color(nsColor: NSColor(calibratedRed: 0.91, green: 0.89, blue: 0.84, alpha: 1)))
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 10) {
                Text("HUMAN RUNTIME — WEEK \(summary.weekNumber)")
                    .font(.system(.headline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color(nsColor: .white))

                if summary.isEmpty {
                    Text("No break history this week yet.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(nsColor: NSColor(calibratedWhite: 0.7, alpha: 1)))
                } else {
                    metricRow("Sitting SLO", HumanRuntimeWeeklySummaryFormatting.sittingSLO(summary.sittingSLOPercent))
                    metricRow("Movement debt peak", "\(summary.movementDebtPeakMinutesRounded)m")
                    metricRow("Breaks completed", "\(summary.completedCount)")
                    metricRow("Breaks postponed", "\(summary.postponedCount)")
                    if let mttb = summary.meanTimeToButtOffSeconds {
                        metricRow("MTTB", HumanRuntimeWeeklySummaryFormatting.duration(mttb))
                    }
                    if let sev = summary.sevLine {
                        Text(sev)
                            .font(.system(.caption, design: .monospaced).weight(.medium))
                            .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.45, alpha: 1)))
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Text("Unchair")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                    Spacer()
                    Text(projectURL)
                        .font(.system(.caption2, design: .monospaced))
                        .opacity(0.7)
                }
                .foregroundStyle(Color(nsColor: NSColor(calibratedWhite: 0.75, alpha: 1)))
            }
            .padding(.leading, 22)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(nsColor: NSColor(calibratedWhite: 0.65, alpha: 1)))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(Color(nsColor: .white))
                .monospacedDigit()
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
