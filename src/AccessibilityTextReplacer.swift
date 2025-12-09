import AppKit
import ApplicationServices
import Foundation

final class AccessibilityTextReplacer {

    static func hasAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        log("Accessibility permission check: \(trusted ? "granted" : "not granted")")
        return trusted
    }

    static func requestAccessibilityPermission() {
        log("Requesting accessibility permission from user prompt")
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func expandSnippetsInFocusedElement(snippets: [String: String]) {
        log("Attempting to expand snippets in focused element")
        guard let element = focusedUIElement(),
              let fullText = readValue(of: element)
        else {
            log("No focused element or readable value found; skipping expansion")
            return
        }

        let selectedRange = readSelectedRange(of: element)
            ?? NSRange(location: fullText.count, length: 0)
        log("Selected range before expansion: \(selectedRange.location)-\(selectedRange.location + selectedRange.length)")

        let lineRange = currentLineRange(in: fullText, cursorLocation: selectedRange.location)
        log("Current line range: \(lineRange.location)-\(lineRange.location + lineRange.length)")
        let currentLine = (fullText as NSString).substring(with: lineRange)

        var replacedLine = currentLine
        for (key, val) in snippets {
            replacedLine = replacedLine.replacingOccurrences(of: key, with: val)
        }

        guard replacedLine != currentLine else {
            log("No snippet expansions applied on current line")
            return
        }

        let newFullText = (fullText as NSString)
            .replacingCharacters(in: lineRange, with: replacedLine)

        setValue(newFullText, of: element)
        log("Replaced line '\(currentLine)' with '\(replacedLine)'")

        let newCursor = lineRange.location + (replacedLine as NSString).length
        setSelectedRange(NSRange(location: newCursor, length: 0), of: element)
        log("Updated cursor position to \(newCursor)")
    }

    // MARK: Focused element

    private func focusedUIElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard err == .success, let el = focused else {
            log("Failed to fetch focused UI element: \(err.rawValue)")
            return nil
        }
        log("Focused UI element obtained")
        return (el as! AXUIElement)
    }

    // MARK: Read / write AX values

    private func readValue(of element: AXUIElement) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard err == .success else {
            log("Failed to read value attribute: \(err.rawValue)")
            return nil
        }
        log("Read value attribute successfully")
        return value as? String
    }

    private func setValue(_ string: String, of element: AXUIElement) {
        AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            string as CFTypeRef
        )
        log("Set value attribute on focused element")
    }

    private func readSelectedRange(of element: AXUIElement) -> NSRange? {
        var sel: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &sel
        )
        guard err == .success, let axRange = sel else {
            log("Failed to read selected text range: \(err.rawValue)")
            return nil
        }

        var cfRange = CFRange()
        if AXValueGetValue(axRange as! AXValue, .cfRange, &cfRange) {
            log("Selected range read as \(cfRange.location)-\(cfRange.location + cfRange.length)")
            return NSRange(location: cfRange.location, length: cfRange.length)
        }
        log("Unable to convert selected text range to CFRange")
        return nil
    }

    private func setSelectedRange(_ range: NSRange, of element: AXUIElement) {
        var cfRange = CFRange(location: range.location, length: range.length)
        if let axValue = AXValueCreate(.cfRange, &cfRange) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                axValue
            )
            log("Set selected range to \(range.location)-\(range.location + range.length)")
        } else {
            log("Failed to create AXValue for selected range")
        }
    }

    // MARK: Line helper

    private func currentLineRange(in text: String, cursorLocation: Int) -> NSRange {
        let nsText = text as NSString
        let length = nsText.length
        let cursor = min(max(cursorLocation, 0), length)

        var start = cursor
        while start > 0 {
            let ch = nsText.character(at: start - 1)
            if ch == 10 || ch == 13 { break } // \n or \r
            start -= 1
        }

        var end = cursor
        while end < length {
            let ch = nsText.character(at: end)
            if ch == 10 || ch == 13 { break }
            end += 1
        }

        log("Computed current line range within \(length) characters")
        return NSRange(location: start, length: end - start)
    }
}
