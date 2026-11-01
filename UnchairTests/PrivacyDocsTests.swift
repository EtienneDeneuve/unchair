import ImageIO
import XCTest

final class PrivacyDocsTests: XCTestCase {
    func testPrivacyDocumentExistsAndCoversRequiredTopics() throws {
        let url = try XCTUnwrap(Self.repoFile("docs/PRIVACY.md"))
        let text = try String(contentsOf: url, encoding: .utf8)

        for needle in [
            "ephemeral",
            "Camera data flow",
            "never persisted",
            "Network behavior",
            "Permissions",
            "Debug logging",
            "landmarks",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "PRIVACY.md should mention \(needle)"
            )
        }
    }


    func testDocumentationMediaHasNoSensitiveMetadataAndStaysSmall() throws {
        let assets = try XCTUnwrap(Self.repoFile("docs/assets"))
        let files = try FileManager.default.contentsOfDirectory(
            at: assets,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )

        let screenshots = try FileManager.default.contentsOfDirectory(
            at: assets.appendingPathComponent("screenshots"),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        let media = (files + screenshots).filter {
            ["png", "gif"].contains($0.pathExtension.lowercased())
        }

        XCTAssertFalse(media.isEmpty, "README media assets should exist")

        var totalBytes = 0

        for url in media {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let size = values.fileSize ?? 0
            totalBytes += size

            if url.lastPathComponent == "unchair-tour.gif" {
                XCTAssertLessThan(
                    size,
                    1_000_000,
                    "Hero GIF should stay below 1 MB"
                )
            }

            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let properties = try XCTUnwrap(
                CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            )

            for forbiddenKey in [
                kCGImagePropertyExifDictionary,
                kCGImagePropertyGPSDictionary,
                kCGImagePropertyIPTCDictionary,
                kCGImagePropertyTIFFDictionary,
            ] {
                XCTAssertNil(
                    properties[forbiddenKey],
                    "\(url.lastPathComponent) must not contain \(forbiddenKey) metadata"
                )
            }
        }

        XCTAssertLessThan(
            totalBytes,
            2_000_000,
            "README documentation media should stay below 2 MB total"
        )
    }

    func testReadmeLinksToPrivacyDocument() throws {
        let url = try XCTUnwrap(Self.repoFile("README.md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("docs/PRIVACY.md"))
    }

    private static func repoFile(_ relative: String) -> URL? {
        // UnchairTests/PrivacyDocsTests.swift → repo root
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // UnchairTests
        url.deleteLastPathComponent() // repo root
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
