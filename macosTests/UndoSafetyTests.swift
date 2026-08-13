import XCTest
@testable import FriendlyTerminal

final class UndoSafetyTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UndoSafetyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    private func makeDir(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - RmInterceptor.safeTargets

    func testRejectsDotAndDotDot() throws {
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf .", cwd: dir.path))
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf ..", cwd: dir.path))
        _ = try makeFile("a.txt")
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf a.txt .", cwd: dir.path))
    }

    func testRejectsCwdAndAncestors() throws {
        let child = try makeDir("child")
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf \(child.path)", cwd: child.path))
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf \(dir.path)", cwd: child.path))
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -rf /", cwd: child.path))
    }

    func testDirectoryRequiresRecursiveOrDirFlag() throws {
        _ = try makeDir("folder")
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm folder", cwd: dir.path))
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm -f folder", cwd: dir.path))
        XCTAssertEqual(RmInterceptor.safeTargets(command: "rm -r folder", cwd: dir.path)?.count, 1)
        XCTAssertEqual(RmInterceptor.safeTargets(command: "rm -d folder", cwd: dir.path)?.count, 1)
        XCTAssertEqual(RmInterceptor.safeTargets(command: "rm folder -r", cwd: dir.path)?.count, 1)
    }

    func testPlainFileNeedsNoFlags() throws {
        _ = try makeFile("a.txt")
        XCTAssertEqual(RmInterceptor.safeTargets(command: "rm a.txt", cwd: dir.path)?.count, 1)
    }

    func testMissingTargetNotIntercepted() {
        XCTAssertNil(RmInterceptor.safeTargets(command: "rm nope.txt", cwd: dir.path))
    }

    // MARK: - UndoPlanner pre-existence

    func testMkdirExistingDirProducesNoPlan() throws {
        _ = try makeDir("exists")
        XCTAssertNil(UndoPlanner.plan(command: "mkdir -p exists", cwd: dir.path))
    }

    func testMkdirPlansOnlyNewDirs() throws {
        _ = try makeDir("exists")
        let plan = UndoPlanner.plan(command: "mkdir -p exists fresh", cwd: dir.path)
        XCTAssertEqual(plan?.actions.count, 1)
    }

    func testZipExistingArchiveProducesNoPlan() throws {
        _ = try makeFile("out.zip")
        _ = try makeFile("a.txt")
        XCTAssertNil(UndoPlanner.plan(command: "zip out.zip a.txt", cwd: dir.path))
        XCTAssertNotNil(UndoPlanner.plan(command: "zip new.zip a.txt", cwd: dir.path))
    }

    func testTarExistingArchiveProducesNoPlan() throws {
        _ = try makeFile("out.tgz")
        XCTAssertNil(UndoPlanner.plan(command: "tar -czf out.tgz src", cwd: dir.path))
        XCTAssertNotNil(UndoPlanner.plan(command: "tar -czf new.tgz src", cwd: dir.path))
    }

    func testCurlExistingOutputProducesNoPlan() throws {
        _ = try makeFile("page.html")
        XCTAssertNil(UndoPlanner.plan(command: "curl -o page.html http://x.test", cwd: dir.path))
        XCTAssertNotNil(UndoPlanner.plan(command: "curl -o fresh.html http://x.test", cwd: dir.path))
    }

    func testGitAddAllFlagsPlanReset() {
        let plan = UndoPlanner.plan(command: "git add -A", cwd: dir.path)
        if case .shell(let cmd)? = plan?.actions.first {
            XCTAssertEqual(cmd, "git reset -q")
        } else {
            XCTFail("expected a shell undo action for git add -A")
        }
        XCTAssertNotNil(UndoPlanner.plan(command: "git add -u", cwd: dir.path))
        XCTAssertNil(UndoPlanner.plan(command: "git add -A file.txt", cwd: dir.path))
        XCTAssertNotNil(UndoPlanner.plan(command: "git add file.txt", cwd: dir.path))
    }

    func testMvOntoExistingFileProducesNoPlan() throws {
        _ = try makeFile("a.txt")
        _ = try makeFile("b.txt")
        XCTAssertNil(UndoPlanner.plan(command: "mv a.txt b.txt", cwd: dir.path))
        XCTAssertNotNil(UndoPlanner.plan(command: "mv a.txt c.txt", cwd: dir.path))
    }

    func testSymlinkToDirInterceptedWithoutRecursiveFlag() throws {
        let target = try makeDir("real")
        let link = dir.appendingPathComponent("mylink")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertEqual(RmInterceptor.safeTargets(command: "rm mylink", cwd: dir.path)?.count, 1)
    }

    func testCpThreeOperandsProducesNoPlan() throws {
        _ = try makeFile("a.txt")
        _ = try makeFile("b.txt")
        _ = try makeDir("dest")
        XCTAssertNil(UndoPlanner.plan(command: "cp a.txt b.txt dest", cwd: dir.path))
    }
}
