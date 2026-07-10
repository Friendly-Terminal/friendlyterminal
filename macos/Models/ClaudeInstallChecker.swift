import Foundation
import Observation

@Observable
@MainActor
final class ClaudeInstallChecker {
    static let shared = ClaudeInstallChecker()

    enum ClaudeStatus: Equatable {
        case unknown
        case checking
        case installed(path: String, version: String?)
        case notInstalled

        var isInstalled: Bool {
            if case .installed = self { return true }
            return false
        }
        var version: String? {
            if case .installed(_, let v) = self { return v }
            return nil
        }
        var path: String? {
            if case .installed(let p, _) = self { return p }
            return nil
        }
    }

    enum NodeStatus: Equatable {
        case unknown
        case installed(version: String)
        case notInstalled

        var isInstalled: Bool {
            if case .installed = self { return true }
            return false
        }
        var version: String? {
            if case .installed(let v) = self { return v }
            return nil
        }
    }

    enum AuthStatus: Equatable {
        case unknown
        case authenticated
        case notAuthenticated
    }

    enum MCPStatus: Equatable {
        case unknown
        case configured(count: Int)
        case none
    }

    private(set) var claudeStatus: ClaudeStatus = .unknown
    private(set) var nodeStatus: NodeStatus = .unknown
    private(set) var authStatus: AuthStatus = .unknown
    private(set) var mcpStatus: MCPStatus = .unknown

    private init() {}

    func check() {
        guard case .unknown = claudeStatus else { return }
        claudeStatus = .checking
        Task { [weak self] in
            await self?.runAllProbes()
        }
    }

    func forceRecheck() {
        claudeStatus = .unknown
        nodeStatus = .unknown
        authStatus = .unknown
        mcpStatus = .unknown
        check()
    }

    private func runAllProbes() async {
        async let c = Self.probeClaudeInstall()
        async let n = Self.probeNode()
        async let a = Self.probeAuth()
        async let m = Self.probeMCP()
        let (claude, node, auth, mcp) = await (c, n, a, m)
        claudeStatus = claude
        nodeStatus = node
        authStatus = auth
        mcpStatus = mcp
    }

    nonisolated private static func probeClaudeInstall() async -> ClaudeStatus {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-l", "-c",
                    "which claude 2>/dev/null && claude --version 2>/dev/null | head -1"]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = Pipe()
                try? p.run()
                p.waitUntilExit()

                let output = String(
                    data: pipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

                if !lines.isEmpty {
                    let path = lines[0]
                    let version = lines.count > 1 ? lines[1] : nil
                    cont.resume(returning: .installed(path: path, version: version))
                    return
                }

                let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
                let candidates = [
                    "/usr/local/bin/claude",
                    "/usr/bin/claude",
                    "\(home)/.local/bin/claude",
                    "\(home)/.npm-global/bin/claude",
                    "\(home)/.npm/bin/claude",
                ]
                for path in candidates where FileManager.default.fileExists(atPath: path) {
                    cont.resume(returning: .installed(path: path, version: nil))
                    return
                }
                cont.resume(returning: .notInstalled)
            }
        }
    }

    nonisolated private static func probeNode() async -> NodeStatus {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-l", "-c", "node --version 2>/dev/null"]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = Pipe()
                try? p.run()
                p.waitUntilExit()
                guard p.terminationStatus == 0 else {
                    cont.resume(returning: .notInstalled)
                    return
                }
                let version = String(
                    data: pipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                cont.resume(returning: version.isEmpty ? .notInstalled : .installed(version: version))
            }
        }
    }

    nonisolated private static func probeAuth() async -> AuthStatus {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let claudeDir = "\(home)/.claude"
        guard FileManager.default.fileExists(atPath: claudeDir) else {
            return .notAuthenticated
        }
        let credentialCandidates = [
            "\(claudeDir)/.credentials.json",
            "\(claudeDir)/auth.json",
            "\(claudeDir)/credentials.json",
        ]
        for path in credentialCandidates {
            if FileManager.default.fileExists(atPath: path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int, size > 10 {
                return .authenticated
            }
        }
        return .unknown
    }

    nonisolated private static func probeMCP() async -> MCPStatus {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [
            "\(home)/.claude/settings.json",
            "\(home)/.claude.json",
        ]
        for path in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = json["mcpServers"] as? [String: Any]
            else { continue }
            return .configured(count: servers.count)
        }
        return .none
    }
}
