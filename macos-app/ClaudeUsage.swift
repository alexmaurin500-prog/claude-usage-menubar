import Cocoa

// ─────────────────────────────────────────────────────────────────────────────
// ClaudeUsage — native macOS menu bar app
// Shows Claude usage (5h / 7d / extra credits) with native progress bars.
//
// The Python data script (claude-usage.5m.py) is bundled inside the .app
// (Contents/Resources), so the binary always finds it regardless of where the
// app is launched from. The script reads browser cookies for claude.ai and
// calls the internal usage endpoint — no API key needed.
// ─────────────────────────────────────────────────────────────────────────────

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    private var headerLabel5h: NSMenuItem!
    private var progressItem5h: NSMenuItem!
    private var headerLabel7d: NSMenuItem!
    private var progressItem7d: NSMenuItem!
    private var headerLabelExtra: NSMenuItem!
    private var progressItemExtra: NSMenuItem!

    // ── Script & Python resolution ───────────────────────────────────────────
    private var scriptPath: String {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SCRIPT"] { return env }
        // Bundled inside the .app — reliable in every launch context.
        if let p = Bundle.main.path(forResource: "claude-usage.5m", ofType: "py") { return p }
        // Dev fallback: script sitting next to the source/binary.
        let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
        return dir + "/claude-usage.5m.py"
    }

    private var pythonPath: String {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_PYTHON"] { return env }
        for path in ["/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
                     "/opt/homebrew/bin/python3",
                     "/usr/local/bin/python3",
                     "/usr/bin/python3"] {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return "/usr/bin/python3"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, menu-bar only

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

        menu = NSMenu()
        buildMenu()
        statusItem.menu = menu

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // ── Menu construction ────────────────────────────────────────────────────
    private func buildMenu() {
        headerLabel5h = sectionHeader("5 HEURES"); menu.addItem(headerLabel5h)
        progressItem5h = NSMenuItem()
        progressItem5h.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItem5h)

        menu.addItem(NSMenuItem.separator())

        headerLabel7d = sectionHeader("7 JOURS"); menu.addItem(headerLabel7d)
        progressItem7d = NSMenuItem()
        progressItem7d.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItem7d)

        menu.addItem(NSMenuItem.separator())

        headerLabelExtra = sectionHeader("EXTRA"); menu.addItem(headerLabelExtra)
        progressItemExtra = NSMenuItem()
        progressItemExtra.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItemExtra)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Rafraîchir", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        menu.addItem(refreshItem)

        let openItem = NSMenuItem(title: "Ouvrir claude.ai/usage", action: #selector(openUsage), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "arrow.up.forward", accessibilityDescription: nil)
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func sectionHeader(_ text: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        item.isEnabled = false
        return item
    }

    private func makeProgressRow(value: Double, color: NSColor, label: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 30))

        let progress = NSProgressIndicator(frame: NSRect(x: 20, y: 8, width: 160, height: 14))
        progress.style = .bar
        progress.minValue = 0; progress.maxValue = 100
        progress.doubleValue = value
        progress.isIndeterminate = false
        progress.wantsLayer = true
        progress.layer?.cornerRadius = 3
        progress.contentFilters = [colorFilter(for: color)]
        container.addSubview(progress)

        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 190, y: 6, width: 100, height: 18)
        labelField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        labelField.textColor = color
        container.addSubview(labelField)
        return container
    }

    private func colorFilter(for color: NSColor) -> CIFilter {
        let filter = CIFilter(name: "CIFalseColor")!
        let ciColor = CIColor(color: color) ?? CIColor.green
        filter.setValue(ciColor, forKey: "inputColor0")
        filter.setValue(ciColor, forKey: "inputColor1")
        return filter
    }

    private func colorFor(_ pct: Double) -> NSColor {
        if pct >= 80 { return .systemRed }
        if pct >= 50 { return .systemOrange }
        return .systemGreen
    }

    @objc private func refreshClicked() { refresh() }

    @objc private func openUsage() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
    }

    // ── Data fetch ───────────────────────────────────────────────────────────
    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let parsed = self.parseOutput(self.runScript())
            DispatchQueue.main.async { self.updateUI(parsed) }
        }
    }

    private func runScript() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    struct UsageData {
        var h5 = 0.0, d7 = 0.0, extraUtil = 0.0
        var extraUsed = "", extraLimit = "", extraCurrency = "EUR"
        var reset5h = "", reset7d = ""
    }

    private func parseOutput(_ output: String) -> UsageData {
        var data = UsageData()
        for line in output.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("5 heures"), let p = extractPercentage(t) { data.h5 = p }
            else if t.hasPrefix("7 jours"), let p = extractPercentage(t) { data.d7 = p }
            else if t.hasPrefix("Extra"), !t.hasPrefix("Extra:"), let p = extractPercentage(t) { data.extraUtil = p }
            else if t.contains(" / "), t.contains("EUR") || t.contains("USD") {
                let parts = t.components(separatedBy: " ")
                if parts.count >= 4 { data.extraUsed = parts[0]; data.extraLimit = parts[2]; data.extraCurrency = parts[3] }
            } else if t.hasPrefix("Reset à") { data.reset5h = t.replacingOccurrences(of: "Reset à ", with: "") }
            else if t.hasPrefix("Reset le") { data.reset7d = t.replacingOccurrences(of: "Reset le ", with: "") }
        }
        return data
    }

    private func extractPercentage(_ line: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+\.?\d*)%"#),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return Double(line[r])
    }

    private func updateUI(_ data: UsageData) {
        let dominant = max(data.h5, data.d7)
        let color = colorFor(dominant)

        let resetStr = data.reset5h.isEmpty ? "" : " ⏱\(data.reset5h)"
        statusItem.button?.attributedTitle = NSAttributedString(
            string: "\(Int(dominant))%\(resetStr)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: color,
            ])
        statusItem.button?.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Claude Usage")
        statusItem.button?.imagePosition = .imageLeading

        progressItem5h.view = makeProgressRow(value: data.h5, color: colorFor(data.h5), label: "\(Int(data.h5))%")
        progressItem7d.view = makeProgressRow(value: data.d7, color: colorFor(data.d7), label: "\(Int(data.d7))%")

        var extraLabel = "\(Int(data.extraUtil))%"
        if !data.extraUsed.isEmpty {
            extraLabel += "  (\(data.extraUsed)/\(data.extraLimit) \(data.extraCurrency))"
        }
        progressItemExtra.view = makeProgressRow(value: data.extraUtil, color: colorFor(data.extraUtil), label: extraLabel)
    }

    // ── Entry point with optional headless self-test ─────────────────────────
    static func main() {
        if CommandLine.arguments.contains("--selftest")
            || ProcessInfo.processInfo.environment["CLAUDE_USAGE_SELFTEST"] == "1" {
            let app = AppDelegate()
            let d = app.parseOutput(app.runScript())
            print("SELFTEST 5h=\(d.h5)% 7d=\(d.d7)% extra=\(d.extraUtil)% (\(d.extraUsed)/\(d.extraLimit) \(d.extraCurrency))")
            exit((d.h5 + d.d7 + d.extraUtil) > 0 ? 0 : 1)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
