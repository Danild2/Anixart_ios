import XCTest
@testable import AnixartPort

final class OriginalCopyTests: XCTestCase {
    func testAPKCopyIsBundledWithOriginalTabLabels() {
        XCTAssertEqual(OriginalCopy.resources.strings.count, 2351)
        XCTAssertEqual(OriginalCopy.resources.arrays.count, 57)
        XCTAssertEqual(OriginalCopy.resources.plurals.count, 27)
        XCTAssertEqual(OriginalCopy.text("home"), "Главная")
        XCTAssertEqual(OriginalCopy.text("discover"), "Обзор")
        XCTAssertEqual(OriginalCopy.text("country_japan"), "Япония")
        XCTAssertEqual(OriginalCopy.text("tab_title_ova"), "OVA")
    }
}
