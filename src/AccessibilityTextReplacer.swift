import AppKit
import ApplicationServices
import Foundation

final class AccessibilityTextReplacer {

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func expandSnippetsInFocusedElement(snippets: [String: String]) {
        guard let element = focusedUIElement(),
              let fullText = readValue(of: element)
        else { return }

        let selectedRange = readSelectedRange(of: element)
            ?? NSRange(location: fullText.count, length: 0)

        let lineRange = currentLineRange(in: fullText, cursorLocation: selectedRange.location)
        let currentLine = (fullText as NSString).substring(with: lineRange)

        var replacedLine = currentLine
        for (key, val) in snippets {
            replacedLine = replacedLine.replacingOccurrences(of: key, with: val)
        }

        guard replacedLine != currentLine else { return }

        let newFullText = (fullText as NSString)
            .replacingCharacters(in: lineRange, with: replacedLine)

        setValue(newFullText, of: element)

        let newCursor = lineRange.location + (replacedLine as NSString).length
        setSelectedRange(NSRange(location: newCursor, length: 0), of: element)
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
        guard err == .success, let el = focused else { return nil }
        return (el as! AXUIElement)
    }

    // MARK: Read / write AX values

    private func readValue(of element: AXUIElement) -> String? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    private func setValue(_ string: String, of element: AXUIElement) {
        AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            string as CFTypeRef
        )
    }

    private func readSelectedRange(of element: AXUIElement) -> NSRange? {
        var sel: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &sel
        )
        guard err == .success, let axRange = sel else { return nil }

        var cfRange = CFRange()
        if AXValueGetValue(axRange as! AXValue, .cfRange, &cfRange) {
            return NSRange(location: cfRange.location, length: cfRange.length)
        }
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

        return NSRange(location: start, length: end - start)
    }
}
