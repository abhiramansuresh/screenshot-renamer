import XCTest
@testable import ScreenRenamer

final class WindowMetadataProviderTests: XCTestCase {
    func testMockedWindowPopulatesMetadataFields() {
        let provider = WindowMetadataProvider {
            WindowMetadataSnapshot(
                appName: "Xcode",
                windowTitle: "Screen Renamer",
                documentName: "file:///Users/example/Projects/screenshot_renamer/Screen%20Renamer.xcodeproj"
            )
        }

        let metadata = provider.metadata()

        XCTAssertEqual(metadata?.appName, "Xcode")
        XCTAssertEqual(metadata?.windowTitle, "Screen Renamer")
        XCTAssertEqual(metadata?.documentName, "Screen Renamer.xcodeproj")
    }

    func testBlankAppNameReturnsNilMetadata() {
        let provider = WindowMetadataProvider {
            WindowMetadataSnapshot(
                appName: "   ",
                windowTitle: "Manual Curriculum Pipeline Inspector",
                documentName: nil
            )
        }

        XCTAssertNil(provider.metadata())
    }
}
