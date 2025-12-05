import Foundation

func parseKeyValueFile(at url: URL) throws -> [String: String] {
    let text = try String(contentsOf: url, encoding: .utf8)
    var result: [String: String] = [:]

    for rawLine in text.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { continue }
        if line.hasPrefix("#") || line.hasPrefix("//") || line.hasPrefix(";") { continue }

        // Split on first "=" only
        guard let eqIndex = line.firstIndex(of: "=") else { continue }
        let key = line[..<eqIndex].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)

        if !key.isEmpty {
            result[String(key)] = String(value)
        }
    }

    return result
}
