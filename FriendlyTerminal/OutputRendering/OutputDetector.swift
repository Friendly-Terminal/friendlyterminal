import Foundation

protocol OutputDetector {
    static func detect(output: String, command: String, cwd: String) -> RenderKind?
}

enum OutputRenderingPipeline {
    @MainActor
    static func process(_ block: CommandBlock) {
        let text = block.plainText
        let cmd  = block.command
        let cwd  = block.cwd

        guard !text.isEmpty else { return }

        // Command-specific "list" detectors run first so their output isn't
        // mistaken for a generic table/file-tree.
        if let kind = LsListingDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = GitBranchDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = GitStatusDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = GitLogOnelineDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = GitTagDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = BrewListDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = HistoryDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }

        if let kind = CatImageDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = ImagePathDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = JSONDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = CSVDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = TableDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
        if let kind = FileTreeDetector.detect(output: text, command: cmd, cwd: cwd) {
            block.renderKind = kind
            return
        }
    }
}
