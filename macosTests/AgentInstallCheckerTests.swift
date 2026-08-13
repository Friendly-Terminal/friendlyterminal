import XCTest
@testable import FriendlyTerminal

final class AgentInstallCheckerTests: XCTestCase {

    func testRunShellCapturesOutputAndStatus() {
        let ok = AgentInstallChecker.runShell("echo hello")
        XCTAssertEqual(ok?.output, "hello")
        XCTAssertEqual(ok?.status, 0)
        XCTAssertEqual(AgentInstallChecker.runShell("exit 3")?.status, 3)
    }

    // The backgrounded grandchild outlives a SIGTERM to the shell and keeps the
    // pipe's write end open; only a process-group kill lets the read return.
    func testRunShellTimeoutKillsWedgedGrandchild() {
        let start = Date()
        let result = AgentInstallChecker.runShell("sleep 30 & wait", timeout: 1)
        XCTAssertNotNil(result)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }
}
