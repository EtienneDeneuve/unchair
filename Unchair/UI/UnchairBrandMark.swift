import AppKit
import SwiftUI

/// Compact Unchair wordmark + app icon for Today / share cards (#85).
struct UnchairBrandMark: View {
    var iconSide: CGFloat = 18
    var titleFont: Font = .subheadline.weight(.semibold)
    var showsTitle: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            UnchairAppIcon(side: iconSide)
            if showsTitle {
                Text("Unchair")
                    .font(titleFont)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unchair")
    }
}

struct UnchairAppIcon: View {
    var side: CGFloat

    var body: some View {
        Group {
            if let image = Self.resolvedIcon() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: side * 0.7, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private static func resolvedIcon() -> NSImage? {
        if let app = NSApp.applicationIconImage, app.size.width > 0 {
            return app
        }
        if let named = NSImage(named: "AppIcon"), named.size.width > 0 {
            return named
        }
        // Bundled icns used by the Direct build / Finder.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }
        return nil
    }
}
