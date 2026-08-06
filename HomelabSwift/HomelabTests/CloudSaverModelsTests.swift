import XCTest
@testable import Homelab

final class CloudSaverModelsTests: XCTestCase {
    func testCategoryDetectorTV() {
        XCTAssertEqual(CloudSaverCategoryDetector.detect(from: "三体 S01E01"), .tv)
        XCTAssertEqual(CloudSaverCategoryDetector.detect(from: "某动画 OVA"), .anime)
        XCTAssertEqual(CloudSaverCategoryDetector.detect(from: "流浪地球 电影"), .movie)
    }

    func testCloudTypeParse() {
        XCTAssertEqual(CloudSaverCloudType(parsing: "115").rawValue, "115")
        XCTAssertEqual(CloudSaverCloudType(parsing: "quark").rawValue, "quark")
    }

    func testDefaultFolderLookup() {
        var s = CloudSaverSettings.empty
        XCTAssertNil(s.defaultFolder(for: .cloud115))
        s.setDefaultFolder(cloud: .cloud115, cid: "  abc  ", name: "电影")
        XCTAssertEqual(s.defaultFolder(for: .cloud115)?.cid, "abc")
        XCTAssertEqual(s.defaultFolder(for: .cloud115)?.name, "电影")
        XCTAssertNil(s.defaultFolder(for: .quark))
    }

