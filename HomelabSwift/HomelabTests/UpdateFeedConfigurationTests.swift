import XCTest
@testable import Homelab

final class UpdateFeedConfigurationTests: XCTestCase {

    func testMissingKeysDisablesRemoteUpdates() {
        let info = InfoDictionaryStub(values: [:])
        XCTAssertNil(UpdateFeedConfiguration.manifestURL(from: info))
        XCTAssertFalse(UpdateFeedConfiguration.isRemoteUpdateConfigured(in: info))
        XCTAssertEqual(UpdateFeedConfiguration.defaultPageURL(from: info), "")
    }

    func testEmptyManifestURLDisablesUpdateCheck() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: "   "
        ])
        XCTAssertNil(UpdateFeedConfiguration.manifestURL(from: info))
        XCTAssertFalse(UpdateFeedConfiguration.isRemoteUpdateConfigured(in: info))
    }

    func testExplicitManifestEnablesCheckWithoutPhoneHomeDefault() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: "https://example.com/private/version.json",
            UpdateFeedConfiguration.defaultPageInfoKey: "https://example.com/private/releases"
        ])
        XCTAssertEqual(
            UpdateFeedConfiguration.manifestURL(from: info)?.absoluteString,
            "https://example.com/private/version.json"
        )
        XCTAssertEqual(
            UpdateFeedConfiguration.defaultPageURL(from: info),
            "https://example.com/private/releases"
        )
        XCTAssertTrue(UpdateFeedConfiguration.isRemoteUpdateConfigured(in: info))
        // Must never fall back to a hard-coded public repo.
        XCTAssertFalse(
            UpdateFeedConfiguration.manifestURL(from: info)?
                .absoluteString
                .contains("unitsung/homelab-project") == true
        )
    }
}

private struct InfoDictionaryStub: InfoDictionaryProviding {
    let values: [String: String]

    func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}
