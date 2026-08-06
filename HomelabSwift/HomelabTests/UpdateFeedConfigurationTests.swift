import XCTest
@testable import Homelab

final class UpdateFeedConfigurationTests: XCTestCase {

    func testEmptyManifestDisablesRemoteUpdates() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: ""
        ])
        XCTAssertNil(UpdateFeedConfiguration.manifestURL(from: info))
        XCTAssertFalse(UpdateFeedConfiguration.isRemoteUpdateConfigured(in: info))
    }

    func testThisForkBundleIsAllowed() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: UpdateFeedConfiguration.thisForkManifestURLString,
            UpdateFeedConfiguration.expectedBundleIDInfoKey: UpdateFeedConfiguration.thisForkBundleID
        ])
        XCTAssertTrue(
            UpdateFeedConfiguration.isThisForkInstall(
                runningBundleID: "com.unitsung.myhomelab",
                info: info
            )
        )
        XCTAssertFalse(
            UpdateFeedConfiguration.isThisForkInstall(
                runningBundleID: "homelab.foreverhomelab",
                info: info
            ),
            "Upstream bundle id must never be treated as this fork"
        )
        XCTAssertFalse(
            UpdateFeedConfiguration.isThisForkInstall(
                runningBundleID: "com.homelab.homelab",
                info: info
            )
        )
    }

    func testFeedBundleIDMustMatchRunningApp() {
        XCTAssertTrue(
            UpdateFeedConfiguration.feedTargetsRunningApp(
                feedBundleID: "com.unitsung.myhomelab",
                runningBundleID: "com.unitsung.myhomelab"
            )
        )
        XCTAssertFalse(
            UpdateFeedConfiguration.feedTargetsRunningApp(
                feedBundleID: "com.unitsung.myhomelab",
                runningBundleID: "homelab.foreverhomelab"
            ),
            "Upstream install must ignore this fork's feed even if it downloads the JSON"
        )
        // Missing feed field still needs the local isThisForkInstall gate.
        XCTAssertTrue(
            UpdateFeedConfiguration.feedTargetsRunningApp(
                feedBundleID: nil,
                runningBundleID: "com.unitsung.myhomelab"
            )
        )
    }

    func testConfiguredManifestURLForThisFork() {
        let info = InfoDictionaryStub(values: [
            UpdateFeedConfiguration.manifestInfoKey: UpdateFeedConfiguration.thisForkManifestURLString,
            UpdateFeedConfiguration.defaultPageInfoKey: UpdateFeedConfiguration.thisForkDefaultPageURLString
        ])
        XCTAssertEqual(
            UpdateFeedConfiguration.manifestURL(from: info)?.absoluteString,
            UpdateFeedConfiguration.thisForkManifestURLString
        )
        XCTAssertFalse(
            UpdateFeedConfiguration.manifestURL(from: info)?
                .absoluteString
                .contains("JohnnWi") == true
        )
    }
}

private struct InfoDictionaryStub: InfoDictionaryProviding {
    let values: [String: String]

    func object(forInfoDictionaryKey key: String) -> Any? {
        values[key]
    }
}
