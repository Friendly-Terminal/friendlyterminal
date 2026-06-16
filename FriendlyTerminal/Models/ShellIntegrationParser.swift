import Foundation

struct ShellIntegrationParser {

    enum Event {
        case promptStart
        case commandStart
        case outputStart
        case commandEnd(exitCode: Int32)
        case commandText(String)
        case cwdUpdate(String)
        case output(String)
        case altScreen(Bool)
        case bracketedPaste(Bool)
    }

    static func parse(osc: String) -> Event? {
        if osc == "133;A" { return .promptStart }
        if osc == "133;B" { return .commandStart }
        if osc == "133;C" { return .outputStart }

        if osc.hasPrefix("133;D") {
            if osc == "133;D" {
                return .commandEnd(exitCode: 0)
            }
            let rest = String(osc.dropFirst("133;D;".count))
            let code = Int32(rest) ?? 0
            return .commandEnd(exitCode: code)
        }

        if osc.hasPrefix("633;E;") {
            let b64 = String(osc.dropFirst("633;E;".count))
            guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
                  let text = String(data: data, encoding: .utf8)
            else { return nil }
            return .commandText(text)
        }

        if osc.hasPrefix("7;") {
            var urlString = String(osc.dropFirst(2))
            if let url = URL(string: urlString), url.isFileURL {
                urlString = url.path
            }
            return .cwdUpdate(urlString)
        }

        return nil
    }

    /// Stateful scanner that consumes the raw PTY byte stream in arbitrarily sized
    /// chunks. It pulls the shell-integration OSC markers (133/633/7) out as events,
    /// discards ANSI styling/cursor escapes, and reports the remaining visible text
    /// as `.output` events. Incomplete escape or UTF-8 sequences at a chunk boundary
    /// are buffered and re-processed when the next chunk arrives.
    final class Stream {
        private var pending: [UInt8] = []

        func feed(_ incoming: ArraySlice<UInt8>) -> [Event] {
            var bytes = pending
            bytes.append(contentsOf: incoming)
            pending = []

            var events: [Event] = []
            var text: [UInt8] = []

            func flushText() {
                guard !text.isEmpty else { return }
                let raw = String(decoding: text, as: UTF8.self)
                let normalized = raw
                    .replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "")
                if !normalized.isEmpty {
                    events.append(.output(normalized))
                }
                text = []
            }

            let n = bytes.count
            var i = 0
            var brokeEarly = false

            while i < n {
                let b = bytes[i]

                guard b == 0x1B else {
                    text.append(b)
                    i += 1
                    continue
                }

                // ESC: need at least one more byte to classify the sequence.
                guard i + 1 < n else {
                    pending = Array(bytes[i...])
                    brokeEarly = true
                    break
                }

                let c = bytes[i + 1]

                if c == 0x5D {
                    // OSC: ESC ] ... (terminated by BEL or ESC \).
                    var j = i + 2
                    var end: Int? = nil
                    var terminatorLen = 1
                    var incomplete = false
                    while j < n {
                        if bytes[j] == 0x07 {
                            end = j; terminatorLen = 1; break
                        }
                        if bytes[j] == 0x1B {
                            if j + 1 < n {
                                if bytes[j + 1] == 0x5C { end = j; terminatorLen = 2; break }
                            } else {
                                incomplete = true; break
                            }
                        }
                        j += 1
                    }
                    guard let e = end, !incomplete else {
                        pending = Array(bytes[i...])
                        brokeEarly = true
                        break
                    }
                    let body = Array(bytes[(i + 2)..<e])
                    if let str = String(bytes: body, encoding: .utf8),
                       let event = parse(osc: str) {
                        flushText()
                        events.append(event)
                    }
                    // Recognized or not, the OSC is control data — drop it from output.
                    i = e + terminatorLen
                    continue
                } else if c == 0x5B {
                    // CSI: ESC [ ... <final byte 0x40-0x7E>.
                    var j = i + 2
                    var end: Int? = nil
                    while j < n {
                        let bj = bytes[j]
                        if bj >= 0x40 && bj <= 0x7E { end = j; break }
                        j += 1
                    }
                    guard let e = end else {
                        pending = Array(bytes[i...])
                        brokeEarly = true
                        break
                    }
                    // Detect interactivity signals. Full-screen programs (vim,
                    // less, top) switch to the alternate screen; raw-mode programs
                    // that render inline (Claude Code, REPLs) instead turn on
                    // bracketed-paste mode. Both mean "this program wants the
                    // keyboard."
                    let finalByte = bytes[e]
                    if finalByte == 0x68 || finalByte == 0x6C { // 'h' (set) / 'l' (reset)
                        let isSet = finalByte == 0x68
                        let body = String(decoding: bytes[(i + 2)..<e], as: UTF8.self)
                        if body == "?1049" || body == "?1047" || body == "?47" {
                            flushText()
                            events.append(.altScreen(isSet))
                        } else if body == "?2004" {
                            flushText()
                            events.append(.bracketedPaste(isSet))
                        }
                    }
                    i = e + 1
                    continue
                } else if c == 0x28 || c == 0x29 {
                    // Charset designation: ESC ( X / ESC ) X (3 bytes).
                    guard i + 2 < n else {
                        pending = Array(bytes[i...])
                        brokeEarly = true
                        break
                    }
                    i += 3
                    continue
                } else {
                    // Other two-byte escape (ESC =, ESC >, ESC M, ...).
                    i += 2
                    continue
                }
            }

            // If we consumed everything cleanly, hold back any trailing bytes that
            // form an incomplete UTF-8 scalar so we don't emit replacement chars.
            if !brokeEarly {
                let keep = incompleteUTF8TailLength(text)
                if keep > 0 {
                    pending = Array(text.suffix(keep))
                    text.removeLast(keep)
                }
            }

            flushText()
            return events
        }

        private func incompleteUTF8TailLength(_ b: [UInt8]) -> Int {
            var idx = b.count - 1
            var continuations = 0
            while idx >= 0 && (b[idx] & 0xC0) == 0x80 {
                continuations += 1
                idx -= 1
                if continuations > 3 { return 0 }
            }
            guard idx >= 0 else { return 0 }

            let lead = b[idx]
            let expectedContinuations: Int
            if lead & 0x80 == 0 { return 0 }
            else if lead & 0xE0 == 0xC0 { expectedContinuations = 1 }
            else if lead & 0xF0 == 0xE0 { expectedContinuations = 2 }
            else if lead & 0xF8 == 0xF0 { expectedContinuations = 3 }
            else { return 0 }

            return continuations < expectedContinuations ? continuations + 1 : 0
        }
    }
}