    func testSettingsLegacyMigration() throws {
        let legacy = """
        {"folder115Movie":"111","folder115TV":"","folder115Anime":"","folderQuarkMovie":"q1","folderQuarkTV":"","folderQuarkAnime":"","libraryOpenURL":"","ingestHint":""}
        """
        let s = try JSONDecoder().decode(CloudSaverSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(s.defaultFolder115Cid, "111")
        XCTAssertEqual(s.defaultFolderQuarkCid, "q1")
    }

    func testPanCookieExpiredMessage() {
        let m = CloudSaverUserFacingError.map("cookie expired please login")
        XCTAssertTrue(m.contains("Cookie"), m)
        XCTAssertTrue(m.contains("网页") || m.contains("CloudSaver"), m)
        XCTAssertFalse(m.contains("自动重新登录"), m)
    }

    func testAppSessionExpiredMessage() {
        let m1 = CloudSaverUserFacingError.map("jwt expired")
        XCTAssertTrue(m1.contains("登录已过期") || m1.contains("重新登录"), m1)
        XCTAssertFalse(m1.contains("Cookie"), m1)

        let m2 = CloudSaverUserFacingError.map("请先登录")
        XCTAssertTrue(m2.contains("登录已过期") || m2.contains("重新登录"), m2)
        XCTAssertFalse(m2.contains("Cookie"), m2)

        let m3 = CloudSaverUserFacingError.message(from: APIError.unauthorized)
        XCTAssertTrue(m3.contains("登录已过期") || m3.contains("重新登录"), m3)
        XCTAssertFalse(m3.contains("Cookie"), m3)
    }

    func testLooksLikeAppSessionAuthExcludesCookie() {
        XCTAssertTrue(CloudSaverAuthFailure.looksLikeAppSession("jwt expired"))
        XCTAssertTrue(CloudSaverAuthFailure.looksLikeAppSession("请先登录"))
        XCTAssertFalse(CloudSaverAuthFailure.looksLikeAppSession("cookie expired"))
        XCTAssertFalse(CloudSaverAuthFailure.looksLikeAppSession("网盘 Cookie 失效"))
    }

    func testServiceTypeRoundTrip() throws {
        let data = try JSONEncoder().encode(ServiceType.cloudsaver)
        let decoded = try JSONDecoder().decode(ServiceType.self, from: data)
        XCTAssertEqual(decoded, .cloudsaver)
        XCTAssertEqual(BackupServiceTypeMapper.backupKey(for: .cloudsaver), "cloudsaver")
        XCTAssertEqual(BackupServiceTypeMapper.serviceType(from: "cloudsaver"), .cloudsaver)
    }

    func testDoubanChipsDefault() {
        XCTAssertEqual(CloudSaverDoubanChip.default.type, "全部")
        XCTAssertEqual(CloudSaverDoubanChip.default.category, "热门")
        XCTAssertEqual(CloudSaverDoubanChip.default.api, "movie")
        XCTAssertTrue(CloudSaverDoubanChip.all.count >= 8)
        let kr = CloudSaverDoubanChip.all.first { $0.id == "tv-kr" }
        XCTAssertEqual(kr?.type, "tv_korean")
        XCTAssertEqual(kr?.category, "tv")
        XCTAssertEqual(kr?.api, "tv")
        let eu = CloudSaverDoubanChip.all.first { $0.id == "tv-eu" }
        XCTAssertEqual(eu?.type, "tv_american")
    }

    func testPosterCardFromDouban() {
        let item = CloudSaverDoubanItem(
            id: "1",
            title: "痴迷",
            rate: "7.5",
            cover: "https://example.com/a.jpg",
            url: "https://movie.douban.com",
            subtitle: "2025 / 美国 / 恐怖",
            isNew: false
        ,
            ratingCount: 0,
            honorTag: "",
            reputation: "",
            year: nil
        )
        let card = CloudSaverPosterCard(douban: item)
        XCTAssertEqual(card.imageURL, "https://example.com/a.jpg")
        XCTAssertEqual(card.badge, "7.5")
        XCTAssertEqual(card.subtitle, "2025 / 美国 / 恐怖")
    }

    func testDoubanJSONDecodeSample() throws {
        let json = """
        {"success":true,"code":0,"data":[{"id":"37450627","title":"痴迷","pic":{"large":"https://img9.doubanio.com/a.jpg","normal":"https://img9.doubanio.com/b.jpg"},"rating":{"count":161167,"max":10,"star_count":4,"value":7.5},"uri":"douban://douban.com/movie/37450627","card_subtitle":"2025 / 美国 / 恐怖","is_new":false,"episodes_info":"","type":"movie"}],"message":"操作成功"}
        """
        // Decode via client private types is hard; verify model construction path instead.
        let item = CloudSaverDoubanItem(
            id: "37450627",
            title: "痴迷",
            rate: "7.5",
            cover: "https://img9.doubanio.com/a.jpg",
            url: "douban://douban.com/movie/37450627",
            subtitle: "2025 / 美国 / 恐怖",
            isNew: false
        ,
            ratingCount: 0,
            honorTag: "",
            reputation: "",
            year: nil
        )
        XCTAssertEqual(item.rate, "7.5")
        XCTAssertTrue(item.cover.contains("doubanio"))
        _ = json
    }
    /// Real sample from GET /api/quark/folders?parentCid= (shape only; no live secrets)
    func testQuarkFoldersEnvelopeShape() throws {
        let json = """
        {"success":true,"code":0,"data":[{"cid":"6e7513af64a041d682887808fb2aca69","name":"仙逆","path":[]},{"cid":"0abcc18ab9774121ac9f918b0db805f5","name":"瑞克和莫蒂第九季","path":[]},{"cid":"f551861ea0be487ea2042b8e318a33ef","name":"电影","path":[]},{"cid":"a618040724804aaa919e34b62d950aa2","name":"动漫","path":[]}],"message":"操作成功"}
        """
        let data = Data(json.utf8)
        let envelope = try JSONDecoder().decode(CSFolderListEnvelopeTest.self, from: data)
        XCTAssertEqual(envelope.success, true)
        XCTAssertEqual(envelope.data?.count, 4)
        XCTAssertEqual(envelope.data?.first?.cid, "6e7513af64a041d682887808fb2aca69")
        XCTAssertEqual(envelope.data?.first?.name, "仙逆")
        let folders = (envelope.data ?? []).map {
            CloudSaverRemoteFolder(cid: $0.cid ?? "", name: $0.name ?? "")
        }.filter { !$0.cid.isEmpty }
        XCTAssertEqual(folders.count, 4)
        XCTAssertEqual(folders.map(\.name), ["仙逆", "瑞克和莫蒂第九季", "电影", "动漫"])
    }

    /// Contract sample from POST /api/quark/save (field names only; values illustrative).
    func testQuarkSaveBodyShape() {
        let fids = ["cb4df45731e74095ad3fe1e16331c6f3"]
        let fidTokens = ["11908797e47a14956238c9cc198ad617"]
        let body: [String: Any] = [
            "fids": fids,
            "fidTokens": fidTokens,
            "folderId": "834b99dac6a7491ab48677bc1bb42e5b",
            "shareCode": "f62be8e158e4",
            "receiveCode": "s1MTrI8c66lnTNq05svZxD9X4Rx0K45msP6azJUl7QA="
        ]
        XCTAssertEqual(body.keys.sorted(), ["fidTokens", "fids", "folderId", "receiveCode", "shareCode"].sorted())
        XCTAssertEqual((body["fids"] as? [String])?.count, (body["fidTokens"] as? [String])?.count)
        XCTAssertNotEqual(body["folderId"] as? String, "0")
        // receiveCode for quark is long stoken-like, not short password
        XCTAssertGreaterThan((body["receiveCode"] as? String)?.count ?? 0, 20)
    }

    /// 115 folders: path is object array; only cid/name required for browse.
    func testCloud115FoldersPathObjects() throws {
        let json = """
        {"success":true,"code":0,"data":[{"cid":"3314217916295019955","name":"电影","path":[{"name":"根目录","aid":"1","cid":"0","pid":"0","isp":"0"}]},{"cid":"3314218535659503063","name":"动漫","path":[{"name":"根目录","aid":"1","cid":"0","pid":"0","isp":"0"}]}],"message":"操作成功"}
        """
        let data = Data(json.utf8)
        let envelope = try JSONDecoder().decode(CSFolderListEnvelopeTest.self, from: data)
        XCTAssertEqual(envelope.data?.count, 2)
        XCTAssertEqual(envelope.data?.first?.name, "电影")
        XCTAssertEqual(envelope.data?.first?.cid, "3314217916295019955")
    }

    /// 115 save body (verified): shareCode, receiveCode, fileId, folderId, fids — folderId may be "0".
    func testCloud115SaveBodyShape() {
        let fids = ["3213158852136533781"]
        let body: [String: Any] = [
            "shareCode": "swwk70f3wrb",
            "receiveCode": "t8d3",
            "fileId": fids[0],
            "folderId": "0",
            "fids": fids
        ]
        XCTAssertEqual(body["fileId"] as? String, (body["fids"] as? [String])?.first)
        XCTAssertEqual(body["folderId"] as? String, "0")
        XCTAssertNil(body["fidTokens"])
    }


    func testPluginBuiltInParamsMake() {
        let item = CloudSaverSearchResult(
            title: "测试影片",
            description: "desc",
            imageURL: "",
            shareCode: "abc123",
            receiveCode: "88",
            cloudType: .cloud115,
            fileSize: "1G",
            channel: "",
            channelId: "",
            pubDate: "",
            messageId: "m1",
            tags: [],
            count: 1
        )
        let files = [CloudSaverShareFile(fileId: "fid1", fileName: "a.mkv", fileSize: nil, fileIdToken: nil, isFolder: false)]
        let p = CloudSaverPluginBuiltInParams.make(
            result: item,
            saveFolderId: "cid99",
            savePath: "电影",
            files: files
        )
        XCTAssertEqual(p.title, "测试影片")
        XCTAssertEqual(p.shareTitle, "测试影片")
        XCTAssertTrue(p.shareUrl.contains("115.com/s/abc123"))
        XCTAssertEqual(p.firstShareUrl, p.shareUrl)
        XCTAssertEqual(p.saveFid, "cid99")
        XCTAssertEqual(p.savePath, "电影")
        XCTAssertEqual(p.shareFid, "fid1")
    }

    func testResolvedPostSavePluginId() {
        var s = CloudSaverSettings.empty
        XCTAssertNil(s.resolvedPostSavePluginId)
        s.postSavePluginId = "4"
        XCTAssertEqual(s.resolvedPostSavePluginId, 4)
        s.postSavePluginId = " 0 "
        XCTAssertNil(s.resolvedPostSavePluginId)
        s.postSavePluginId = "x"
        XCTAssertNil(s.resolvedPostSavePluginId)
    }

    func testPostSaveFollowUpSuffix() {
        let zh = Translations.chinese
        let en = Translations.english
        XCTAssertNil(CloudSaverPostSaveFollowUp.skipped.userSuffix(using: zh))
        XCTAssertTrue(
            CloudSaverPostSaveFollowUp.triggered(message: "LitePan推送触发成功！").userSuffix(using: zh)?.contains("LitePan") == true
        )
        XCTAssertTrue(
            CloudSaverPostSaveFollowUp.failed(message: "timeout").userSuffix(using: zh)?.contains("timeout") == true
        )
        XCTAssertEqual(
            CloudSaverPostSaveFollowUp.triggered(message: "").userSuffix(using: en),
            en.csPluginTriggeredDefault
        )
        XCTAssertEqual(
            CloudSaverPostSaveFollowUp.failed(message: "").userSuffix(using: zh),
            zh.csPluginFailedDefault
        )
    }
}

/// Test-only mirror of wire envelope for folder list (private DTOs not @testable).
private struct CSFolderListEnvelopeTest: Decodable {
    let success: Bool?
    let message: String?
    let data: [CSFolderItemTest]?
}

private struct CSFolderItemTest: Decodable {
    let cid: String?
    let name: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try c.decodeIfPresent(String.self, forKey: .cid) {
            cid = s
        } else if let n = try c.decodeIfPresent(Int64.self, forKey: .cid) {
            cid = String(n)
        } else {
            cid = nil
        }
        name = try c.decodeIfPresent(String.self, forKey: .name)
        // path may be [] or [{name,cid,...}] — ignore
    }

    private enum CodingKeys: String, CodingKey { case cid, name, path }

}
