#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Cross-platform system tray app (macOS / Windows / Linux).
# Displays Claude usage (5h / 7d / extra credits) in the system tray.
# Auto-refreshes every 5 minutes.
#
# Prerequisites:
#   - Python 3.9+
#   - pip3 install browser-cookie3 requests pystray Pillow
#   - Logged into claude.ai in Safari, Chrome, Firefox, or Edge
#   - macOS: Full Disk Access for the terminal/app running this script
#
# Run: python3 claude-tray.py

import sys
import platform
import threading
import time

try:
    import browser_cookie3
    import requests
    import pystray
    from PIL import Image, ImageDraw, ImageFont
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("pip3 install browser-cookie3 requests pystray Pillow")
    sys.exit(1)

REFRESH_INTERVAL = 300

BROWSERS = [
    ("Safari", browser_cookie3.safari),
    ("Chrome", browser_cookie3.chrome),
    ("Firefox", browser_cookie3.firefox),
]

if platform.system() == "Windows":
    try:
        BROWSERS.append(("Edge", browser_cookie3.edge))
    except AttributeError:
        pass


def fetch_usage():
    for name, fn in BROWSERS:
        try:
            cookies = fn(domain_name=".claude.ai")
            session = requests.Session()
            jar = {}
            for c in cookies:
                session.cookies.set(c.name, c.value, domain=c.domain)
                jar[c.name] = c.value
            org_id = jar.get("lastActiveOrg")
            if not org_id:
                continue
            resp = session.get(
                f"https://claude.ai/api/organizations/{org_id}/usage",
                headers={
                    "Accept": "*/*",
                    "anthropic-client-platform": "web_claude_ai",
                    "Referer": "https://claude.ai/settings/usage",
                },
                timeout=10,
            )
            if resp.status_code == 200:
                return resp.json(), name, None
        except Exception:
            continue
    return None, None, "Not logged in (Safari/Chrome/Firefox/Edge)"


def color_for(pct):
    if pct >= 80:
        return (220, 50, 50)
    if pct >= 50:
        return (230, 160, 30)
    return (60, 180, 80)


def make_icon(text, color):
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([2, 2, 62, 62], radius=12, fill=color)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("arial.ttf", 28)
        except (OSError, IOError):
            font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (64 - tw) // 2
    y = (64 - th) // 2 - bbox[1]
    draw.text((x, y), text, fill=(255, 255, 255), font=font)
    return img


def make_error_icon():
    return make_icon("!", (220, 50, 50))


def bar_visual(pct, width=10):
    filled = round(pct / 100 * width)
    return "█" * filled + "░" * (width - filled)


def format_reset(iso):
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(iso)
        return dt.astimezone().strftime("%H:%M")
    except Exception:
        return iso


class ClaudeTray:
    def __init__(self):
        self.icon = pystray.Icon(
            "claude-usage",
            icon=make_icon("...", (100, 100, 100)),
            title="Claude Usage — loading...",
            menu=pystray.Menu(
                pystray.MenuItem("Loading...", None, enabled=False),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Refresh", self._on_refresh),
                pystray.MenuItem("Open usage page", self._on_open),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Quit", self._on_quit),
            ),
        )
        self._data = {}
        self._browser = None
        self._error = None

    def _on_refresh(self, icon, item):
        threading.Thread(target=self._refresh, daemon=True).start()

    def _on_open(self, icon, item):
        import webbrowser
        webbrowser.open("https://claude.ai/settings/usage")

    def _on_quit(self, icon, item):
        icon.stop()

    def _refresh(self):
        data, browser, err = fetch_usage()
        if err or not data:
            self._error = err
            self.icon.icon = make_error_icon()
            self.icon.title = f"Claude — {err}"
            self.icon.menu = pystray.Menu(
                pystray.MenuItem(err or "Error", None, enabled=False),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Refresh", self._on_refresh),
                pystray.MenuItem("Open usage page", self._on_open),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Quit", self._on_quit),
            )
            return

        self._data = data
        self._browser = browser

        h5 = (data.get("five_hour") or {}).get("utilization", 0)
        d7 = (data.get("seven_day") or {}).get("utilization", 0)
        extra = data.get("extra_usage") or {}
        dominant = max(h5, d7)
        color = color_for(dominant)

        self.icon.icon = make_icon(f"{dominant:.0f}", color)
        self.icon.title = f"Claude {dominant:.0f}% (via {browser})"

        reset5 = format_reset((data.get("five_hour") or {}).get("resets_at", ""))
        reset7 = format_reset((data.get("seven_day") or {}).get("resets_at", ""))

        items = [
            pystray.MenuItem(f"5h:  {bar_visual(h5)}  {h5:.0f}%  (reset {reset5})", None, enabled=False),
            pystray.MenuItem(f"7d:  {bar_visual(d7)}  {d7:.0f}%  (reset {reset7})", None, enabled=False),
        ]

        if extra:
            used = extra.get("used_credits", 0)
            limit = extra.get("monthly_limit", 0)
            util = extra.get("utilization", 0)
            currency = extra.get("currency", "EUR")
            items.append(pystray.MenuItem(
                f"Extra: {used:.0f}/{limit} {currency} ({util:.0f}%)", None, enabled=False
            ))

        items.append(pystray.MenuItem(f"Source: {browser}", None, enabled=False))
        items.extend([
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Refresh", self._on_refresh),
            pystray.MenuItem("Open usage page", self._on_open),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", self._on_quit),
        ])

        self.icon.menu = pystray.Menu(*items)

    def _auto_refresh_loop(self):
        while True:
            self._refresh()
            time.sleep(REFRESH_INTERVAL)

    def run(self):
        threading.Thread(target=self._auto_refresh_loop, daemon=True).start()
        self.icon.run()


if __name__ == "__main__":
    ClaudeTray().run()
