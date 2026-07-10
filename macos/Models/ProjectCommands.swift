import Foundation

struct ProjectCommandGroup: Identifiable {
    let name: String
    let systemImage: String
    let commands: [ProjectCommand]
    var id: String { name }
}

struct ProjectCommand: Identifiable {
    let label: String
    let command: String
    let systemImage: String
    var id: String { command }
}

enum ProjectCommandDetector {
    static func suggestions(cwd: String, fileItems: [FileItem]) -> [ProjectCommandGroup] {
        let names = Set(fileItems.map(\.name))
        var groups: [ProjectCommandGroup] = []

        if names.contains("package.json") {
            if let group = nodeGroup(cwd: cwd, names: names) {
                groups.append(group)
            }
        }

        if names.contains("requirements.txt") || names.contains("pyproject.toml") || names.contains("setup.py") {
            groups.append(pythonGroup(cwd: cwd, names: names))
        }

        if names.contains("Cargo.toml") {
            groups.append(ProjectCommandGroup(
                name: "Rust", systemImage: "gearshape",
                commands: [
                    ProjectCommand(label: "Run", command: "cargo run", systemImage: "play.fill"),
                    ProjectCommand(label: "Build", command: "cargo build", systemImage: "hammer.fill"),
                    ProjectCommand(label: "Test", command: "cargo test", systemImage: "checkmark.seal.fill"),
                ]
            ))
        }

        if names.contains("go.mod") {
            groups.append(ProjectCommandGroup(
                name: "Go", systemImage: "chevron.left.forwardslash.chevron.right",
                commands: [
                    ProjectCommand(label: "Run", command: "go run .", systemImage: "play.fill"),
                    ProjectCommand(label: "Test", command: "go test ./...", systemImage: "checkmark.seal.fill"),
                    ProjectCommand(label: "Build", command: "go build .", systemImage: "hammer.fill"),
                ]
            ))
        }

        if names.contains("Makefile") {
            groups.append(ProjectCommandGroup(
                name: "Make", systemImage: "hammer",
                commands: makeTargets(cwd: cwd)
            ))
        }

        if names.contains("Gemfile") {
            groups.append(ProjectCommandGroup(
                name: "Ruby", systemImage: "diamond",
                commands: [
                    ProjectCommand(label: "Bundle install", command: "bundle install", systemImage: "square.and.arrow.down"),
                    ProjectCommand(label: "RSpec", command: "bundle exec rspec", systemImage: "checkmark.seal.fill"),
                ]
            ))
        }

        if names.contains("Dockerfile") {
            groups.append(ProjectCommandGroup(
                name: "Docker", systemImage: "shippingbox",
                commands: [
                    ProjectCommand(label: "Build", command: "docker build .", systemImage: "hammer.fill"),
                ]
            ))
        }

        return groups
    }

    private static func nodeGroup(cwd: String, names: Set<String>) -> ProjectCommandGroup? {
        let manager: String
        if names.contains("pnpm-lock.yaml") || names.contains("pnpm-lock.yml") {
            manager = "pnpm"
        } else if names.contains("yarn.lock") {
            manager = "yarn"
        } else {
            manager = "npm"
        }

        var commands: [ProjectCommand] = []

        if !names.contains("node_modules") {
            let installCmd = manager == "npm" ? "npm install" : "\(manager) install"
            commands.append(ProjectCommand(
                label: "Install deps", command: installCmd, systemImage: "square.and.arrow.down"
            ))
        }

        let pkgPath = (cwd as NSString).appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: pkgPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: Any] {

            let priority = ["dev", "start", "serve", "preview", "build", "test", "lint", "check", "format"]
            for key in priority where scripts[key] != nil {
                let cmd = manager == "npm" ? "npm run \(key)" : "\(manager) \(key)"
                commands.append(ProjectCommand(
                    label: key, command: cmd, systemImage: scriptIcon(key)
                ))
            }
            let extra = scripts.keys.filter { !priority.contains($0) }.sorted().prefix(4)
            for key in extra {
                let cmd = manager == "npm" ? "npm run \(key)" : "\(manager) \(key)"
                commands.append(ProjectCommand(label: key, command: cmd, systemImage: "terminal"))
            }
        } else {
            let runDev = manager == "npm" ? "npm run dev" : "\(manager) dev"
            let runTest = manager == "npm" ? "npm test" : "\(manager) test"
            let runBuild = manager == "npm" ? "npm run build" : "\(manager) build"
            commands += [
                ProjectCommand(label: "dev", command: runDev, systemImage: "play.fill"),
                ProjectCommand(label: "test", command: runTest, systemImage: "checkmark.seal.fill"),
                ProjectCommand(label: "build", command: runBuild, systemImage: "hammer.fill"),
            ]
        }

