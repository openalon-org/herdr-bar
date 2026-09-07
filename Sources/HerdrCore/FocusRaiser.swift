import AppKit
import Darwin
import Foundation

/// After `agent.focus`, raise the GUI terminal that hosts that herdr TUI client.
/// Isolated from protocol logic; never creates a pane, tab, or window.
///
/// Herdr's listening socket is owned by `herdr server` (ppid 1). The TUI that
/// sits inside cmux / Otty / Ghostty is a separate process (`herdr` or
/// `herdr session attach <name>`). We locate that client, walk to its regular
/// GUI ancestor, then hand activation over.
///
/// Host PIDs are cached so a dashboard click is just `activate()`, not a
/// process scan. Lookup uses `sysctl` (no `lsof`/`ps` spawn).
public enum FocusRaiser {
    @MainActor
    public static func raiseHost(sessionName: String, socketPath: String) {
        if let app = cachedLiveApp(sessionName: sessionName) {
            raise(app)
            return
        }
        if let app = resolveHost(sessionName: sessionName, socketPath: socketPath) {
            raise(app)
        }
    }

    /// Back-compat: infer the session from a standard herdr socket path.
    @MainActor
    public static func raiseHost(forSocketPath socketPath: String) {
        raiseHost(sessionName: sessionName(fromSocketPath: socketPath), socketPath: socketPath)
    }

