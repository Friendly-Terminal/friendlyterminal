import XCTest
@testable import FriendlyTerminal

final class ShellIntegrationParserTests: XCTestCase {

    private func output(_ events: [ShellIntegrationParser.Event]) -> String {
        events.compactMap {
            if case .output(let s) = $0 { return s }
            return nil
        }.joined()
    }

    func testOSC7FileURLIsPercentDecoded() {
        XCTAssertEqual(ShellIntegrationParser.decodeFileURL("file:///tmp/a%20b"), "/tmp/a b")
        XCTAssertEqual(ShellIntegrationParser.decodeFileURL("file://localhost/tmp/x"), "/tmp/x")
    }

    func testOSC7RawPathIsNotPercentDecoded() {
        XCTAssertEqual(ShellIntegrationParser.decodeFileURL("/tmp/a%20b"), "/tmp/a%20b")
        XCTAssertEqual(ShellIntegrationParser.decodeFileURL("/tmp/100%"), "/tmp/100%")
        XCTAssertNil(ShellIntegrationParser.decodeFileURL("relative/path"))
    }

    func testCRLFWithONLCRDoublingKeepsLineContent() {
        let stream = ShellIntegrationParser.Stream()
        let events = stream.feed(ArraySlice(Array("HTTP/1.1 200 OK\r\r\nContent-Type: text\r\r\n".utf8)))
        XCTAssertEqual(output(events), "HTTP/1.1 200 OK\nContent-Type: text\n")
        XCTAssertFalse(events.contains { if case .outputDiscardLine = $0 { return true }; return false })
    }

    func testLoneCROverwritesPendingLine() {
        let stream = ShellIntegrationParser.Stream()
        let events = stream.feed(ArraySlice(Array("progress 10%\rprogress 99%\n".utf8)))
        XCTAssertEqual(output(events), "progress 99%\n")
    }

    func testUnterminatedDCSAbortsAtNextEscape() {
        let stream = ShellIntegrationParser.Stream()
        // ESC P with no ST, then a CSI reset and normal text: text must survive.
        var bytes: [UInt8] = [0x1B, 0x50]
        bytes.append(contentsOf: Array("junk".utf8))
        bytes.append(contentsOf: [0x1B, 0x5B, 0x6D]) // ESC [ m
        bytes.append(contentsOf: Array("after\n".utf8))
        let events = stream.feed(ArraySlice(bytes))
        XCTAssertEqual(output(events), "after\n")
    }

    func testTerminatedDCSIsSwallowed() {
        let stream = ShellIntegrationParser.Stream()
        var bytes: [UInt8] = [0x1B, 0x50]
        bytes.append(contentsOf: Array("payload".utf8))
        bytes.append(contentsOf: [0x1B, 0x5C]) // ST
        bytes.append(contentsOf: Array("ok\n".utf8))
        let events = stream.feed(ArraySlice(bytes))
        XCTAssertEqual(output(events), "ok\n")
    }
}
