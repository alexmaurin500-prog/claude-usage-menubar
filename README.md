# Claude Usage Widget

Track your Claude usage — 5-hour window, 7-day window, and extra credits — right in the macOS menu bar or the Windows/Linux system tray.

<p align="center">
  <img src="assets/screenshot.png" alt="Claude Usage Widget" width="400">
</p>

## Download

**macOS (recommended):** grab the latest `ClaudeUsage-x.y.z.dmg` from the
[**Releases**](https://github.com/alexmaurin500-prog/claude-usage-menubar/releases) page,
open it, and drag **Claude Usage** into Applications. Universal binary (Intel + Apple Silicon).

Other options (SwiftBar plugin, cross-platform tray) are described below.

## How it works

No Anthropic API key needed. The data script reads your browser session cookies for
`claude.ai` via [`browser-cookie3`](https://pypi.org/project/browser-cookie3/) and calls
the internal usage endpoint. Browsers auto-detected: **Safari**, **Chrome**, **Firefox**
(+ **Edge** on Windows).

> **Unofficial.** This is not a public Anthropic API and may change or break at any time.
> Not affiliated with, endorsed by, or sponsored by Anthropic.

## Prerequisites

- Python 3.9+ (with `browser-cookie3` and `requests` — `pip3 install -r requirements.txt`)
- Logged into [claude.ai](https://claude.ai) in a supported browser
- **macOS**: grant **Full Disk Access** to the app so it can read Safari cookies
  (*System Settings → Privacy & Security → Full Disk Access*)

## Options

### 1 — Native macOS app

Download the DMG from Releases (above), or build it yourself:

```bash
cd macos-app
./build.sh --dmg      # produces ClaudeUsage.app + ClaudeUsage-x.y.z.dmg
```

To launch at login: *System Settings → General → Login Items → +* and add **Claude Usage**.

### 2 — SwiftBar plugin (macOS)

1. Install [SwiftBar](https://github.com/swiftbar/SwiftBar).
2. Copy `claude-usage.5m.py` into your SwiftBar plugin folder.
3. `chmod +x claude-usage.5m.py`, then refresh SwiftBar.

### 3 — System tray (Windows / Linux / macOS)

```bash
python3 claude-tray.py
```

## Project layout

| Path | What |
|---|---|
| `claude-usage.5m.py` | Data script — SwiftBar plugin and the engine bundled inside the app |
| `claude-tray.py` | Cross-platform system-tray app (`pystray`) |
| `macos-app/ClaudeUsage.swift` | Native menu-bar app source |
| `macos-app/build.sh` | Builds the universal `.app` and a DMG |

## License

MIT — see [LICENSE](LICENSE).
