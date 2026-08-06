import XCTest
@testable import Homelab

final class UpdateFeedConfigurationTests: XCTestCase {

    func testBuiltInDefaultsWhenKeysMissing() {
        let info = InfoDictionaryStub(values: [:])
        let url = UpdateFeedConfiguration.manifestURL(from: info)
        XCTAssertEqual(
            url?.absoluteString,
            UpdateFeedConfiguration.builtInManifestURLString
        )
        XCTAssertEqual(
            UpdateFeedConfiguration.defaultPageURL(from: info),
            UpdateFeedConfiguration.builtInDefaultPageURLString
        )
        XCTAssertFalse(url?.absoluteString.contains("JohnnWi") == true)
    }

    func testEmptyManifestURLDisablesUpdateCheck() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: "   "
        ])
        XCTAssertNil(UpdateFeedConfiguration.manifestURL(from: info))
    }

    func testCustomManifestAndDefaultPage() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: "https://example.com/version.json",
            UpdateFeedConfiguration.defaultPageInfoKey: "https://example.com/releases"
        ])
        XCTAssertEqual(
            UpdateFeedConfiguration.manifestURL(from: info)?.absoluteString,
            "https://example.com/version.json"
        )
        XCTAssertEqual(
            UpdateFeedConfiguration.defaultPageURL(from: info),
            "https://example.com/releases"
        )
    }
}

private struct InfoDictionaryStub: InfoDictionaryProviding {
    let values: [String: String]

    func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}
