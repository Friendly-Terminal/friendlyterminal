import Foundation
import Observation

@Observable
@MainActor
final class AgentInstallChecker {
    static let shared = AgentInstallChecker(profile: AgentRegistry.claude)
    private static var instances: [String: AgentInstallChecker] = [:]

    static func shared(for profile: AgentProfile) -> AgentInstallChecker {
        if profile.id == AgentRegistry.claude.id { return shared }
        if let existing = instances[profile.id] { return existing }
        let checker = AgentInstallChecker(profile: profile)
        instances[profile.id] = checker
        return checker
    }

    enum InstallStatus: Equatable {
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
        case notApplicable
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

    let profile: AgentProfile
    private(set) var installStatus: InstallStatus = .unknown
    private(set) var nodeStatus: NodeStatus = .unknown
    private(set) var authStatus: AuthStatus = .unknown
    private(set) var mcpStatus: MCPStatus = .unknown
    private var generation = 0

    init(profile: AgentProfile) {
        self.profile = profile
    }

    func check() {
        guard case .unknown = installStatus else { return }
        installStatus = .checking
        generation += 1
        let gen = generation
        Task { [weak self] in
            await self?.runAllProbes(gen)
        }
    }

    func forceRecheck() {
        installStatus = .unknown
        nodeStatus = .unknown
        authStatus = .unknown
        mcpStatus = .unknown
        check()
    }

    private func runAllProbes(_ gen: Int) async {
        let profile = self.profile
        async let c = Self.probeInstall(profile)
        async let n = Self.probeNode(profile)
        async let a = Self.probeAuth(profile)
        async let m = Self.probeMCP(profile)
        let (install, node, auth, mcp) = await (c, n, a, m)
        guard gen == generation else { return }
        installStatus = install
        nodeStatus = node
        authStatus = auth
        mcpStatus = mcp
    }

    // Reads stdout to EOF before waiting so a full pipe can't deadlock;
    // terminates the process after `timeout`.
    nonisolated private static func runShell(
        _ script: String, timeout: TimeInterval = 15
    ) -> (status: Int32, output: String)? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", script]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        killer.cancel()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (p.terminationStatus, output)
    }

    nonisolated private static func probeInstall(_ profile: AgentProfile) async -> InstallStatus {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let names = profile.binaryNames.joined(separator: " ")
                let versionArgs = profile.versionProbe.dropFirst().joined(separator: " ")
                let script = """
                    for b in \(names); do \
                    p=$(command -v "$b" 2>/dev/null) || continue; \
                    echo "$p"; "$p" \(versionArgs) 2>/dev/null | head -1; break; \
                    done
                    """
                let output = Self.runShell(script)?.output ?? ""
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

                if !lines.isEmpty {
                    let path = lines[0]
                    let version = lines.count > 1 ? lines[1] : nil
                    cont.resume(returning: .installed(path: path, version: version))
                    return
                }

                if profile.id == AgentRegistry.claude.id {
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
                }
                cont.resume(returning: .notInstalled)
            }
        }
    }

    nonisolated private static func probeNode(_ profile: AgentProfile) async -> NodeStatus {
        guard profile.requiresNode else { return .notApplicable }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                guard let result = Self.runShell("node --version 2>/dev/null"),
                      result.status == 0, !result.output.isEmpty else {
                    cont.resume(returning: .notInstalled)
                    return
                }
                cont.resume(returning: .installed(version: result.output))
            }
        }
    }

    nonisolated private static func probeAuth(_ profile: AgentProfile) async -> AuthStatus {
        guard let auth = profile.authProbe else { return .unknown }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let dir = "\(home)/\(auth.homeRelativeDir)"
        guard FileManager.default.fileExists(atPath: dir) else {
            return .notAuthenticated
        }
        guard !auth.credentialFiles.isEmpty else { return .unknown }
        for file in auth.credentialFiles {
            let path = "\(dir)/\(file)"
            if FileManager.default.fileExists(atPath: path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int, size > 10 {
                return .authenticated
            }
        }
        // Credentials may live elsewhere (Keychain, env vars) — can't confirm either way.
        return .unknown
    }

    nonisolated private static func probeMCP(_ profile: AgentProfile) async -> MCPStatus {
        guard let mcp = profile.mcpProbe else { return .unknown }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        for relative in mcp.configFiles {
            let path = "\(home)/\(relative)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = json[mcp.jsonKey] as? [String: Any]
            else { continue }
            return .configured(count: servers.count)
        }
        return .none
    }
}
