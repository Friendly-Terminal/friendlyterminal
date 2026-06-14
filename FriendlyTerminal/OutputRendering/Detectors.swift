import Foundation

enum ImagePathDetector: OutputDetector {
    static let priority = 10

    private static let imageExtensions = Set([
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg"
    ])

    static func detect(output: String, command: String) -> RenderKind? {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard let lastLine = lines.last else { return nil }

        guard lastLine.hasPrefix("/") else { return nil }
        let ext = (lastLine as NSString).pathExtension.lowercased()
        guard imageExtensions.contains(ext) else { return nil }

        guard FileManager.default.fileExists(atPath: lastLine) else { return nil }

        return .imageFile(URL(fileURLWithPath: lastLine))
    }
}

enum JSONDetector: OutputDetector {
    static let priority = 20

    static func detect(output: String, command: String) -> RenderKind? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }

        guard trimmed.components(separatedBy: .newlines).count >= 2 else { return nil }

        guard let data = trimmed.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else { return nil }

        return .jsonTree
    }
}

enum TableDetector: OutputDetector {
    static let priority = 30

    static let minCols = 3
    static let minRows = 3
    static let maxRows = 500

    static func detect(output: String, command: String) -> RenderKind? {
        let lines = output.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= minRows else { return nil }

        let rows = lines.prefix(maxRows).map { line -> [String] in
            splitIntoColumns(line)
        }

        let colCounts = rows.map(\.count)
        let medianCols = colCounts.sorted()[colCounts.count / 2]
        guard medianCols >= minCols else { return nil }

        let consistent = colCounts.filter { abs($0 - medianCols) <= 2 }.count
        guard Double(consistent) / Double(colCounts.count) > 0.7 else { return nil }

        return .table(rows.map { Array($0) })
    }

    private static func splitIntoColumns(_ line: String) -> [String] {
        let pattern = "  +"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(line.startIndex..., in: line)
            let result = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "\t")
            return result.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }
}

enum FileTreeDetector: OutputDetector {
    static let priority = 40

    static func detect(output: String, command: String) -> RenderKind? {
        if output.contains("├──") || output.contains("└──") || output.contains("│") {
            return .fileTree
        }
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 3 else { return nil }
        let pathLines = lines.filter { $0.hasPrefix("./") || ($0.hasPrefix("/") && $0.contains("/")) }
        if Double(pathLines.count) / Double(lines.count) > 0.8 {
            return .fileTree
        }
        return nil
    }
}
