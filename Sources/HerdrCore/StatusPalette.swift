import Darwin
import Foundation

/// Status colors. Defaults match Claude Code's terminal tab-status palette.
/// Override with `~/.config/herdr/herdr-bar.json`:
///
/// ```json
/// { "colors": { "blocked": "#5F87FF", "done": "#00D75F", "working": "#CF7650", "unknown": "#C7A35A", "idle": "#888888" } }
/// ```
public final class StatusPalette: @unchecked Sendable {
    public static let shared = StatusPalette()

    public static var configPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/herdr/herdr-bar.json")
            .path
    }

    private let lock = NSLock()
    private var overrides: [AgentStatus: String] = [:]
    private var directoryMonitors: [DispatchSourceFileSystemObject] = []
    private var directoryFDs: [Int32] = []
    private var onChange: (() -> Void)?

    public init() {
        reload()
    }

    public func hex(for status: AgentStatus) -> String {
        lock.lock()
        let value = overrides[status]
        lock.unlock()
        return Self.normalize(value) ?? status.defaultHexColor
    }

    public func isOverridden(_ status: AgentStatus) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return overrides[status] != nil
    }

    public var hasOverrides: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !overrides.isEmpty
    }

    /// `hex == nil` or the default value drops the override.
    public func set(_ status: AgentStatus, hex: String?) {
        lock.lock()
        if let hex, let normalized = Self.normalize(hex), normalized != status.defaultHexColor {
            overrides[status] = normalized
        } else {
            overrides.removeValue(forKey: status)
        }
        let copy = overrides
        lock.unlock()
        persist(copy)
        DispatchQueue.main.async { self.onChange?() }
    }

    public func resetAll() {
        lock.lock()
        overrides = [:]
        lock.unlock()
        persist([:])
        DispatchQueue.main.async { self.onChange?() }
    }

    public func reload() {
        let parsed = Self.load(from: Self.configPath)
        lock.lock()
        overrides = parsed
        lock.unlock()
    }

    /// Watch the config file/dir. `onChange` is invoked on the main queue.
    public func startWatching(onChange: @escaping () -> Void) {
        stopWatching()
        self.onChange = onChange
        let file = Self.configPath
        let dir = URL(fileURLWithPath: file).deletingLastPathComponent().path
        watch(path: dir)
        watch(path: file)
    }

    public func stopWatching() {
        directoryMonitors.forEach { $0.cancel() }
        directoryMonitors.removeAll()
        for fd in directoryFDs where fd >= 0 { Darwin.close(fd) }
        directoryFDs.removeAll()
        onChange = nil
    }

    static func load(from path: String) -> [AgentStatus: String] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        let colors = json["colors"] as? [String: Any] ?? json
        var result: [AgentStatus: String] = [:]
        for status in AgentStatus.allCases {
            if let raw = colors[status.rawValue] as? String,
               let hex = normalize(raw),
               hex != status.defaultHexColor
            {
                result[status] = hex
            }
        }
        return result
    }

    /// Accept `#RGB`, `#RRGGBB`, or `RRGGBB`. Reject anything else.
    static func normalize(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.allSatisfy(\.isHexDigit) else { return nil }
        if value.count == 3 {
            let chars = Array(value)
            value = String([chars[0], chars[0], chars[1], chars[1], chars[2], chars[2]])
        }
        guard value.count == 6 else { return nil }
        return "#" + value.uppercased()
    }

    static func persist(_ overrides: [AgentStatus: String], to path: String) throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            root = json
        }
        var colors: [String: String] = [:]
        for status in AgentStatus.order {
            if let hex = overrides[status] { colors[status.rawValue] = hex }
        }
        if colors.isEmpty {
            root.removeValue(forKey: "colors")
        } else {
            root["colors"] = colors
        }
        let url = URL(fileURLWithPath: path)
        if root.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func persist(_ overrides: [AgentStatus: String]) {
        try? Self.persist(overrides, to: Self.configPath)
    }

    private func watch(path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFDs.append(fd)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
            self?.onChange?()
        }
        source.resume()
        directoryMonitors.append(source)
    }
}
