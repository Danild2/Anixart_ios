import XCTest

@MainActor final class NavigationTests: XCTestCase {
    func testRealPostersDecodeDuringScrolling() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme","liquidGlass","-regionalAPI","NO","-verifyPosterLoading","YES"]
        app.launch()
        let metric = app.staticTexts["imageMetrics"]
        XCTAssertTrue(metric.waitForExistence(timeout:15))
        let first = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value MATCHES %@","decoded=([3-9]|[1-9][0-9]+);.*"),object:metric)
        XCTAssertEqual(XCTWaiter.wait(for:[first],timeout:30),.completed)
        for _ in 0..<12 { app.swipeUp() }
        let scrolled = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value MATCHES %@","decoded=([2-9][0-9]|[1-9][0-9]{2,});.*"),object:metric)
        XCTAssertEqual(XCTWaiter.wait(for:[scrolled],timeout:30),.completed)
        XCTAssertTrue((metric.value as? String ?? "").hasSuffix("failed=0"))
        let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "real-posters-decoded-after-scrolling"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); app.launch()
        let restarted = app.staticTexts["imageMetrics"]
        let disk = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value MATCHES %@",".*;disk=[1-9][0-9]*;.*"),object:restarted)
        XCTAssertEqual(XCTWaiter.wait(for:[disk],timeout:30),.completed,"Real posters should survive process restart in the disk cache")
    }
    func testRealProfileStatisticsAndViewingSections() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme","liquidGlass","-regionalAPI","NO","-verifyProfileID","4804973"]
        app.launch()
        let name = app.descendants(matching:.any).matching(identifier:"profileHeaderName").firstMatch
        guard name.waitForExistence(timeout:30) else { XCTFail("Real profile unavailable"); return }
        let header = XCTAttachment(screenshot:app.screenshot()); header.name = "profile-viewing-header"; header.lifetime = .keepAlways; add(header)
        XCTAssertFalse(app.buttons["profileFriends"].exists)
        XCTAssertFalse(app.buttons["profile.section.1"].exists)
        XCTAssertFalse(app.buttons["profile.section.3"].exists)
        XCTAssertFalse(app.buttons["profile.section.4"].exists)
        let count = app.staticTexts["profile.listCount.0"]
        guard count.exists else { XCTFail("Real statistics unavailable"); return }
        for _ in 0..<3 { if app.staticTexts["profile.listCount.4"].frame.maxY < app.frame.maxY - 140 { break }; app.swipeUp() }
        let stats = XCTAttachment(screenshot:app.screenshot()); stats.name = "profile-viewing-statistics"; stats.lifetime = .keepAlways; add(stats)
        XCTAssertTrue(app.staticTexts["profile.listCount.4"].exists)
        let details = app.buttons["profileDynamicsDetails"]
        for _ in 0..<6 { if details.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"profileWatchDynamics").firstMatch.exists)
        let dynamics = XCTAttachment(screenshot:app.screenshot()); dynamics.name = "profile-viewing-dynamics"; dynamics.lifetime = .keepAlways; add(dynamics)
        XCTAssertTrue(details.isHittable); details.tap()
        XCTAssertTrue(app.alerts["Информация"].waitForExistence(timeout:5))
        app.alerts.buttons["Понятно"].tap()
        app.swipeUp()
        let history = XCTAttachment(screenshot:app.screenshot()); history.name = "profile-recent-history"; history.lifetime = .keepAlways; add(history)
        for _ in 0..<6 { if name.exists, name.frame.minY >= 120 { break }; app.swipeDown() }
        let chips = app.scrollViews["profileSections"]
        XCTAssertTrue(chips.waitForExistence(timeout:15))
        for section in [2,5] {
            let chip = app.buttons["profile.section.\(section)"]
            for _ in 0..<4 { if chip.isHittable { break }; chips.swipeLeft() }
            XCTAssertTrue(chip.isHittable); chip.tap()
            let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "profile-section-\(section)"; shot.lifetime = .keepAlways; add(shot)
        }
        let more = app.buttons["profile.section.more"]
        for _ in 0..<3 { if more.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(more.isHittable); more.tap()
        XCTAssertTrue(app.navigationBars["Значки"].waitForExistence(timeout:10))
        let badges = XCTAttachment(screenshot:app.screenshot()); badges.name = "profile-badges"; badges.lifetime = .keepAlways; add(badges)
    }
    func testKodikResolvesRealMediaStream() { resolveInitialD(source:8) }
    func testSibnetResolvesRealMediaStream() { resolveInitialD(source:1) }
    private func resolveInitialD(source:Int) {
        let app = XCUIApplication()
        app.launchArguments = ["-theme","liquidGlass","-regionalAPI","NO","-playbackMode","vlc","-captureResolvedStream","YES"]
        app.launch()
        let search = app.searchFields.firstMatch
        guard search.waitForExistence(timeout:15) else { XCTFail("Search unavailable"); return }
        search.tap(); search.typeText("Инициал Ди")
        let release = app.descendants(matching:.any).matching(identifier:"release.841").firstMatch
        guard release.waitForExistence(timeout:30) else { XCTFail("Initial D unavailable"); return }; release.tap()
        let watch = app.buttons["watchRelease"]
        guard watch.waitForExistence(timeout:20) else { XCTFail("Server disallowed watching"); return }; watch.tap()
        for id in ["translation.1","source.\(source)","episode.1"] {
            let item = app.descendants(matching:.any).matching(identifier:id).firstMatch
            guard item.waitForExistence(timeout:30) else { XCTFail("Source selection unavailable: \(id)"); return }; item.tap()
        }
        if source == 8 {
            let web = app.webViews.firstMatch
            guard web.waitForExistence(timeout:45) else { XCTFail("Kodik page unavailable"); return }
            let state = app.staticTexts["playbackState"]
            if state.label == "Реклама источника" {
                let ready = app.staticTexts["providerPlayReady"]
                guard ready.waitForExistence(timeout:60) else {
                    let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Kodik-play-control-not-ready"; screenshot.lifetime = .keepAlways; add(screenshot)
                    XCTFail("The provider did not display its actual play control"); return
                }
                web.tap() // A real user gesture after the provider's own Play element becomes visible.
            }
            let content = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@ OR label == %@ OR label == %@", "Источник загружен", "Воспроизводится", "Пауза"),object:state)
            guard XCTWaiter.wait(for:[content],timeout:120) == .completed else {
                let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Kodik-normal-ad-flow-result"; screenshot.lifetime = .keepAlways; add(screenshot)
                XCTFail("Kodik did not complete its normal ad flow and load the content player"); return
            }
            if !app.buttons["openVLCStream"].isEnabled { app.webViews.firstMatch.tap() }
        }
        let open = app.buttons["openVLCStream"]
        if !open.waitForExistence(timeout:5), app.descendants(matching:.any).matching(identifier:"playbackFailure").firstMatch.exists {
            let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Initial-D-source-\(source)-provider-error"; screenshot.lifetime = .keepAlways; add(screenshot)
            XCTFail("Provider returned an explicit error before a media URL was available"); return
        }
        let resolved = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:open)
        let result = XCTWaiter.wait(for:[resolved],timeout:120)
        let screenshot = XCTAttachment(screenshot:app.screenshot()); screenshot.name = "Initial-D-source-\(source)-stream-result"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertEqual(result,.completed,"Every required provider must produce an actual media URL")
        if source == 8 {
            XCTAssertFalse(app.webViews.staticTexts.matching(NSPredicate(format:"label CONTAINS[cd] %@","данной страницы не существует")).firstMatch.exists,"The real Kodik content page must not display a missing-page error")
            XCTAssertFalse(app.descendants(matching:.any).matching(identifier:"playbackFailure").firstMatch.exists)
        }
    }
    func testScheduleUsesRealServerDataAndOpensRelease() {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", "liquidGlass", "-regionalAPI", "NO"]
        app.launch()
        let discover = app.tabBars.buttons["Обзор"]
        guard discover.waitForExistence(timeout: 10) else { XCTFail("Native tabs unavailable"); return }
        discover.tap(); app.buttons["openSchedule"].tap()
        XCTAssertTrue(app.navigationBars["Расписание"].waitForExistence(timeout: 10))
        let release = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule.release.")).firstMatch
        guard release.waitForExistence(timeout: 45) else { XCTFail("Real schedule did not contain any release"); return }
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "iPhone17-live-schedule"; screenshot.lifetime = .keepAlways; add(screenshot)
        release.tap()
        XCTAssertTrue(app.navigationBars["О релизе"].waitForExistence(timeout: 10))
    }
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
        for identifier in ["translation.365", "source.413", "episode.1"] {
            let item = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard item.waitForExistence(timeout: 30) else { XCTFail("Live source selection unavailable: \(identifier)"); return }; item.tap()
        }
        let open = app.buttons["openVLCStream"]
        let resolved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: open)
        let result = XCTWaiter.wait(for: [resolved], timeout: 60)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "VLC-live-stream-resolution-result"; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTAssertEqual(result, .completed, "Requires a real episode media URL from the APK-confirmed public Liberty API")
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
        for title in ["Главная", "Обзор", "Закладки", "Профиль"] { XCTAssertTrue(bar.buttons[title].exists) }
        XCTAssertFalse(bar.buttons["Лента"].exists)
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
    func testAccountRegistrationAndRestoreNavigationWithoutSendingEmail() {
        let app = XCUIApplication(); app.launchArguments = ["-theme", "original"]; app.launch()
        let bookmarks = app.buttons["tab.2"]
        guard bookmarks.waitForExistence(timeout: 10) else { XCTFail("Bookmarks unavailable"); return }
        bookmarks.tap(); app.buttons["Регистрация"].tap()
        XCTAssertTrue(app.secureTextFields["Повторите пароль"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["beginAccountAccess"].isEnabled)
        XCTAssertEqual(app.switches["termsConsent"].value as? String, "0")
        XCTAssertEqual(app.switches["disseminationConsent"].value as? String, "0")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Забыли пароль?"].tap()
        XCTAssertTrue(app.secureTextFields["Новый пароль"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["beginAccountAccess"].isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.secureTextFields["Пароль"].exists)
    }
}
