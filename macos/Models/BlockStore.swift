import Foundation
import Observation

@Observable
@MainActor
final class BlockStore {
    private(set) var blocks: [CommandBlock] = []
    private(set) var sessionID: UUID = UUID()

    func startBlock(command: String, cwd: String) {
        let block = CommandBlock(command: command, cwd: cwd, sessionID: sessionID)
        blocks.append(block)
    }

    func appendOutput(plain: String, attributed: AttributedString?) {
        guard let block = currentBlock else { return }
        block.plainText += plain
        if let attr = attributed {
            block.outputText += attr
        } else {
            block.outputText += AttributedString(plain)
        }
    }

    func finishBlock(exitCode: Int32) {
        guard let block = currentBlock else { return }
        block.exitCode = exitCode
        block.finishedAt = Date()
        OutputRenderingPipeline.process(block)
        if block.failed {
            block.renderKind = .errorHighlighted
        }
    }

    func newSession() {
        blocks = []
        sessionID = UUID()
    }

    var currentBlock: CommandBlock? { blocks.last(where: { $0.isRunning }) }

    var lastFinishedBlock: CommandBlock? { blocks.last(where: { !$0.isRunning }) }

    var lastUndoableBlock: CommandBlock? {
        blocks.last { $0.undoPlan != nil && !$0.isUndone }
    }

    var visibleBlocks: [CommandBlock] { blocks }

    func block(with id: UUID) -> CommandBlock? { blocks.first { $0.id == id } }

    #if DEBUG
    func appendForPreview(_ block: CommandBlock) {
        blocks.append(block)
    }
    #endif
}