        guard !commands.isEmpty else { return nil }
        let displayName: String
        switch manager {
        case "pnpm": displayName = "pnpm"
        case "yarn": displayName = "Yarn"
        default:     displayName = "Node.js"
        }
        return ProjectCommandGroup(name: displayName, systemImage: "curlybraces", commands: commands)
    }

    private static func pythonGroup(cwd: String, names: Set<String>) -> ProjectCommandGroup {
        var commands: [ProjectCommand] = []

        if names.contains("requirements.txt") {
            commands.append(ProjectCommand(
                label: "pip install", command: "pip install -r requirements.txt",
                systemImage: "square.and.arrow.down"
            ))
        }
        if names.contains("pyproject.toml") || names.contains("setup.py") {
            commands.append(ProjectCommand(
                label: "pip install -e", command: "pip install -e .",
                systemImage: "square.and.arrow.down"
            ))
        }
        if names.contains("manage.py") {
            commands.append(ProjectCommand(
                label: "runserver", command: "python manage.py runserver",
                systemImage: "play.fill"
            ))
        } else if names.contains("app.py") {
            commands.append(ProjectCommand(
                label: "Run app.py", command: "python app.py", systemImage: "play.fill"
            ))
        } else if names.contains("main.py") {
            commands.append(ProjectCommand(
                label: "Run main.py", command: "python main.py", systemImage: "play.fill"
            ))
        }
        commands.append(ProjectCommand(
            label: "pytest", command: "pytest", systemImage: "checkmark.seal.fill"
        ))

        return ProjectCommandGroup(name: "Python", systemImage: "terminal", commands: commands)
    }

    private static func makeTargets(cwd: String) -> [ProjectCommand] {
        let makePath = (cwd as NSString).appendingPathComponent("Makefile")
        guard let content = try? String(contentsOfFile: makePath, encoding: .utf8) else {
            return [ProjectCommand(label: "make", command: "make", systemImage: "play.fill")]
        }

        var targets: [String] = []
        for line in content.components(separatedBy: .newlines) {
            guard !line.hasPrefix("\t"), !line.hasPrefix("#"), !line.hasPrefix(".") else { continue }
            if let colonIdx = line.firstIndex(of: ":") {
                let target = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                if !target.isEmpty && !target.contains(" ") && !target.contains("=") {
                    targets.append(target)
                }
            }
        }

        let limited = targets.prefix(6)
        guard !limited.isEmpty else {
            return [ProjectCommand(label: "make", command: "make", systemImage: "play.fill")]
        }
        return limited.map {
            ProjectCommand(label: "make \($0)", command: "make \($0)", systemImage: scriptIcon($0))
        }
    }

    private static func scriptIcon(_ name: String) -> String {
        switch name {
        case "dev", "start", "serve", "preview", "runserver": return "play.fill"
        case "build":   return "hammer.fill"
        case "test":    return "checkmark.seal.fill"
        case "lint", "check", "format": return "exclamationmark.circle"
        case "clean":   return "trash"
        default:        return "terminal"
        }
    }
}
