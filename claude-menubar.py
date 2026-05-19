#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# App menubar autonome (sans SwiftBar) — affiche ton usage Claude (5h / 7j / extra)
# dans la barre de menus macOS. Se rafraîchit automatiquement toutes les 5 minutes.
#
# Prérequis :
#   - Python 3
#   - pip3 install browser-cookie3 requests rumps
#   - être connecté à claude.ai dans Safari, Chrome ou Firefox
#   - Accès complet au disque autorisé pour le terminal/app qui lance le script
#
# Lancer : python3 claude-menubar.py

import rumps
import threading
import json

try:
    import browser_cookie3
    import requests
except ImportError:
    rumps.App("⚠ Claude").run()
    raise SystemExit

BROWSERS = [
    ("Safari",  browser_cookie3.safari),
    ("Chrome",  browser_cookie3.chrome),
    ("Firefox", browser_cookie3.firefox),
]

def color_emoji(pct):
    if pct >= 80:
        return "🔴"
    if pct >= 50:
        return "🟠"
    return "🟢"

def format_reset(iso):
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(iso)
        return dt.astimezone().strftime("%H:%M")
    except Exception:
        return iso

def fetch_usage():
    try:
        session = None
        jar = {}
        for name, fn in BROWSERS:
            try:
                cookies = fn(domain_name=".claude.ai")
                jar = {}
                session = requests.Session()
                for c in cookies:
                    session.cookies.set(c.name, c.value, domain=c.domain)
                    jar[c.name] = c.value
                if jar.get("lastActiveOrg"):
                    break
                session = None
            except Exception:
                continue

        org_id = jar.get("lastActiveOrg")
        if not session or not org_id:
            return None, "Non connecté (Safari/Chrome/Firefox)"

        resp = session.get(
            f"https://claude.ai/api/organizations/{org_id}/usage",
            headers={
                "Accept": "*/*",
                "anthropic-client-platform": "web_claude_ai",
                "Referer": "https://claude.ai/settings/usage",
            },
            timeout=10,
        )
        if resp.status_code != 200:
            return None, f"Erreur {resp.status_code}"

        return resp.json(), None
    except Exception as e:
        return None, str(e)


class ClaudeUsageApp(rumps.App):
    def __init__(self):
        super().__init__("Claude …")
        self.menu = [
            rumps.MenuItem("Rafraîchir", callback=self.refresh),
            None,
            rumps.MenuItem("Ouvrir l'usage", callback=self.open_usage),
        ]
        self._info_5h = rumps.MenuItem("5h: …")
        self._info_7d = rumps.MenuItem("7j: …")
        self._info_extra = rumps.MenuItem("")
        self.menu.insert_before("Rafraîchir", self._info_5h)
        self.menu.insert_before("Rafraîchir", self._info_7d)
        self.menu.insert_before("Rafraîchir", self._info_extra)
        self.menu.insert_before("Rafraîchir", None)
        self.refresh(None)

    @rumps.timer(300)
    def auto_refresh(self, _):
        self._do_refresh()

    def refresh(self, _):
        threading.Thread(target=self._do_refresh, daemon=True).start()

    def _do_refresh(self):
        data, err = fetch_usage()
        if err or not data:
            self.title = "⚠ Claude"
            self._info_5h.title = err or "Erreur"
            return

        h5 = (data.get("five_hour") or {}).get("utilization", 0)
        d7 = (data.get("seven_day") or {}).get("utilization", 0)
        extra = data.get("extra_usage") or {}

        dominant = max(h5, d7)
        em = color_emoji(dominant)

        self.title = f"{em} Claude {dominant:.0f}%"

        reset5 = (data.get("five_hour") or {}).get("resets_at", "")
        reset7 = (data.get("seven_day") or {}).get("resets_at", "")
        self._info_5h.title = f"5h:  {h5:.0f}%  (reset {format_reset(reset5)})"
        self._info_7d.title = f"7j:  {d7:.0f}%  (reset {format_reset(reset7)})"

        if extra:
            used = extra.get("used_credits", 0)
            limit = extra.get("monthly_limit", 0)
            util = extra.get("utilization", 0)
            currency = extra.get("currency", "EUR")
            self._info_extra.title = f"Extra: {used:.0f}/{limit} {currency} ({util:.0f}%)"
        else:
            self._info_extra.title = ""

    def open_usage(self, _):
        import subprocess
        subprocess.run(["open", "https://claude.ai/settings/usage"])


if __name__ == "__main__":
    ClaudeUsageApp().run()
