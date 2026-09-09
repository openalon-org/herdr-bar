import Foundation
import Testing
@testable import HerdrCore

@Suite("Update check")
struct UpdateCheckTests {
    @Test func emptyBundleVersionIsDev() {
        #expect(UpdateCheck.displayVersion(nil) == "dev")
        #expect(UpdateCheck.displayVersion("  ") == "dev")
        #expect(UpdateCheck.displayVersion("1.0.0") == "1.0.0")
    }

    @Test func stripsTagPrefix() {
        #expect(UpdateCheck.normalizeVersion("v1.2.3") == "1.2.3")
        #expect(UpdateCheck.normalizeVersion("V0.8.0") == "0.8.0")
        #expect(UpdateCheck.normalizeVersion("1.2.3") == "1.2.3")
    }

    @Test func comparesDottedVersions() {
        #expect(UpdateCheck.compare("1.0.0", "1.0.0") == .orderedSame)
        #expect(UpdateCheck.compare("1.0.1", "1.0.0") == .orderedDescending)
        #expect(UpdateCheck.compare("1.0.0", "1.0.1") == .orderedAscending)
        #expect(UpdateCheck.compare("1.2", "1.2.0") == .orderedSame)
        #expect(UpdateCheck.compare("v1.10.0", "1.9.9") == .orderedDescending)
        #expect(UpdateCheck.isNewer("1.0.0", than: "1.0.0-dev"))
        #expect(UpdateCheck.isNewer("1.0.0", than: "dev"))
        #expect(!UpdateCheck.isNewer("1.0.0", than: "1.0.0"))
        #expect(!UpdateCheck.isNewer("1.0.0", than: "1.1.0"))
    }

    @Test func parsesLatestReleaseJSON() throws {
        let json = """
        {
          "tag_name": "v1.2.0",
          "html_url": "https://github.com/openalon-org/herdr-bar/releases/tag/v1.2.0",
          "draft": false,
          "prerelease": false
        }
        """
        let release = try UpdateCheck.parseLatestRelease(from: Data(json.utf8))
        #expect(release.version == "1.2.0")
        #expect(release.htmlURL.absoluteString.hasSuffix("/v1.2.0"))
    }

    @Test func rejectsDraftAndPrerelease() {
        let draft = Data(#"{"tag_name":"v1.0.0","html_url":"https://example.invalid/v1","draft":true}"#.utf8)
        #expect(throws: UpdateCheckError.noReleases) {
            try UpdateCheck.parseLatestRelease(from: draft)
        }
        let pre = Data(#"{"tag_name":"v1.0.0","html_url":"https://example.invalid/v1","prerelease":true}"#.utf8)
        #expect(throws: UpdateCheckError.noReleases) {
            try UpdateCheck.parseLatestRelease(from: pre)
        }
    }

    @Test func mapsHTTPStatus() throws {
        #expect(throws: UpdateCheckError.noReleases) {
            try UpdateCheck.parseHTTP(status: 404, data: Data())
        }
        #expect(throws: UpdateCheckError.http(403)) {
            try UpdateCheck.parseHTTP(status: 403, data: Data())
        }
        let body = Data(#"{"tag_name":"1.0.0","html_url":"https://example.invalid/tag"}"#.utf8)
        let release = try UpdateCheck.parseHTTP(status: 200, data: body)
        #expect(release.version == "1.0.0")
    }

    @Test func rejectsGarbageJSON() {
        #expect(throws: UpdateCheckError.invalidPayload) {
            try UpdateCheck.parseLatestRelease(from: Data("{}".utf8))
        }
    }
}
