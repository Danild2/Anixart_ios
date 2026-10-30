import XCTest

@MainActor final class NavigationTests: XCTestCase {
    func testVLCResolvesRealMediaStream() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "liquidGlass", "-regionalAPI", "NO", "-playbackMode", "vlc", "-captureResolvedStream", "YES"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); search.typeText("Гонка")
        let release = app.descendants(matching: .any).matching(identifier: "release.20290").firstMatch
        guard release.waitForExistence(timeout: 30) else { XCTFail("Live release unavailable"); return }; release.tap()
        let watch = app.buttons["watchRelease"]
        guard watch.waitForExistence(timeout: 15) else { XCTFail("Playback is restricted by the server"); return }; watch.tap()
        for identifier in ["translation.143", "source.153", "episode.1"] {
            let item = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard item.waitForExistence(timeout: 30) else { XCTFail("Live source selection unavailable: \(identifier)"); return }; item.tap()
        }
        let web = app.webViews.firstMatch
        guard web.waitForExistence(timeout: 30) else { XCTFail("Legitimate embedding flow did not load"); return }
        let state = app.staticTexts["playbackState"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Загрузка плеера…"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 45), .completed)
        web.tap()
        if app.buttons["Воспроизвести"].isEnabled { app.buttons["Воспроизвести"].tap() }
        let open = app.buttons["openVLCStream"]
        let resolved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
        let result = XCTWaiter.wait(for: [resolved], timeout: 120)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "VLC-live-stream-resolution-result"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertEqual(result, .completed, "Requires an actual HTTP(S) media URL observed in the authorized player, not an iframe URL")
    }
    func testRealEmbeddedVideoProducesDecodedFrames() throws {
        guard ProcessInfo.processInfo.environment["ANIXART_EMBEDDED_PLAYBACK_TEST"] == "1" else {
            throw XCTSkip("Version 1 uses external VLC; embedded playback remains a separately invoked compatibility test.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "liquidGlass", "-regionalAPI", "NO", "-playbackMode", "inApp"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); search.typeText("Гонка")
        let release = app.descendants(matching: .any).matching(identifier: "release.20290").firstMatch
        guard release.waitForExistence(timeout: 30) else { XCTFail("Live Anixart release 20290 is unavailable"); return }
        release.tap()
        let watch = app.buttons["watchRelease"]
        guard watch.waitForExistence(timeout: 15) else { XCTFail("Server did not allow playback for the selected release"); return }
        watch.tap()
        for identifier in ["translation.143", "source.153", "episode.1"] {
            let item = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard item.waitForExistence(timeout: 30) else { XCTFail("Live playback chain is unavailable: \(identifier)"); return }
            item.tap()
        }
        let web = app.webViews.firstMatch
        guard web.waitForExistence(timeout: 30) else { XCTFail("Embedded player did not appear"); return }
        let state = app.staticTexts["playbackState"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "Загрузка плеера…"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 45), .completed)
        web.tap() // Ordinary user gesture on the legitimate provider's play surface.
        if app.buttons["Воспроизвести"].isEnabled { app.buttons["Воспроизвести"].tap() }
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Воспроизводится"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 120), .completed, "Requires advancing currentTime plus readyState >= 3 and nonzero decoded video dimensions")
        XCTAssertGreaterThanOrEqual(Int(state.value as? String ?? "0") ?? 0, 2)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "real-Anixart-source-video-playing"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["Пауза"].tap()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Пауза"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 10), .completed)
    }
    func testNativeLiquidGlassTabsAndScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "liquidGlass", "-regionalAPI", "NO"]
        app.launch()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        for title in ["Главная", "Обзор", "Закладки", "Лента", "Профиль"] { XCTAssertTrue(bar.buttons[title].exists) }
        let release = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "release.")).firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 45))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "iPhone17-native-liquid-glass-tabs"; screenshot.lifetime = .keepAlways; add(screenshot)
        bar.buttons["Профиль"].tap()
        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5))
        bar.buttons["Главная"].tap()
        XCTAssertTrue(app.navigationBars["Anixart"].exists)
    }
    func testGuestCatalogOpensRealRelease() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "original", "-regionalAPI", "NO"]
        app.launch()
        let release = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "release.")).firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 45), "A real server release must appear; no fixture or offline demo is used")
        let catalog = XCTAttachment(screenshot: app.screenshot()); catalog.name = "iPhone17-catalog-original"; catalog.lifetime = .keepAlways; add(catalog)
        release.tap()
        XCTAssertTrue(app.navigationBars["О релизе"].waitForExistence(timeout: 10))
        let detail = XCTAttachment(screenshot: app.screenshot()); detail.name = "iPhone17-release-original"; detail.lifetime = .keepAlways; add(detail)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Anixart"].exists)
    }
    func testSettingsThemeAndBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "original"]
        app.launch()
        let profile = app.buttons["tab.4"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10)); profile.tap()
        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Тёмное оформление"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Профиль"].exists)
    }
    func testGuestBookmarksShowsRealLoginForm() {
        let app = XCUIApplication(); app.launchArguments = ["-theme", "original"]; app.launch()
        let bookmarks = app.buttons["tab.2"]
        XCTAssertTrue(bookmarks.waitForExistence(timeout: 10)); bookmarks.tap()
        XCTAssertTrue(app.secureTextFields["Пароль"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Войти"].isEnabled)
    }
}
