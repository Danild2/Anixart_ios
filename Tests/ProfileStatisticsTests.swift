import XCTest
@testable import AnixartPort

final class ProfileStatisticsTests: XCTestCase {
    func testOriginalProfileStatisticsWireFieldsAndMinutes() throws {
        let data = Data(#"{"id":7,"watching_count":3,"plan_count":10,"completed_count":40,"hold_on_count":2,"dropped_count":1,"watched_episode_count":1234,"watched_time":1500,"preferred_genres":[{"name":"Драма","percentage":42}],"watch_dynamics":[{"day":1,"timestamp":1700000000,"count":7}],"is_stats_hidden":false}"#.utf8)
        let profile = try APIClient.decoder().decode(Profile.self,from:data)
        XCTAssertEqual(profile.completedCount,40); XCTAssertEqual(profile.watchedEpisodeCount,1234)
        XCTAssertEqual(profile.preferredGenres?.first?.percentage,42)
        XCTAssertEqual(profile.watchDynamics?.first?.count,7)
        XCTAssertTrue(profile.hasStatistics)
        XCTAssertEqual(ProfileTimeText.format(minutes:1500),"~ 1 день 1 час")
        XCTAssertEqual(ProfileTimeText.format(minutes:61),"~ 1 час")
        XCTAssertEqual(ProfileTimeText.format(minutes:5),"~ 5 минут")
    }
    func testCompactProfileDoesNotInventStatistics() throws {
        let profile = try APIClient.decoder().decode(Profile.self,from:Data(#"{"id":7,"login":"Fixture"}"#.utf8))
        XCTAssertFalse(profile.hasStatistics); XCTAssertNil(profile.watchedTime)
    }
}
