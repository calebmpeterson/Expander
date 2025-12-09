import Foundation

/// Lightweight logger for development diagnostics.
func log(_ message: String) {
    print("[Expander] \(message)")
}

/// Error-specific logger that routes to stderr.
func logError(_ message: String) {
    fputs("[Expander] \(message)\n", stderr)
}
