# Karen From Finance

WhatsApp expense tracker built with [OpenClaw](https://openclaw.ai). Snap a photo of a receipt, send it to Karen, and get a clean Excel report on demand to help with invoicing.

[Prototype #3 of 42](https://mmetrics.ai) — mmetrics.ai

---
## What it does
SME's providing services have trouble logging time and materials for effective invoicing. 
Karen from finance simplifies this process into a WhatsApp conversation.

---

## How it works

1. Send Karen a photo of a receipt on WhatsApp
2. Karen reads it, confirms the details, and logs it
3. Ask for a report — she sends an Excel file
4. Ask her to remind you — she sets a recurring WhatsApp reminder that you can cancel at any time.

No app. No login. No training. Just WhatsApp.

---

## Prerequisites

- **Node.js ≥22** — required by OpenClaw
- **Python 3.12** — pinned in `.python-version`
- **openpyxl** — already installed in `.venv`
- **An Anthropic API key**

---

## Setup

```bash
cp .env.example .env
# edit .env and add your ANTHROPIC_API_KEY

./setup.sh
```

`setup.sh` is idempotent — safe to re-run. It handles:
- `openclaw onboard` (non-interactive, local mode)
- WhatsApp channel config (open policy, 👀 ack reaction)
- Agent identity (Karen 💰)
- Workspace files (SOUL.md, IDENTITY.md, USER.md)
- Skill symlink (`~/.openclaw/skills/karen-from-finance`)
- Data directory (`~/.openclaw/workspace/karen-data/`)
- Gateway systemd service + API key injection

### Connect WhatsApp (once per machine)

Karen needs a dedicated phone number (prepaid SIM works):

```bash
openclaw channels login --channel whatsapp
```

Scan the QR from Karen's dedicated phone (WhatsApp → Settings → Linked Devices → Link a Device).

Verify the connection:
```bash
openclaw channels status
```

### Test without WhatsApp

```bash
openclaw dashboard   # opens http://127.0.0.1:18789/
```

Send `"hello"` — Karen should reply with her first-contact disclaimer.
Send `"give me my expense report"` — she should run the Python script and return an Excel file.

### Test the Excel generator directly

```bash
source .venv/bin/activate

python3 skills/karen-from-finance/scripts/generate_report.py \
  --requester +61400000001 \
  --data ~/.openclaw/workspace/karen-data/expenses.json \
  --out /tmp/
# Expected: 4 expenses, $112.50 total

python3 skills/karen-from-finance/scripts/generate_report.py \
  --requester +61400000002 \
  --data ~/.openclaw/workspace/karen-data/expenses.json \
  --out /tmp/
# Expected: 1 expense, $25.00 total
```

---

## Project structure

```
setup.sh                           # One-command setup (run this first)

skills/
└── karen-from-finance/
    ├── SKILL.md                   # Agent playbook (receipts, reports, reminders)
    └── scripts/
        └── generate_report.py    # Excel report generator

workspace/
    ├── SOUL.md                    # Karen's personality (copied to ~/.openclaw/workspace/)
    ├── IDENTITY.md                # Karen's identity
    └── USER.md                    # User context template

sample-data/
└── expenses.json                 # Pre-loaded test data (two demo users)
```

Live data is stored outside this repo at `~/.openclaw/workspace/karen-data/`.

---

## Admin cron reminder

Once WhatsApp is connected, set up the recurring Saturday reminder via CLI:

```bash
openclaw cron add \
  --name "karen-reminder-614XXXXXXXX-admin" \
  --cron "0 14 * * 6" \
  --tz "Australia/Sydney" \
  --session isolated \
  --message "Remind the user to photograph and send their lunch receipt for today's TARA session. Be friendly and brief." \
  --announce \
  --channel whatsapp \
  --to "+614XXXXXXXX"
```

Users can also set their own reminders by messaging Karen directly — see `agents.md` for the full design.

---

## See also

- [`agents.md`](agents.md) — full implementation plan, skill design, data model
