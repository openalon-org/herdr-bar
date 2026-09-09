import Foundation

/// Latest GitHub Release for this repo. herdr-bar has no Sparkle feed — tagged
/// zips are ad-hoc signed — so a check compares versions and points at the tag.
public struct UpdateRelease: Equatable, Sendable {
    public var version: String
    public var htmlURL: URL

    public init(version: String, htmlURL: URL) {
        self.version = version
        self.htmlURL = htmlURL
    }
}

public enum UpdateCheckError: Error, Equatable, LocalizedError, Sendable {
    case noReleases
    case http(Int)
    case invalidPayload
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .noReleases:
            "No GitHub Releases yet."
        case .http(let status):
            "GitHub returned HTTP \(status)."
        case .invalidPayload:
            "GitHub returned an unreadable release."
        case .invalidURL:
            "GitHub release URL was invalid."
        }
    }
}

public enum UpdateCheck {
    public static let repository = "openalon-org/herdr-bar"
    public static let repositoryURL = URL(string: "https://github.com/\(repository)")!
    public static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!

    /// Bundle short version, or `dev` when the process is not packed as HerdrBar.app.
    public static func displayVersion(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "dev" : trimmed
    }

    public static func currentVersion(from bundle: Bundle = .main) -> String {
        displayVersion(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// Strip a leading `v` / `V` so tag `v1.2.3` matches `CFBundleShortVersionString`.
    public static func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "v" || trimmed.first == "V" {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    /// Numeric dotted compare. A suffix (`1.0.0-dev`) is older than the same
    /// numbers without one, so a tagged `1.0.0` beats a `workflow_dispatch` build.
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = splitVersion(lhs)
        let right = splitVersion(rhs)
        let count = max(left.parts.count, right.parts.count)
        for index in 0..<count {
            let a = index < left.parts.count ? left.parts[index] : 0
            let b = index < right.parts.count ? right.parts[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        switch (left.prerelease, right.prerelease) {
        case (true, false): return .orderedAscending
        case (false, true): return .orderedDescending
        default: return .orderedSame
        }
    }

    public static func isNewer(_ latest: String, than current: String) -> Bool {
        compare(latest, current) == .orderedDescending
    }

    public static func parseLatestRelease(from data: Data) throws -> UpdateRelease {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw UpdateCheckError.invalidPayload
        }
        if payload.draft == true || payload.prerelease == true {
            throw UpdateCheckError.noReleases
        }
        let version = normalizeVersion(payload.tagName)
        guard !version.isEmpty else { throw UpdateCheckError.invalidPayload }
        guard let url = URL(string: payload.htmlURL) else { throw UpdateCheckError.invalidURL }
        return UpdateRelease(version: version, htmlURL: url)
    }

    public static func parseHTTP(status: Int, data: Data) throws -> UpdateRelease {
        if status == 404 { throw UpdateCheckError.noReleases }
        guard (200..<300).contains(status) else { throw UpdateCheckError.http(status) }
        return try parseLatestRelease(from: data)
    }

    /// Hits GitHub's `/releases/latest`. Call from the UI; tests use `parseHTTP`.
    public static func fetchLatest(session: URLSession = .shared) async throws -> UpdateRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("herdr-bar", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try parseHTTP(status: status, data: data)
    }

    private static func splitVersion(_ raw: String) -> (parts: [Int], prerelease: Bool) {
        let normalized = normalizeVersion(raw)
        let chunks = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let core = chunks.first.map(String.init) ?? normalized
        let parts = core.split(separator: ".").map { Int($0) ?? 0 }
        return (parts, chunks.count > 1)
    }

    private struct Payload: Decodable {
        var tagName: String
        var htmlURL: String
        var draft: Bool?
        var prerelease: Bool?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case prerelease
        }
    }
}
