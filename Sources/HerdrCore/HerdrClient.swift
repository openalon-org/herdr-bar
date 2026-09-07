import Darwin
import Foundation

/// Newline-delimited JSON-RPC over a Unix domain socket.
///
/// Herdr closes request sockets after one response. Subscribe sockets stay open
/// and emit events with no `id`; those are treated as invalidation signals.
public final class HerdrClient: @unchecked Sendable {
    public enum ClientError: Error, LocalizedError {
        case invalidJSON
        case herdr(String)
        case timeout
        case disconnected
        case emptyResponse

        public var errorDescription: String? {
            switch self {
            case .invalidJSON: "Herdr returned invalid JSON"
            case .herdr(let message): message
            case .timeout: "Herdr request timed out"
            case .disconnected: "Herdr socket disconnected"
            case .emptyResponse: "Herdr returned no response"
            }
        }
    }

    private struct Envelope: Decodable {
        var id: String?
        var result: AgentListResult?
        var error: RPCError?
        var event: String?
    }

    private struct RPCError: Decodable {
        var message: String?
        var code: String?
    }

    private struct AgentListResult: Decodable {
        var agents: [AgentDTO]?
    }

    private let socketPath: String
    private let sessionName: String
    private let timeout: TimeInterval

    public init(socketPath: String, sessionName: String, timeout: TimeInterval = 3) {
        self.socketPath = socketPath
        self.sessionName = sessionName
        self.timeout = timeout
    }

    public func listAgents() throws -> [Agent] {
        let payload = try request(
            method: "agent.list",
            params: [:] as [String: String],
            keepOpen: false
        )
        return payload.agents
    }

    public func focus(target: String) throws {
        _ = try request(
            method: "agent.focus",
            params: ["target": target],
            keepOpen: false
        )
    }

    /// Connects a long-lived subscribe socket. `onEvent` is invoked on a background
    /// queue for every event (payload without `id`). Returns a handle that closes
    /// the socket when cancelled.
    public func subscribe(
        agents: [Agent],
        onEvent: @escaping @Sendable () -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) -> SubscribeHandle {
        let handle = SubscribeHandle()
        let path = socketPath
        let subscriptions = HerdrLogic.subscriptions(for: agents)
        let timeout = timeout
        Thread.detachNewThread {
            do {
                let fd = try connectUnix(path: path, timeout: timeout)
                handle.setFileDescriptor(fd)
                let id = "herdr-bar:\(Int(Date().timeIntervalSince1970 * 1000)):subscribe"
                let body: [String: Any] = [
                    "id": id,
                    "method": "events.subscribe",
                    "params": ["subscriptions": subscriptions],
                ]
                try writeJSONLine(fd: fd, object: body)
                while !handle.isCancelled {
                    // Subscribe sockets stay open; block until the next event line.
                    guard let line = try readLine(fd: fd, timeout: .infinity) else { break }
                    let data = Data(line.utf8)
                    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
                    if let error = envelope.error {
                        onError(ClientError.herdr(error.message ?? "Herdr subscription failed"))
                        break
                    }
                    if envelope.id == nil {
                        onEvent()
                    }
                }
            } catch {
                if !handle.isCancelled {
                    onError(error)
                }
            }
            handle.close()
        }
        return handle
    }

    private struct RequestResult {
        var agents: [Agent]
    }

    private func request(method: String, params: [String: String], keepOpen: Bool) throws -> RequestResult {
        let fd = try connectUnix(path: socketPath, timeout: timeout)
        defer { if !keepOpen { close(fd) } }
        let id = "herdr-bar:\(Int(Date().timeIntervalSince1970 * 1000)):\(method)"
        let body: [String: Any] = [
            "id": id,
            "method": method,
            "params": params,
        ]
        try writeJSONLine(fd: fd, object: body)
        guard let line = try readLine(fd: fd, timeout: timeout) else {
            throw ClientError.emptyResponse
        }
        let data = Data(line.utf8)
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ClientError.invalidJSON
        }
        if let error = envelope.error {
            throw ClientError.herdr(error.message ?? "Herdr request failed")
        }
        let agents = (envelope.result?.agents ?? []).compactMap { $0.asAgent(sessionName: sessionName) }
        return RequestResult(agents: agents)
    }
}

public final class SubscribeHandle: @unchecked Sendable {
    private var fd: Int32 = -1
    private let lock = NSLock()
    private var cancelled = false

    fileprivate func setFileDescriptor(_ value: Int32) {
        lock.lock()
        if cancelled {
            lock.unlock()
            Darwin.close(value)
            return
        }
        fd = value
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let current = fd
        fd = -1
        lock.unlock()
        if current >= 0 { Darwin.close(current) }
    }

    fileprivate func close() {
        lock.lock()
        let current = fd
        fd = -1
        lock.unlock()
        if current >= 0 { Darwin.close(current) }
    }
}

private func connectUnix(path: String, timeout: TimeInterval) throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let maxLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
    let utf8 = Array(path.utf8)
    guard utf8.count <= maxLen else {
        close(fd)
        throw POSIXError(.ENAMETOOLONG)
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: maxLen + 1) { cptr in
            for (i, byte) in utf8.enumerated() {
                cptr[i] = CChar(bitPattern: byte)
            }
            cptr[utf8.count] = 0
        }
    }

    var raw = addr
    let size = socklen_t(MemoryLayout<sockaddr_un>.size)
    let ok = withUnsafePointer(to: &raw) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
            Darwin.connect(fd, sockaddrPtr, size)
        }
    }
    if ok != 0 {
        let code = errno
        close(fd)
        throw POSIXError(POSIXError.Code(rawValue: code) ?? .ECONNREFUSED)
    }

    var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    return fd
}

private func writeJSONLine(fd: Int32, object: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [])
    var payload = data
    payload.append(0x0A)
    try payload.withUnsafeBytes { raw in
        var written = 0
        let bytes = raw.bindMemory(to: UInt8.self)
        while written < bytes.count {
            let n = Darwin.write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
            if n <= 0 { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }
            written += n
        }
    }
}

private func readLine(fd: Int32, timeout: TimeInterval) throws -> String? {
    if timeout.isInfinite {
        var tv = timeval(tv_sec: 0, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    } else {
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }
    var buffer: [UInt8] = []
    var byte: UInt8 = 0
    while true {
        let n = Darwin.read(fd, &byte, 1)
        if n == 0 { return buffer.isEmpty ? nil : String(bytes: buffer, encoding: .utf8) }
        if n < 0 {
            if errno == EINTR { continue }
            if errno == EAGAIN || errno == EWOULDBLOCK { throw HerdrClient.ClientError.timeout }
            throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO)
        }
        if byte == 0x0A { break }
        buffer.append(byte)
    }
    return String(bytes: buffer, encoding: .utf8)
}
