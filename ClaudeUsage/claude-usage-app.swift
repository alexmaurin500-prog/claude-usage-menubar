import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?

    // Menu items
    private var headerLabel5h: NSMenuItem!
    private var progressItem5h: NSMenuItem!
    private var headerLabel7d: NSMenuItem!
    private var progressItem7d: NSMenuItem!
    private var headerLabelExtra: NSMenuItem!
    private var progressItemExtra: NSMenuItem!

    // Script is expected next to the binary, or override via env CLAUDE_USAGE_SCRIPT / CLAUDE_USAGE_PYTHON
    private var scriptPath: String {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SCRIPT"] { return env }
        let dir = Bundle.main.executableURL?.deletingLastPathComponent().path ?? "."
        return dir + "/claude-usage.5m.py"
    }
    private var pythonPath: String {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_PYTHON"] { return env }
        // Try common Python paths
        for path in ["/usr/local/bin/python3", "/opt/homebrew/bin/python3",
                     "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
                     "/usr/bin/python3"] {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return "/usr/bin/env python3"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    private func buildMenu() {
        headerLabel5h = NSMenuItem()
        headerLabel5h.attributedTitle = sectionTitle("5 HEURES")
        headerLabel5h.isEnabled = false
        menu.addItem(headerLabel5h)

        progressItem5h = NSMenuItem()
        progressItem5h.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItem5h)

        menu.addItem(NSMenuItem.separator())

        headerLabel7d = NSMenuItem()
        headerLabel7d.attributedTitle = sectionTitle("7 JOURS")
        headerLabel7d.isEnabled = false
        menu.addItem(headerLabel7d)

        progressItem7d = NSMenuItem()
        progressItem7d.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItem7d)

        menu.addItem(NSMenuItem.separator())

        headerLabelExtra = NSMenuItem()
        headerLabelExtra.attributedTitle = sectionTitle("EXTRA")
        headerLabelExtra.isEnabled = false
        menu.addItem(headerLabelExtra)

        progressItemExtra = NSMenuItem()
        progressItemExtra.view = makeProgressRow(value: 0, color: .systemGreen, label: "0%")
        menu.addItem(progressItemExtra)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Rafraîchir", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Rafraîchir")
        menu.addItem(refreshItem)

        let openItem = NSMenuItem(title: "Ouvrir claude.ai/usage", action: #selector(openUsage), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "arrow.up.forward", accessibilityDescription: "Ouvrir")
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func sectionTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    private func makeProgressRow(value: Double, color: NSColor, label: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 30))

        let progress = NSProgressIndicator(frame: NSRect(x: 20, y: 8, width: 160, height: 14))
        progress.style = .bar
        progress.minValue = 0
        progress.maxValue = 100
        progress.doubleValue = value
        progress.isIndeterminate = false
        progress.wantsLayer = true
        progress.layer?.cornerRadius = 3
        progress.contentFilters = [colorFilter(for: color)]
        container.addSubview(progress)

        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 190, y: 6, width: 80, height: 18)
        labelField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        labelField.textColor = color
        container.addSubview(labelField)

        container.identifier = NSUserInterfaceItemIdentifier("progressRow")
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

    @objc private func refreshClicked() {
        refresh()
    }

    @objc private func openUsage() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let output = self.runScript()
            let parsed = self.parseOutput(output)
            DispatchQueue.main.async {
                self.updateUI(parsed)
            }
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
        var h5: Double = 0
        var d7: Double = 0
        var extraUtil: Double = 0
        var extraUsed: String = ""
        var extraLimit: String = ""
        var extraCurrency: String = "EUR"
        var reset5h: String = ""
        var reset7d: String = ""
    }

    private func parseOutput(_ output: String) -> UsageData {
        var data = UsageData()
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // "Claude 58.0% | color=orange"
            if trimmed.hasPrefix("Claude ") && trimmed.contains("| color=") {
                // Main percentage is 5h
            }
            // "5 heures  ██████░░░░ 58.0% | color=orange"
            if trimmed.hasPrefix("5 heures") {
                if let pct = extractPercentage(from: trimmed) {
                    data.h5 = pct
                }
            }
            // "7 jours   ██░░░░░░░░ 16.0% | color=green"
            if trimmed.hasPrefix("7 jours") {
                if let pct = extractPercentage(from: trimmed) {
                    data.d7 = pct
                }
            }
            // "Extra  ██░░░░░░░░ 24%"
            if trimmed.hasPrefix("Extra") && !trimmed.hasPrefix("Extra:") {
                if let pct = extractPercentage(from: trimmed) {
                    data.extraUtil = pct
                }
            }
            // "  416 / 1700 EUR"
            if trimmed.contains(" / ") && (trimmed.contains("EUR") || trimmed.contains("USD")) {
                let parts = trimmed.components(separatedBy: " ")
                if parts.count >= 4 {
                    data.extraUsed = parts[0]
                    data.extraLimit = parts[2]
                    data.extraCurrency = parts[3]
                }
            }
            // "  Reset à 01:20"
            if trimmed.hasPrefix("Reset à") {
                data.reset5h = trimmed.replacingOccurrences(of: "Reset à ", with: "")
            }
            // "  Reset le 00:00"
            if trimmed.hasPrefix("Reset le") {
                data.reset7d = trimmed.replacingOccurrences(of: "Reset le ", with: "")
            }
        }
        return data
    }

    private func extractPercentage(from line: String) -> Double? {
        // Match patterns like "58.0%" or "24%"
        let pattern = #"(\d+\.?\d*)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Double(line[range])
    }

    private func updateUI(_ data: UsageData) {
        let dominant = max(data.h5, data.d7)
        let color = colorFor(dominant)

        // Status bar title
        let resetStr = data.reset5h.isEmpty ? "" : " ⏱\(data.reset5h)"
        let title = "\(Int(dominant))%\(resetStr)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
        ]
        statusItem.button?.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        statusItem.button?.image = NSImage(systemSymbolName: "clock.arrow.circlepath",
                                           accessibilityDescription: "Claude Usage")
        statusItem.button?.imagePosition = .imageLeading

        // 5h row
        let color5h = colorFor(data.h5)
        progressItem5h.view = makeProgressRow(
            value: data.h5, color: color5h, label: "\(Int(data.h5))%"
        )

        // 7d row
        let color7d = colorFor(data.d7)
        progressItem7d.view = makeProgressRow(
            value: data.d7, color: color7d, label: "\(Int(data.d7))%"
        )

        // Extra row
        let colorExtra = colorFor(data.extraUtil)
        var extraLabel = "\(Int(data.extraUtil))%"
        if !data.extraUsed.isEmpty {
            extraLabel += "  (\(data.extraUsed)/\(data.extraLimit) \(data.extraCurrency))"
        }
        progressItemExtra.view = makeProgressRow(
            value: data.extraUtil, color: colorExtra, label: extraLabel
        )
    }
}
