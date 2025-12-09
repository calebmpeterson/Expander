import Foundation

func parseKeyValueFile(at url: URL) throws -> [String: String] {
    log("Parsing snippets file at \(url.path)")
    let text = try String(contentsOf: url, encoding: .utf8)
    var result: [String: String] = [:]

    for (index, rawLine) in text.split(whereSeparator: \.isNewline).enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { continue }
        if line.hasPrefix("#") || line.hasPrefix("//") || line.hasPrefix(";") {
            log("Skipping comment at line \(index + 1)")
            continue
        }

        // Split on first "=" only
        guard let eqIndex = line.firstIndex(of: "=") else {
            log("Skipping malformed line \(index + 1): \(line)")
            continue
        }
        let key = String(line[..<eqIndex].trimmingCharacters(in: .whitespaces))
        let value = String(line[line.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces))

        if !key.isEmpty {
            result[key] = value
            log("Loaded snippet '\(key)' -> '\(value)' from line \(index + 1)")
        } else {
            log("Skipping line \(index + 1) due to empty key")
        }
    }

    log("Parsed \(result.count) snippet entries from \(url.path)")
    return result
}
