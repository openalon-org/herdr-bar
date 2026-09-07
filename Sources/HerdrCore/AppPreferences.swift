import Foundation

/// Shortcut that opens the dashboard from any app. `keyCode` is a hardware
/// virtual key (Carbon `kVK_*`); modifiers are Cocoa-style names in JSON.
public struct HotkeySpec: Equatable, Sendable {
    public var keyCode: UInt32
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool

    public init(keyCode: UInt32, command: Bool, option: Bool, control: Bool, shift: Bool) {
        self.keyCode = keyCode
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }

    /// Carbon `cmdKey` / `shiftKey` / `optionKey` / `controlKey` bits.
    public var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if command { value |= 1 << 8 }
        if shift { value |= 1 << 9 }
        if option { value |= 1 << 11 }
        if control { value |= 1 << 12 }
        return value
    }

    public var display: String {
        var marks = ""
        if control { marks += "⌃" }
        if option { marks += "⌥" }
        if shift { marks += "⇧" }
        if command { marks += "⌘" }
        return marks + Self.keyName(keyCode)
    }

    /// US-layout names for the common virtual keys. Enough for a settings label.
    public static func keyName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(keyCode)"
        }
    }

    static func fromJSON(_ raw: Any?) -> HotkeySpec? {
        guard let obj = raw as? [String: Any],
              let code = intValue(obj["keyCode"])
        else { return nil }
        return HotkeySpec(
            keyCode: UInt32(code),
            command: obj["command"] as? Bool ?? false,
            option: obj["option"] as? Bool ?? false,
            control: obj["control"] as? Bool ?? false,
            shift: obj["shift"] as? Bool ?? false
        )
    }

    var json: [String: Any] {
        var obj: [String: Any] = ["keyCode": Int(keyCode)]
        if command { obj["command"] = true }
        if option { obj["option"] = true }
        if control { obj["control"] = true }
        if shift { obj["shift"] = true }
        return obj
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let n = raw as? Int { return n }
        if let n = raw as? NSNumber { return n.intValue }
        return nil
    }
}

/// Non-color dashboard prefs in `~/.config/herdr/herdr-bar.json`.
/// `hideIdle` defaults to true (notification mode) and is omitted from disk
/// when it matches that default, so a colors-only file stays colors-only.
public final class AppPreferences: @unchecked Sendable {
    public static let shared = AppPreferences()

    public static var configPath: String { StatusPalette.configPath }

    private let lock = NSLock()
    private var hideIdle = true
    private var hotkey: HotkeySpec?

    public init() {
        reload()
    }

    public var hidesIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hideIdle
    }

    public var dashboardHotkey: HotkeySpec? {
        lock.lock()
        defer { lock.unlock() }
        return hotkey
    }

    public func setHidesIdle(_ value: Bool) {
        lock.lock()
        hideIdle = value
        lock.unlock()
        persist()
    }

    public func setDashboardHotkey(_ value: HotkeySpec?) {
        lock.lock()
        hotkey = value
        lock.unlock()
        persist()
    }

    public func reload() {
        let loaded = Self.load(from: Self.configPath)
        lock.lock()
        hideIdle = loaded.hideIdle
        hotkey = loaded.hotkey
        lock.unlock()
    }

    public struct Snapshot: Equatable, Sendable {
        public var hideIdle: Bool
        public var hotkey: HotkeySpec?
    }

    static func loadHideIdle(from path: String) -> Bool {
        load(from: path).hideIdle
    }

    static func loadHotkey(from path: String) -> HotkeySpec? {
        load(from: path).hotkey
    }

    static func load(from path: String) -> Snapshot {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return Snapshot(hideIdle: true, hotkey: nil) }
        let hide = json["hideIdle"] as? Bool ?? true
        return Snapshot(hideIdle: hide, hotkey: HotkeySpec.fromJSON(json["hotkey"]))
    }

    static func persistHideIdle(_ hideIdle: Bool, to path: String) throws {
        try mutate(path) { root in
            if hideIdle {
                root.removeValue(forKey: "hideIdle")
            } else {
                root["hideIdle"] = false
            }
        }
    }

    static func persistHotkey(_ hotkey: HotkeySpec?, to path: String) throws {
        try mutate(path) { root in
            if let hotkey {
                root["hotkey"] = hotkey.json
            } else {
                root.removeValue(forKey: "hotkey")
            }
        }
    }

    static func mutate(_ path: String, _ body: (inout [String: Any]) -> Void) throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            root = json
        }
        body(&root)
        let url = URL(fileURLWithPath: path)
        if root.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func persist() {
        let hide = hidesIdle
        let key = dashboardHotkey
        try? Self.mutate(Self.configPath) { root in
            if hide {
                root.removeValue(forKey: "hideIdle")
            } else {
                root["hideIdle"] = false
            }
            if let key {
                root["hotkey"] = key.json
            } else {
                root.removeValue(forKey: "hotkey")
            }
        }
    }
}