    /// Fill the host cache off the click path so the first raise is instant.
    public static func warm(sessionName: String, socketPath: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = resolveHost(sessionName: sessionName, socketPath: socketPath)
        }
    }

    public static func forget(sessionName: String) {
        hosts.remove(sessionName)
    }

    // MARK: - Session matching (pure; covered by tests)

    static func sessionName(fromSocketPath socketPath: String) -> String {
        let parts = socketPath.split(separator: "/").map(String.init)
        if let idx = parts.lastIndex(of: "sessions"), idx + 1 < parts.count {
            let name = parts[idx + 1]
            if !name.isEmpty, name != "herdr.sock" { return name }
        }
        return "default"
    }

    /// Client log lives next to the session socket, not on the listening sock.
    static func clientLogPath(forSocketPath socketPath: String) -> String {
        URL(fileURLWithPath: socketPath)
            .deletingLastPathComponent()
            .appendingPathComponent("herdr-client.log")
            .path
    }

    /// `herdr` (no args) is the default TUI. `herdr session attach <name>` is a named session.
    /// `herdr server` and other subcommands are not TUI clients.
    static func isHerdrTUIClient(command: String, sessionName: String) -> Bool {
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let idx = tokens.lastIndex(where: isHerdrBinary) else { return false }
        let args = Array(tokens[(idx + 1)...])
        if args.first == "server" { return false }
        if sessionName == "default" {
            return args.isEmpty
                || (args.count >= 3 && args[0] == "session" && args[1] == "attach" && args[2] == "default")
        }
        return args.count >= 3
            && args[0] == "session"
            && args[1] == "attach"
            && args[2] == sessionName
    }

    static func isHerdrBinary(_ token: String) -> Bool {
        token == "herdr" || token.hasSuffix("/herdr")
    }

    // MARK: - Process lookup

    static func resolveHost(sessionName: String, socketPath: String) -> NSRunningApplication? {
        _ = socketPath
        guard let clientPID = clientPID(sessionName: sessionName) else { return nil }
        guard let app = hostingApp(startingAt: clientPID) else { return nil }
        hosts.store(sessionName, pid: app.processIdentifier)
        return app
    }

    static func clientPID(sessionName: String) -> pid_t? {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        for (pid, command) in herdrCommands() where pid != selfPID {
            if isHerdrTUIClient(command: command, sessionName: sessionName),
               hostingApp(startingAt: pid) != nil
            {
                return pid
            }
        }
        return nil
    }

    static func hostingApp(startingAt pid: pid_t) -> NSRunningApplication? {
        var current = pid
        var seen = Set<pid_t>()
        let selfPID = ProcessInfo.processInfo.processIdentifier
        while current > 1, seen.insert(current).inserted {
            if current != selfPID,
               let app = NSRunningApplication(processIdentifier: current),
               let bundle = app.bundleIdentifier,
               bundle != "com.apple.dt.Xcode",
               !bundle.contains("herdr-bar"),
               !bundle.contains("macos-herdr"),
               !bundle.contains("MacBar"),
               !bundle.contains("HerdrBar"),
               app.activationPolicy == .regular
            {
                return app
            }
            current = parentPID(current)
        }
        return nil
    }

    static func parentPID(_ pid: pid_t) -> pid_t {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = mib.withUnsafeMutableBufferPointer { ptr in
            sysctl(ptr.baseAddress, 4, &kinfo, &size, nil, 0)
        }
        guard result == 0 else { return 1 }
        return kinfo.kp_eproc.e_ppid
    }

    // MARK: - Activate existing host (never open a new window)

    @MainActor
    static func raise(_ app: NSRunningApplication) {
        if app.isHidden {
            app.unhide()
        }
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: app)
        }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    // MARK: - Cache

    private static let hosts = HostCache()

    static func cachedLiveApp(sessionName: String) -> NSRunningApplication? {
        guard let pid = hosts.pid(for: sessionName) else { return nil }
        guard let app = NSRunningApplication(processIdentifier: pid),
              !app.isTerminated,
              app.activationPolicy == .regular
        else {
            hosts.remove(sessionName)
            return nil
        }
        return app
    }

    // MARK: - sysctl process table (no subprocess)

    static func herdrCommands() -> [(pid_t, String)] {
        kinfoProcs()
            .compactMap { info -> (pid_t, String)? in
                let pid = info.kp_proc.p_pid
                guard processName(info) == "herdr" else { return nil }
                guard let command = commandLine(of: pid) else { return nil }
                return (pid, command)
            }
    }

    static func kinfoProcs() -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        for _ in 0..<3 {
            guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }
            size += MemoryLayout<kinfo_proc>.stride * 32
            let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<kinfo_proc>.alignment)
            defer { raw.deallocate() }
            var used = size
            if sysctl(&mib, 4, raw, &used, nil, 0) == 0 {
                let n = used / MemoryLayout<kinfo_proc>.stride
                let typed = raw.bindMemory(to: kinfo_proc.self, capacity: n)
                return Array(UnsafeBufferPointer(start: typed, count: n))
            }
            if errno != ENOMEM { return [] }
        }
        return []
    }

    static func processName(_ info: kinfo_proc) -> String {
        withUnsafePointer(to: info.kp_proc.p_comm) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.kp_proc.p_comm)) {
                String(cString: $0)
            }
        }
    }

    static func commandLine(of pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        var used = size
        guard sysctl(&mib, 3, &buf, &used, nil, 0) == 0 else { return nil }
        return parseProcArgs2(buf, length: used)
    }

    /// KERN_PROCARGS2: int32 argc, exec path, padding, then argv strings.
    static func parseProcArgs2(_ buf: [CChar], length: Int) -> String? {
        guard length >= 4 else { return nil }
        let argc = buf.withUnsafeBytes { raw -> Int32 in
            guard raw.count >= 4 else { return 0 }
            return raw.load(fromByteOffset: 0, as: Int32.self)
        }
        guard argc > 0 else { return nil }
        var i = 4
        while i < length, buf[i] != 0 { i += 1 }
        i += 1
        while i < length, buf[i] == 0 { i += 1 }
        var args: [String] = []
        args.reserveCapacity(Int(argc))
        for _ in 0..<argc {
            if i >= length { break }
            var end = i
            while end < length, buf[end] != 0 { end += 1 }
            buf.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                args.append(String(cString: base + i))
            }
            i = end + 1
        }
        guard !args.isEmpty else { return nil }
        return args.joined(separator: " ")
    }
}

private final class HostCache: @unchecked Sendable {
    private let lock = NSLock()
    private var pids: [String: pid_t] = [:]

    func pid(for session: String) -> pid_t? {
        lock.lock()
        defer { lock.unlock() }
        return pids[session]
    }

    func store(_ session: String, pid: pid_t) {
        lock.lock()
        pids[session] = pid
        lock.unlock()
    }

    func remove(_ session: String) {
        lock.lock()
        pids.removeValue(forKey: session)
        lock.unlock()
    }
}
