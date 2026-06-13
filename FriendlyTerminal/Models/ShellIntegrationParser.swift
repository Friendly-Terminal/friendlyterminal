import Foundation

struct ShellIntegrationParser {

    enum Event {
        case promptStart
        case commandStart
        case outputStart
        case commandEnd(exitCode: Int32)
        case commandText(String)
        case cwdUpdate(String)
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

    static func scan(bytes: [UInt8], handler: (Event) -> Void) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)

        var i = bytes.startIndex

        while i < bytes.endIndex {
            guard bytes[i] == 0x1B else {
                output.append(bytes[i])
                i = bytes.index(after: i)
                continue
            }

            let next = bytes.index(after: i)
            guard next < bytes.endIndex, bytes[next] == 0x5D else {
                output.append(bytes[i])
                i = bytes.index(after: i)
                continue
            }

            var oscEnd: Int? = nil
            let oscBodyStart = bytes.index(after: next)
            var j = oscBodyStart

            while j < bytes.endIndex {
                if bytes[j] == 0x07 {
                    oscEnd = j
                    break
                }
                if bytes[j] == 0x1B {
                    let afterEsc = bytes.index(after: j)
                    if afterEsc < bytes.endIndex, bytes[afterEsc] == 0x5C {
                        oscEnd = j
                        break
                    }
                }
                j = bytes.index(after: j)
            }

            guard let end = oscEnd else {
                output.append(bytes[i])
                i = bytes.index(after: i)
                continue
            }

            let oscBytes = Array(bytes[oscBodyStart..<end])
            if let oscString = String(bytes: oscBytes, encoding: .utf8),
               let event = parse(osc: oscString) {
                handler(event)
                i = bytes.index(after: end)
                if bytes[end] == 0x1B { i = bytes.index(after: i) }
            } else {
                output.append(bytes[i])
                i = bytes.index(after: i)
            }
        }

        return output
    }
}
