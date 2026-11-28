#!/usr/bin/env python3
"""Email the moderators when new members are waiting for approval.

Run hourly by .github/workflows/alerts.yml. It reads the public member list
from Supabase (names and status only; email addresses are never public),
compares it with scripts/alert_state.json, and sends one short email listing
anyone new. It never emails about the same person twice.

Repository secrets (Settings > Secrets and variables > Actions):
  ALERT_SMTP_USER      the Gmail address that sends the sign-in codes
  ALERT_SMTP_PASSWORD  a Google app password for that account
  ALERT_TO             who gets the alert; several addresses separated by commas
Without them the script only prints what it would send.
"""
import json
import os
import smtplib
import ssl
import sys
import urllib.request
from email.message import EmailMessage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "docs", "data", "config.json")
STATE = os.path.join(ROOT, "scripts", "alert_state.json")
SITE = "https://wtunsworth-a11y.github.io/MCA_BioD/"


def pending_members(cfg):
    url = cfg["supabaseUrl"].rstrip("/") + "/rest/v1/profiles?select=id,display_name,affiliation,expertise,created_at&status=eq.pending&order=created_at"
    req = urllib.request.Request(url, headers={"apikey": cfg["supabaseKey"], "User-Agent": "camtrap-alerts"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def main():
    cfg = json.load(open(CONFIG))
    if not cfg.get("supabaseUrl"):
        print("No Supabase project configured; nothing to check.")
        return
    waiting = pending_members(cfg)
    try:
        told = set(json.load(open(STATE)).get("notified", []))
    except FileNotFoundError:
        told = set()
    new = [p for p in waiting if p["id"] not in told]
    print(f"{len(waiting)} waiting for approval, {len(new)} new since the last alert")

    # Remember only people still waiting, so the file stays small.
    still = sorted({p["id"] for p in waiting} & (told | {p["id"] for p in new}))
    if not new:
        if sorted(told) != still:
            json.dump({"notified": still}, open(STATE, "w"), indent=1)
        return

    lines = []
    for p in new:
        extra = ", ".join(x for x in [p.get("affiliation") or "", ", ".join(p.get("expertise") or [])] if x)
        lines.append(f"- {p['display_name']}" + (f" ({extra})" if extra else "") + f", joined {p['created_at'][:10]}")
    n = len(new)
    body = (f"{n} new member{'s are' if n > 1 else ' is'} waiting for approval on Melanesian Camera Trap ID:\n\n"
            + "\n".join(lines)
            + f"\n\nIn total {len(waiting)} {'people are' if len(waiting) != 1 else 'person is'} waiting.\n"
            f"Approve or block them on the Moderate page (sign in first): {SITE}#moderate\n\n"
            "Their identifications are already saved and will count once you approve them.\n"
            "You get this email at most once an hour, and only when someone new is waiting.\n")

    user, password, to = (os.environ.get(k, "").strip() for k in ("ALERT_SMTP_USER", "ALERT_SMTP_PASSWORD", "ALERT_TO"))
    if not (user and password and to):
        print("Alert secrets are not set, so no email was sent. It would have said:\n\n" + body)
        return
    msg = EmailMessage()
    msg["Subject"] = f"{n} new member{'s' if n > 1 else ''} waiting for approval"
    msg["From"] = f"Melanesian Camera Trap ID <{user}>"
    msg["To"] = to
    msg.set_content(body)
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=ssl.create_default_context()) as s:
        s.login(user, password.replace(" ", ""))
        s.send_message(msg)
    print(f"Alert sent to {len([a for a in to.split(',') if a.strip()])} address(es).")
    json.dump({"notified": still}, open(STATE, "w"), indent=1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:   # an alert problem should be visible but never break the site
        print(f"Alert check failed: {e}", file=sys.stderr)
        sys.exit(1)
