# Claude Usage Widget

Track your Claude usage (5h / 7d / extra credits) in the macOS menu bar or Windows/Linux system tray.

Three options depending on your setup:

| | macOS (native) | macOS (SwiftBar) | Windows / Linux |
|---|---|---|---|
| **File** | `ClaudeUsage/` | `claude-usage.5m.py` | `claude-tray.py` |
| **Look** | Native progress bars | Text in menu bar | Icon in system tray |
| **Requires** | Xcode CLI tools | [SwiftBar](https://github.com/swiftbar/SwiftBar) | Python + pystray |

## How it works

No Anthropic API key needed. The scripts read your browser session cookies for `claude.ai` via [`browser-cookie3`](https://pypi.org/project/browser-cookie3/), then call the internal usage endpoint.

Browsers auto-detected: **Safari**, **Chrome**, **Firefox** (+ **Edge** on Windows).

> **Unofficial.** This is not a public Anthropic API. It may change or break at any time. Not affiliated with Anthropic.

## Prerequisites

- Python 3.9+
- Logged into [claude.ai](https://claude.ai) in any supported browser
- macOS: **Full Disk Access** granted to SwiftBar / Terminal (*System Settings > Privacy & Security > Full Disk Access*)

## Install

```bash
pip3 install -r requirements.txt
```

### Option 1 — Native macOS app (recommended on Mac)

Compile the Swift app, then place it next to the Python script:

```bash
cd ClaudeUsage
swiftc -parse-as-library -o ClaudeUsage claude-usage-app.swift -framework Cocoa -framework QuartzCore
cp ../claude-usage.5m.py .
./ClaudeUsage
```

### Option 2 — SwiftBar plugin (macOS)

1. Install [SwiftBar](https://github.com/swiftbar/SwiftBar).
2. Copy `claude-usage.5m.py` to your SwiftBar plugin folder.
3. `chmod +x claude-usage.5m.py`
4. Refresh SwiftBar.

### Option 3 — System tray (macOS / Windows / Linux)

```bash
python3 claude-tray.py
```

## License

MIT — see [LICENSE](LICENSE).
