#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SwiftBar plugin — affiche ton usage Claude (5h / 7j / extra) dans la barre de menus macOS.
# Place ce fichier dans ton dossier de plugins SwiftBar (le suffixe .5m.py
# indique un rafraîchissement toutes les 5 minutes).
#
# Prérequis :
#   - Python 3
#   - pip3 install browser-cookie3 requests
#   - être connecté à claude.ai dans Safari
#   - Accès complet au disque autorisé pour SwiftBar (Réglages → Confidentialité)

import sys
import json

try:
    import browser_cookie3
    import requests
except ImportError:
    print("⚠ Claude | color=red")
    print("---")
    print("pip3 install browser-cookie3 requests | bash=pip3 param1=install param2=browser-cookie3 param3=requests terminal=true")
    sys.exit(0)

def bar_visual(pct, width=10):
    filled = round(pct / 100 * width)
    return "█" * filled + "░" * (width - filled)

def color_for(pct):
    if pct >= 80:
        return "red"
    if pct >= 50:
        return "orange"
    return "green"

def format_reset(iso):
    try:
        from datetime import datetime
        dt = datetime.fromisoformat(iso)
        return dt.astimezone().strftime("%H:%M")
    except Exception:
        return iso

try:
    cookies = browser_cookie3.safari(domain_name=".claude.ai")
    session = requests.Session()
    jar = {}
    for c in cookies:
        session.cookies.set(c.name, c.value, domain=c.domain)
        jar[c.name] = c.value

    org_id = jar.get("lastActiveOrg")
    if not org_id:
        print("⚠ Claude | color=red")
        print("---")
        print("Connectez-vous à claude.ai dans Safari")
        sys.exit(0)

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
        print(f"⚠ Claude {resp.status_code} | color=red")
        sys.exit(0)

    d = resp.json()
    h5 = (d.get("five_hour") or {}).get("utilization", 0)
    d7 = (d.get("seven_day") or {}).get("utilization", 0)
    extra = d.get("extra_usage") or {}

    dominant = max(h5, d7)
    color = color_for(dominant)

    print(f"Claude {h5}% | color={color}")
    print("---")
    print(f"5 heures  {bar_visual(h5)} {h5}% | color={color_for(h5)}")
    reset5 = (d.get("five_hour") or {}).get("resets_at")
    if reset5:
        print(f"  Reset à {format_reset(reset5)}")
    print(f"7 jours   {bar_visual(d7)} {d7}% | color={color_for(d7)}")
    reset7 = (d.get("seven_day") or {}).get("resets_at")
    if reset7:
        print(f"  Reset le {format_reset(reset7)}")

    if extra:
        used = extra.get("used_credits", 0)
        limit = extra.get("monthly_limit", 0)
        util = extra.get("utilization", 0)
        currency = extra.get("currency", "EUR")
        print("---")
        print(f"Extra  {bar_visual(util)} {util:.0f}%")
        print(f"  {used:.0f} / {limit} {currency}")

    print("---")
    print("Ouvrir l'usage | href=https://claude.ai/settings/usage")

except browser_cookie3.BrowserCookieError as e:
    print("⚠ Claude | color=red")
    print("---")
    print("Accès cookies Safari refusé")
    print("Réglages Système → Confidentialité → Accès complet au disque → SwiftBar")
except Exception as e:
    print("⚠ Claude | color=red")
    print("---")
    print(f"Erreur: {e}")
