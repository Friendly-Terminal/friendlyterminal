import Foundation
import Observation

struct RunningProcess: Identifiable {
    let pid: Int32
    let command: String
    let port: Int
    let friendlyName: String
    let isWebServer: Bool

    var id: String { "\(pid):\(port)" }
}

@Observable
@MainActor
final class ProcessMonitor {
    private(set) var entries: [RunningProcess] = []
    private(set) var isBusy: Bool = false

    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?

    func refresh() {
        isBusy = true
        Task {
            let snap = await Self.load()
            entries = snap
            isBusy = false
        }
    }

    func kill(_ entry: RunningProcess) {
        let pid = entry.pid
        isBusy = true
        Task {
            _ = await Self.terminate(pid: pid)
            try? await Task.sleep(nanoseconds: 700_000_000)
            let snap = await Self.load()
            entries = snap
            isBusy = false
        }
    }

    func startAutoRefresh() {
        refresh()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                refresh()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    nonisolated private static func load() async -> [RunningProcess] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: loadSync())
            }
        }
    }

    nonisolated private static func loadSync() -> [RunningProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do { try process.run() } catch { return [] }
        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return parseOutput(output)
    }

    nonisolated private static func parseOutput(_ output: String) -> [RunningProcess] {
        var result: [RunningProcess] = []
        var seen = Set<String>()
        let lines = output.components(separatedBy: .newlines).dropFirst()

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9 else { continue }

            let command = parts[0]
            guard let pid = Int32(parts[1]) else { continue }
            let name = parts[8]

            guard let colonIdx = name.lastIndex(of: ":"),
                  let port = Int(String(name[name.index(after: colonIdx)...])) else { continue }
            guard port > 0 else { continue }

            let entry = RunningProcess(
                pid: pid,
                command: command,
                port: port,
                friendlyName: Self.friendlyName(command: command, port: port),
                isWebServer: Self.isWebPort(port)
            )
            guard seen.insert(entry.id).inserted else { continue }
            result.append(entry)
        }
        return result.sorted { $0.port < $1.port }
    }

    nonisolated private static func terminate(pid: Int32) async -> Bool {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/kill")
                proc.arguments = ["-TERM", String(pid)]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                try? proc.run()
                proc.waitUntilExit()
                cont.resume(returning: proc.terminationStatus == 0)
            }
        }
    }

    nonisolated private static func friendlyName(command: String, port: Int) -> String {
        switch port {
        case 3000:
            return command.lowercased() == "node" ? "Node.js" : "Dev server"
        case 3001...3999:
            return "Dev server"
        case 4200:
            return "Angular"
        case 4321:
            return "Astro"
        case 5000:
            return command.lowercased() == "python" || command.lowercased() == "python3"
                ? "Flask" : "Dev server"
        case 5173:
            return "Vite"
        case 5432:
            return "PostgreSQL"
        case 6379:
            return "Redis"
        case 8000:
            return "Dev server"
        case 8080:
            return "Web server"
        case 8888:
            return "Jupyter"
        case 9000:
            return "Dev server"
        case 27017:
            return "MongoDB"
        case 3306:
            return "MySQL"
        default:
            switch command.lowercased() {
            case "node":   return "Node.js"
            case "python", "python3": return "Python"
            case "ruby":   return "Ruby"
            case "java":   return "Java"
            case "go":     return "Go"
            default:       return command
            }
        }
    }

    nonisolated private static func isWebPort(_ port: Int) -> Bool {
        let webPorts: Set<Int> = [3000, 3001, 3002, 3003, 4200, 4321, 5000, 5173, 8000, 8080, 8081, 8888, 9000]
        return webPorts.contains(port) || (port >= 1024 && port < 10000 && port != 5432 && port != 6379 && port != 27017 && port != 3306)
    }
}
