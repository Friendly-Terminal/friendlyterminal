import Foundation

struct AgentSlashCommand: Equatable, Sendable {
    let label: String
    let sendText: String
    let help: String
}

struct AgentAuthProbe: Equatable, Sendable {
    let homeRelativeDir: String
    let credentialFiles: [String]
}

struct AgentMCPProbe: Equatable, Sendable {
    let configFiles: [String]
    let jsonKey: String
}

struct AgentProfile: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let binaryNames: [String]
    let versionProbe: [String]
    let requiresNode: Bool
    let dangerFlags: [String]
    let supportsNumberedOptions: Bool
    let slashCommands: [AgentSlashCommand]
    let exitSendText: String
    let exitHint: String
    let symbol: String
    let accentHex: String?
    let authProbe: AgentAuthProbe?
    let mcpProbe: AgentMCPProbe?
}

enum AgentRegistry {
    static let claude = AgentProfile(
        id: "claude",
        displayName: "Claude Code",
        binaryNames: ["claude"],
        versionProbe: ["claude", "--version"],
        requiresNode: true,
        dangerFlags: ["--dangerously-skip-permissions"],
        supportsNumberedOptions: true,
        slashCommands: [
            AgentSlashCommand(label: "/clear",   sendText: "/clear\r",   help: "Clear the conversation history"),
            AgentSlashCommand(label: "/compact", sendText: "/compact\r", help: "Compact context to save tokens"),
            AgentSlashCommand(label: "/help",    sendText: "/help\r",    help: "Show Claude's built-in help"),
            AgentSlashCommand(label: "/init",    sendText: "/init\r",    help: "Create a CLAUDE.md for this project"),
            AgentSlashCommand(label: "/model",   sendText: "/model\r",   help: "Switch the model"),
            AgentSlashCommand(label: "/resume",  sendText: "/resume\r",  help: "Resume a previous conversation"),
        ],
        exitSendText: "/exit\r",
        exitHint: "or press Ctrl+C twice",
        symbol: "sparkles",
        accentHex: nil,
        authProbe: AgentAuthProbe(
            homeRelativeDir: ".claude",
            credentialFiles: [".credentials.json", "auth.json", "credentials.json"]
        ),
        mcpProbe: AgentMCPProbe(
            configFiles: [".claude/settings.json", ".claude.json"],
            jsonKey: "mcpServers"
        )
    )

    static let codex = AgentProfile(
        id: "codex",
        displayName: "Codex",
        binaryNames: ["codex"],
        versionProbe: ["codex", "--version"],
        requiresNode: false,
        dangerFlags: ["--dangerously-bypass-approvals-and-sandbox", "--yolo"],
        supportsNumberedOptions: false,
        slashCommands: [
            AgentSlashCommand(label: "/status",    sendText: "/status\r",    help: "Show session status"),
            AgentSlashCommand(label: "/model",     sendText: "/model\r",     help: "Switch the model"),
            AgentSlashCommand(label: "/approvals", sendText: "/approvals\r", help: "Change the approval policy"),
            AgentSlashCommand(label: "/compact",   sendText: "/compact\r",   help: "Compact context to save tokens"),
            AgentSlashCommand(label: "/diff",      sendText: "/diff\r",      help: "Show pending changes"),
            AgentSlashCommand(label: "/new",       sendText: "/new\r",       help: "Start a new conversation"),
        ],
        exitSendText: "\u{04}",
        exitHint: "or press Ctrl+D",
        symbol: "chevron.left.forwardslash.chevron.right",
        accentHex: "#10A37F",
        authProbe: AgentAuthProbe(homeRelativeDir: ".codex", credentialFiles: ["auth.json"]),
        mcpProbe: nil
    )

