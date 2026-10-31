import XCTest
@testable import AnixartPort

final class FullProfileTests: XCTestCase {
    func testFullProfilePreviewsDecodeWithoutCredentials() throws {
        let data = Data(#"{"id":9,"rating_score":100,"register_date":1700000000,"friend_count":1,"friends_preview":[{"id":7,"login":"Друг"}],"badges_preview":[{"id":2,"type":1,"image_url":"https://example.com/a.json","image_preview_url":"https://example.com/a.png","ownership_percentage":0.3}],"comments_preview":[{"id":4,"message":"Текст","release":{"id":841,"title_ru":"Инициал Ди"}}],"votes":[{"id":841,"my_vote":5}],"history":[{"id":841,"last_view_episode":{"name":"1 серия"},"last_view_timestamp":1700000000}],"pinned_section_id":5}"#.utf8)
        let p = try APIClient.decoder().decode(Profile.self,from:data)
        XCTAssertEqual(p.friendsPreview?.first?.login,"Друг")
        XCTAssertEqual(p.commentsPreview?.first?.release?.id,841)
        XCTAssertEqual(p.history?.first?.lastViewEpisode?.name,"1 серия")
        XCTAssertEqual(p.badgesPreview?.first?.thumbnail?.path,"/a.png")
        XCTAssertEqual(ProfileSection.visible(in:p).first,.badges)
        let restored = try JSONDecoder().decode(Profile.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(restored,p)
    }
    func testPrivacyHidesAllOriginalRestrictedSectionsEvenWhenPinned() {
        var p = Profile(id:1); p.isStatsHidden = true; p.isCountsHidden = true; p.pinnedSectionId = 0
        XCTAssertEqual(ProfileSection.visible(in:p),[.badges])
    }
    func testArticleHeterogeneousBlockPayloadPreservesEveryBlock() throws {
        let data = Data(#"{"id":1,"payload":{"blocks":[{"type":"paragraph","data":{"text":"<b>Текст</b>"}},{"type":"media","data":{"items":[{"url":"https://example.com/a.png","width":400}]}},{"type":"future","data":{"enabled":true,"values":[null,3]}}]}}"#.utf8)
        let article = try APIClient.decoder().decode(ProfileArticle.self,from:data)
        XCTAssertEqual(article.payload?.blocks?.count,3)
        XCTAssertEqual(article.payload?.blocks?.first?.data["text"].string,"<b>Текст</b>")
        XCTAssertEqual(try JSONDecoder().decode(ProfileArticle.self,from:JSONEncoder().encode(article)),article)
    }
    func testRepeatedJacksonReleaseReferencesKeepCommentTargetsAndNumericFields() throws {
        let data = Data(#"{"code":0,"content":[{"id":10,"release":{"@id":1,"id":841,"title_ru":"Инициал Ди"},"vote_count":1},{"id":11,"release":1,"vote_count":1}]}"#.utf8)
        let page = try APIClient.decoder().decode(Page<ProfileComment>.self,from:IdentityJSON.expand(data))
        XCTAssertEqual(page.content.map { $0.release?.id },[841,841])
        XCTAssertEqual(page.content[1].release?.title,"Инициал Ди")
        XCTAssertEqual(page.content[1].voteCount,1)
    }
}
