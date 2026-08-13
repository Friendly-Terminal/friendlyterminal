import XCTest
@testable import FriendlyTerminal

final class AgentRegistryTests: XCTestCase {

    func testEachToolBasenameMatches() {
        XCTAssertEqual(AgentRegistry.match("claude")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("codex")?.id, "codex")
        XCTAssertEqual(AgentRegistry.match("gemini")?.id, "gemini")
        XCTAssertEqual(AgentRegistry.match("qwen")?.id, "qwen")
        XCTAssertEqual(AgentRegistry.match("zcode")?.id, "zcode")
        XCTAssertEqual(AgentRegistry.match("zai")?.id, "zcode")
    }

    func testMatchIsCaseInsensitive() {
        XCTAssertEqual(AgentRegistry.match("CLAUDE")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("Gemini")?.id, "gemini")
    }

    func testPathPrefixedBasenameMatches() {
        XCTAssertEqual(AgentRegistry.match("/usr/local/bin/claude")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("/opt/homebrew/bin/codex --version")?.id, "codex")
        XCTAssertEqual(AgentRegistry.match("~/.local/bin/qwen")?.id, "qwen")
    }

    func testArgumentsDoNotAffectMatch() {
        XCTAssertEqual(AgentRegistry.match("claude --dangerously-skip-permissions")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("codex --yolo")?.id, "codex")
        XCTAssertEqual(AgentRegistry.match("gemini -y")?.id, "gemini")
    }

    func testQuotedPathsWithSpacesMatch() {
        XCTAssertEqual(AgentRegistry.match("'/Users/x/My Tools/claude'")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("\"/Users/x/My Tools/claude\" --resume")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("sudo '/opt/some dir/codex' --yolo")?.id, "codex")
        XCTAssertNil(AgentRegistry.match("'/Users/x/My Tools/claudia'"))
    }

    func testPipeUsesLastStage() {
        XCTAssertEqual(AgentRegistry.match("echo hi | claude")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("cat prompt.txt | codex")?.id, "codex")
        XCTAssertNil(AgentRegistry.match("claude | grep foo"))
    }

    func testSkipsEnvAssignmentsAndWrappers() {
        XCTAssertEqual(AgentRegistry.match("FOO=bar claude")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("sudo claude")?.id, "claude")
        XCTAssertEqual(AgentRegistry.match("command gemini")?.id, "gemini")
        XCTAssertEqual(AgentRegistry.match("exec qwen")?.id, "qwen")
        XCTAssertEqual(AgentRegistry.match("time codex")?.id, "codex")
        XCTAssertEqual(AgentRegistry.match("env FOO=bar sudo claude --resume")?.id, "claude")
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(AgentRegistry.match("vim"))
        XCTAssertNil(AgentRegistry.match("ls -la"))
        XCTAssertNil(AgentRegistry.match(""))
        XCTAssertNil(AgentRegistry.match("FOO=bar"))
        XCTAssertNil(AgentRegistry.match("claudia"))
    }

    func testDangerFlagsPerProfile() {
        XCTAssertEqual(AgentRegistry.claude.dangerFlags, ["--dangerously-skip-permissions"])
        XCTAssertTrue(AgentRegistry.codex.dangerFlags.contains("--yolo"))
        XCTAssertTrue(AgentRegistry.zcode.dangerFlags.isEmpty)
    }

    // Canonical strings copied from windows/src/FriendlyTerminal.Core/Agents/AgentRegistry.cs
    func testCodexSlashCommandsMatchWindowsCanon() {
        XCTAssertEqual(
            AgentRegistry.codex.slashCommands.map { [$0.label, $0.sendText, $0.help] },
            [
                ["/status", "/status\r", "Show session status"],
                ["/model", "/model\r", "Switch the model"],
                ["/approvals", "/approvals\r", "Change the approval policy"],
                ["/compact", "/compact\r", "Compact context to save tokens"],
                ["/diff", "/diff\r", "Show pending changes"],
                ["/new", "/new\r", "Start a new conversation"],
            ]
        )
    }

    func testBaselineProfileStaysMinimal() {
        XCTAssertEqual(AgentRegistry.zcode.slashCommands.map(\.label), ["/help"])
        XCTAssertFalse(AgentRegistry.zcode.supportsNumberedOptions)
    }
}
