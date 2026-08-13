import Foundation
import Observation
import os

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

    // Reads stdout to EOF before waiting so a full pipe can't deadlock. The probe
    // gets its own process group so the timeout can SIGKILL the whole tree —
    // signalling only the shell leaves grandchildren holding the pipe's write end
    // and the read never returns.
    nonisolated static func runShell(
        _ script: String, timeout: TimeInterval = 15
    ) -> (status: Int32, output: String)? {
        var fds: [Int32] = [-1, -1]
        guard pipe(&fds) == 0 else { return nil }
        let (readFD, writeFD) = (fds[0], fds[1])

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attr, 0)

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_adddup2(&actions, writeFD, STDOUT_FILENO)
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addclose(&actions, readFD)
        posix_spawn_file_actions_addclose(&actions, writeFD)

        let args: [String] = ["/bin/zsh", "-l", "-c", script]
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
        var spawned: pid_t = 0
        let rc = posix_spawn(&spawned, "/bin/zsh", &actions, &attr, argv, environ)
        argv.forEach { free($0) }
        posix_spawn_file_actions_destroy(&actions)
        posix_spawnattr_destroy(&attr)
        close(writeFD)
        guard rc == 0 else { close(readFD); return nil }
        let pid = spawned

        let reaped = OSAllocatedUnfairLock(initialState: false)
        let killer = DispatchWorkItem {
            reaped.withLock { if !$0 { kill(-pid, SIGKILL) } }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)

        let data = FileHandle(fileDescriptor: readFD, closeOnDealloc: true).readDataToEndOfFile()
        var raw: Int32 = 0
        while waitpid(pid, &raw, 0) < 0 && errno == EINTR {}
        reaped.withLock { $0 = true }
        killer.cancel()

        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let status = (raw & 0x7F) == 0 ? (raw >> 8) & 0xFF : -1
        return (status, output)
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
