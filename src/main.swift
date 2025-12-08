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

        reloadSnippets()
    }

    func start() {
        if !AccessibilityTextReplacer.hasAccessibilityPermission() {
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

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if delimiters.contains(event.keyCode) {
                self.replacer.expandSnippetsInFocusedElement(snippets: self.snippets)
            }
        }

        print("SnippetExpander running. Type :smile: then space/return/tab.")
    }

    func openSnippetsInTextEdit() {
        guard ensureSnippetsFileExists() else { return }

        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let configuration = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.open(
            [snippetsURL],
            withApplicationAt: textEditURL,
            configuration: configuration
        ) { _, error in
            if let error {
                fputs("Failed to open snippets in TextEdit: \(error)\n", stderr)
            }
        }
    }

    @discardableResult
    func reloadSnippets() -> Bool {
        guard ensureSnippetsFileExists() else {
            snippets = Self.defaultSnippets
            return false
        }

        do {
            let parsed = try parseKeyValueFile(at: snippetsURL)
            snippets = parsed.isEmpty ? Self.defaultSnippets : parsed
            print("Reloaded snippets from \(snippetsURL.path).")
            return true
        } catch {
            fputs("Failed to read snippets from \(snippetsURL.path): \(error)\n", stderr)
            snippets = Self.defaultSnippets
            return false
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
    }
}

extension SnippetExpander {
    @discardableResult
    private func ensureSnippetsFileExists() -> Bool {
        guard !fileManager.fileExists(atPath: snippetsURL.path) else { return true }

        do {
            let directoryURL = snippetsURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let contents = Self.defaultSnippets
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "\n") + "\n"
            try contents.write(to: snippetsURL, atomically: true, encoding: .utf8)
            print("Created default snippets file at \(snippetsURL.path).")
            return true
        } catch {
            fputs("Failed to create default snippets file at \(snippetsURL.path): \(error)\n", stderr)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        expander.start()
        configureStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        expander.stop()
    }

    private func configureStatusItem() {
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

        let menu = NSMenu()
        let editItem = NSMenuItem(title: "Edit Snippets…", action: #selector(editSnippets), keyEquivalent: "e")
        editItem.target = self
        menu.addItem(editItem)
        let reloadItem = NSMenuItem(title: "Reload Snippets", action: #selector(reloadSnippets), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func reloadSnippets() {
        expander.reloadSnippets()
    }

    @objc private func editSnippets() {
        expander.openSnippetsInTextEdit()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
