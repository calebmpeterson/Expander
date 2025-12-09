import AppKit
import Foundation

final class SnippetExpander {
    private var monitor: Any?
    private let replacer = AccessibilityTextReplacer()
    private let fileManager: FileManager
    private let snippetsURL: URL
    private var snippets: [String: String]

    private static let defaultSnippets: [String: String] = [
        ":smile:": "😄",
        ":heart:": "❤️",
        ":thumbsup:": "👍",
        ":fire:": "🔥",
        ":party:": "🥳",
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.snippetsURL = fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".expander/snippets")
        self.snippets = Self.defaultSnippets

        log("Initialized SnippetExpander with snippets file at \(snippetsURL.path)")
        reloadSnippets()
    }

    func start() {
        if !AccessibilityTextReplacer.hasAccessibilityPermission() {
            logError("Accessibility permission not granted")
            fputs("Accessibility permission not granted.\n", stderr)
            fputs("Open System Settings → Privacy & Security → Accessibility and enable Expander.\n", stderr)
            AccessibilityTextReplacer.requestAccessibilityPermission()
            return
        }

        // Trigger expansion on delimiter keys.
        let delimiters: Set<UInt16> = [
            49, // space
            36, // return
            48  // tab
        ]

        log("Starting snippet expansion monitor with delimiters: \(delimiters)")
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if delimiters.contains(event.keyCode) {
                log("Delimiter key pressed with keyCode \(event.keyCode); triggering expansion")
                self.replacer.expandSnippetsInFocusedElement(snippets: self.snippets)
            }
        }

        log("SnippetExpander running. Type :smile: then space/return/tab.")
    }

    func openSnippetsInTextEdit() {
        guard ensureSnippetsFileExists() else { return }

        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let configuration = NSWorkspace.OpenConfiguration()

        log("Opening snippets file in TextEdit at \(snippetsURL.path)")
        NSWorkspace.shared.open(
            [snippetsURL],
            withApplicationAt: textEditURL,
            configuration: configuration
        ) { _, error in
            if let error {
                fputs("Failed to open snippets in TextEdit: \(error)\n", stderr)
                logError("Failed to open snippets in TextEdit: \(error)")
            }
        }
    }

    @discardableResult
    func reloadSnippets() -> Bool {
        log("Reloading snippets from disk")
        guard ensureSnippetsFileExists() else {
            snippets = Self.defaultSnippets
            log("Snippets file missing; reverted to default snippets")
            return false
        }

        do {
            let parsed = try parseKeyValueFile(at: snippetsURL)
            snippets = parsed.isEmpty ? Self.defaultSnippets : parsed
            log("Reloaded \(snippets.count) snippets from \(snippetsURL.path).")
            return true
        } catch {
            fputs("Failed to read snippets from \(snippetsURL.path): \(error)\n", stderr)
            logError("Failed to read snippets from \(snippetsURL.path): \(error)")
            snippets = Self.defaultSnippets
            return false
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            log("Stopped global keyDown monitor")
        }
    }

    func allSnippets() -> [(key: String, value: String)] {
        let sorted = snippets.sorted { $0.key < $1.key }
        log("Returning sorted snippets list (\(sorted.count) items)")
        return sorted
    }
}

extension SnippetExpander {
    @discardableResult
    private func ensureSnippetsFileExists() -> Bool {
        guard !fileManager.fileExists(atPath: snippetsURL.path) else {
            log("Snippets file exists at \(snippetsURL.path)")
            return true
        }

        do {
            let directoryURL = snippetsURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let contents = Self.defaultSnippets
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "\n") + "\n"
            try contents.write(to: snippetsURL, atomically: true, encoding: .utf8)
            log("Created default snippets file at \(snippetsURL.path).")
            return true
        } catch {
            fputs("Failed to create default snippets file at \(snippetsURL.path): \(error)\n", stderr)
            logError("Failed to create default snippets file at \(snippetsURL.path): \(error)")
            return false
        }
    }
}

// ---- App bootstrap ----

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // hides Dock icon but allows menu bar extra

let delegate = AppDelegate()
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let expander = SnippetExpander()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("Application did finish launching")
        expander.start()
        configureStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        log("Application will terminate")
        expander.stop()
    }

    private func configureStatusItem() {
        log("Configuring status bar item")
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Expander")
            if let image {
                image.isTemplate = true // invert for dark/light
                button.image = image
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.title = "Expander"
            }
        }

        rebuildMenu()
        statusItem.menu = menu
    }

    @objc private func reloadSnippets() {
        _ = expander.reloadSnippets()
        rebuildMenu()
        log("Reload menu triggered from status item")
    }

    @objc private func editSnippets() {
        expander.openSnippetsInTextEdit()
        log("Edit snippets action triggered")
    }

    @objc private func quitApp() {
        log("Quit action triggered from status item")
        NSApp.terminate(nil)
    }

    private func rebuildMenu() {
        log("Rebuilding status item menu")
        menu.removeAllItems()

        let editItem = NSMenuItem(title: "Edit Snippets…", action: #selector(editSnippets), keyEquivalent: "e")
        editItem.target = self
        menu.addItem(editItem)

        let reloadItem = NSMenuItem(title: "Reload Snippets", action: #selector(reloadSnippets), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(NSMenuItem.separator())
        addSnippetItems()
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addSnippetItems() {
        let items = expander.allSnippets()
        guard !items.isEmpty else {
            let empty = NSMenuItem(title: "No snippets loaded", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            log("No snippets available to show in menu")
            return
        }

        for snippet in items {
            let item = NSMenuItem(title: "\(snippet.key) → \(snippet.value)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        log("Added \(items.count) snippet items to menu")
    }
}
