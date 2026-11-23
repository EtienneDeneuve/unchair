import AppKit
import SwiftUI
import XCTest
@testable import Unchair

/// Guards the dual-display fullscreen contract: one borderless panel per
/// `NSScreen.frame`, with `NSHostingView` sized by AppKit — not SwiftUI intrinsic size.
@MainActor
final class BreakOverlayFullscreenTests: XCTestCase {
    func testHostingViewDisablesIntrinsicSizingSoPanelCanFillScreen() {
        let model = BreakOverlayModel.active(
            remaining: .seconds(60),
            verificationStatus: .verificationOptedOut,
            canComplete: true
        )
        let view = BreakOverlayView(
            model: model,
            onPrimary: {},
            onSkip: {},
            onPostpone15: {},
            onQuit: {}
        )
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        XCTAssertTrue(hosting.sizingOptions.isEmpty)
        XCTAssertEqual(hosting.autoresizingMask, [.width, .height])
    }

    func testPanelFrameMatchesScreenFrameForEachDisplay() {
        let screens = NSScreen.screens
        XCTAssertFalse(screens.isEmpty, "test host must have at least one display")
        for screen in screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.setFrame(screen.frame, display: false)
            XCTAssertEqual(panel.frame.origin.x, screen.frame.origin.x, accuracy: 0.5)
            XCTAssertEqual(panel.frame.origin.y, screen.frame.origin.y, accuracy: 0.5)
            XCTAssertEqual(panel.frame.size.width, screen.frame.size.width, accuracy: 0.5)
            XCTAssertEqual(panel.frame.size.height, screen.frame.size.height, accuracy: 0.5)
            panel.close()
        }
    }
}
