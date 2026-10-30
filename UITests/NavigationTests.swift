import XCTest

@MainActor final class NavigationTests: XCTestCase {
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
