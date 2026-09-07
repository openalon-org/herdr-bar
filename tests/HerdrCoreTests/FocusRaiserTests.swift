import Foundation
import Testing
@testable import HerdrCore

@Suite("FocusRaiser session matching")
struct FocusRaiserTests {
    @Test func sessionNameFromStandardSockets() {
        #expect(FocusRaiser.sessionName(fromSocketPath: "/Users/me/.config/herdr/herdr.sock") == "default")
        #expect(FocusRaiser.sessionName(fromSocketPath: "/Users/me/.config/herdr/sessions/work/herdr.sock") == "work")
        #expect(FocusRaiser.sessionName(fromSocketPath: "/tmp/herdr-demo.sock") == "default")
    }

    @Test func clientLogSitsBesideSocket() {
        #expect(
            FocusRaiser.clientLogPath(forSocketPath: "/Users/me/.config/herdr/herdr.sock")
                == "/Users/me/.config/herdr/herdr-client.log"
        )
        #expect(
            FocusRaiser.clientLogPath(forSocketPath: "/Users/me/.config/herdr/sessions/work/herdr.sock")
                == "/Users/me/.config/herdr/sessions/work/herdr-client.log"
        )
    }

    @Test func defaultTUIIsBareHerdr() {
        #expect(FocusRaiser.isHerdrTUIClient(command: "herdr", sessionName: "default"))
        #expect(FocusRaiser.isHerdrTUIClient(command: "/Users/me/.local/bin/herdr", sessionName: "default"))
        #expect(!FocusRaiser.isHerdrTUIClient(command: "herdr server", sessionName: "default"))
        #expect(!FocusRaiser.isHerdrTUIClient(command: "herdr session attach work", sessionName: "default"))
        #expect(FocusRaiser.isHerdrTUIClient(command: "herdr session attach default", sessionName: "default"))
    }

    @Test func namedTUIMatchesAttachArgv() {
        #expect(FocusRaiser.isHerdrTUIClient(command: "herdr session attach work", sessionName: "work"))
        #expect(FocusRaiser.isHerdrTUIClient(
            command: "/Users/me/.local/bin/herdr session attach work",
            sessionName: "work"
        ))
        #expect(!FocusRaiser.isHerdrTUIClient(command: "herdr session attach work", sessionName: "other"))
        #expect(!FocusRaiser.isHerdrTUIClient(command: "herdr", sessionName: "work"))
        #expect(!FocusRaiser.isHerdrTUIClient(command: "herdr server", sessionName: "work"))
    }

    @Test func parseProcArgs2ReadsArgv() {
        var buf = [CChar](repeating: 0, count: 64)
        let argc: Int32 = 4
        withUnsafeBytes(of: argc) { raw in
            for (i, byte) in raw.enumerated() { buf[i] = CChar(bitPattern: byte) }
        }
        let exec = "/Users/me/.local/bin/herdr"
        let args = ["herdr", "session", "attach", "work"]
        var i = 4
        for byte in exec.utf8 { buf[i] = CChar(bitPattern: byte); i += 1 }
        i += 1
        i += 3
        for arg in args {
            for byte in arg.utf8 { buf[i] = CChar(bitPattern: byte); i += 1 }
            i += 1
        }
        #expect(FocusRaiser.parseProcArgs2(buf, length: i) == "herdr session attach work")
    }
}
