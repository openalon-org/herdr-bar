import Darwin
import Foundation
import Testing
@testable import HerdrCore

@Suite("HerdrClient against demo server")
struct HerdrClientTests {
    @Test func listsAgentsFromDemoProtocol() throws {
        try withDemoServer { socket in
            let client = HerdrClient(socketPath: socket, sessionName: "demo")
            let agents = try client.listAgents()
            #expect(agents.count == 4)
            #expect(agents.allSatisfy { $0.sessionName == "demo" })
            #expect(Set(agents.map(\.status)).contains(.working))
            try client.focus(target: agents[0].target)
        }
    }

    @Test func subscribeInvalidatesWithoutPolling() throws {
        try withDemoServer { socket in
            let client = HerdrClient(socketPath: socket, sessionName: "demo")
            let first = try client.listAgents()
            let seq = first.map(\.stateChangeSeq).max() ?? 0
            let gotEvent = expectation()
            let handle = client.subscribe(
                agents: first,
                onEvent: { gotEvent.fulfill() },
                onError: { _ in }
            )
            defer { handle.cancel() }
            #expect(gotEvent.wait(timeout: 8))
            let second = try client.listAgents()
            #expect((second.map(\.stateChangeSeq).max() ?? 0) > seq)
        }
    }
}

private func withDemoServer(_ body: (String) throws -> Void) throws {
    let socket = FileManager.default.temporaryDirectory
        .appendingPathComponent("herdr-demo-\(UUID().uuidString).sock")
        .path
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let script = root.appendingPathComponent("tools/demo-server.py")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["python3", script.path, "--socket", socket, "--interval", "1"]
    let stderr = Pipe()
    process.standardOutput = Pipe()
    process.standardError = stderr
    try process.run()
    defer {
        process.terminate()
        let deadline = Date().addingTimeInterval(1)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit()
        try? FileManager.default.removeItem(atPath: socket)
    }
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: socket) { break }
        Thread.sleep(forTimeInterval: 0.05)
    }
    Thread.sleep(forTimeInterval: 0.1)
    do {
        try body(socket)
    } catch {
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        Issue.record("demo-server stderr: \(err)")
        throw error
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func fulfill() {
        lock.lock()
        value = true
        lock.unlock()
    }
    var isFulfilled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private func expectation() -> Flag { Flag() }

private extension Flag {
    func wait(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isFulfilled { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return isFulfilled
    }
}