    static let gemini = AgentProfile(
        id: "gemini",
        displayName: "Gemini CLI",
        binaryNames: ["gemini"],
        versionProbe: ["gemini", "--version"],
        requiresNode: true,
        dangerFlags: ["--yolo", "-y"],
        supportsNumberedOptions: false,
        slashCommands: [
            AgentSlashCommand(label: "/help",   sendText: "/help\r",   help: "Show Gemini's built-in help"),
            AgentSlashCommand(label: "/tools",  sendText: "/tools\r",  help: "List available tools"),
            AgentSlashCommand(label: "/mcp",    sendText: "/mcp\r",    help: "Show MCP server status"),
            AgentSlashCommand(label: "/memory", sendText: "/memory\r", help: "Manage remembered context"),
            AgentSlashCommand(label: "/stats",  sendText: "/stats\r",  help: "Show session statistics"),
            AgentSlashCommand(label: "/clear",  sendText: "/clear\r",  help: "Clear the conversation"),
        ],
        exitSendText: "/quit\r",
        exitHint: "or press Ctrl+C twice",
        symbol: "sparkle",
        accentHex: "#1A73E8",
        authProbe: AgentAuthProbe(homeRelativeDir: ".gemini", credentialFiles: []),
        mcpProbe: AgentMCPProbe(configFiles: [".gemini/settings.json"], jsonKey: "mcpServers")
    )

    static let qwen = AgentProfile(
        id: "qwen",
        displayName: "Qwen Code",
        binaryNames: ["qwen"],
        versionProbe: ["qwen", "--version"],
        requiresNode: true,
        dangerFlags: ["--yolo"],
        supportsNumberedOptions: false,
        slashCommands: [
            AgentSlashCommand(label: "/help",          sendText: "/help\r",          help: "Show Qwen's built-in help"),
            AgentSlashCommand(label: "/tools",         sendText: "/tools\r",         help: "List available tools"),
            AgentSlashCommand(label: "/mcp",           sendText: "/mcp\r",           help: "Show MCP server status"),
            AgentSlashCommand(label: "/memory",        sendText: "/memory\r",        help: "Manage remembered context"),
            AgentSlashCommand(label: "/stats",         sendText: "/stats\r",         help: "Show session statistics"),
            AgentSlashCommand(label: "/approval-mode", sendText: "/approval-mode\r", help: "Change the approval mode"),
        ],
        exitSendText: "/quit\r",
        exitHint: "or press Ctrl+C twice",
        symbol: "cpu",
        accentHex: "#615CED",
        authProbe: AgentAuthProbe(homeRelativeDir: ".qwen", credentialFiles: []),
        mcpProbe: AgentMCPProbe(configFiles: [".qwen/settings.json"], jsonKey: "mcpServers")
    )

    static let zcode = AgentProfile(
        id: "zcode",
        displayName: "Z-code",
        binaryNames: ["zcode", "zai"],
        versionProbe: ["zcode", "--version"],
        requiresNode: false,
        dangerFlags: [],
        supportsNumberedOptions: false,
        slashCommands: [
            AgentSlashCommand(label: "/help", sendText: "/help\r", help: "Show built-in help"),
        ],
        exitSendText: "\u{04}",
        exitHint: "or press Ctrl+C twice",
        symbol: "sparkles",
        accentHex: nil,
        authProbe: nil,
        mcpProbe: nil
    )

    static let all: [AgentProfile] = [claude, codex, gemini, qwen, zcode]

    // Unquotes while splitting so a quoted path with spaces stays one token.
    static func tokenize(_ stage: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character? = nil
        var inToken = false
        for ch in stage {
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
            } else if ch == "'" || ch == "\"" {
                quote = ch
                inToken = true
            } else if ch == " " || ch == "\t" {
                if inToken { tokens.append(current); current = ""; inToken = false }
            } else {
                current.append(ch)
                inToken = true
            }
        }
        if inToken { tokens.append(current) }
        return tokens
    }

    static func commandName(_ command: String) -> String? {
        let lastStage = command.split(separator: "|").last.map(String.init) ?? command
        let tokens = tokenize(lastStage)
        for token in tokens {
            if token.contains("=") { continue }
            if ["sudo", "command", "exec", "time", "env"].contains(token) { continue }
            return (token as NSString).lastPathComponent.lowercased()
        }
        return nil
    }

    static func match(_ command: String) -> AgentProfile? {
        guard let name = commandName(command) else { return nil }
        return all.first { $0.binaryNames.contains(name) }
    }

    static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
