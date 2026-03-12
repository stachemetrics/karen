# Karen From Finance

> *Named after the legendary [Karen From Finance](https://www.karenfromfinance.com), Sydney's fiercest drag queen. She handles the books, darling — so you don't have to.*

WhatsApp expense tracker built with [OpenClaw](https://openclaw.ai). Snap a photo of a receipt, send it to Karen, and get a clean Excel report on demand.

[Prototype #3 of 42](https://mmetrics.ai) — mmetrics.ai

---

## The problem

Small businesses and sole traders doing services work have the same headache: receipts pile up in your camera roll, time gets logged on scraps of paper, and invoicing happens at 11pm the night before it's due. You don't need an app — you need someone who'll just handle it.

## Meet Karen

Karen From Finance turns WhatsApp into your expense tracker and invoicing assistant. Like her drag queen namesake, she's sharp, she's organised, and she doesn't suffer fools — but she'll always get your numbers right.

1. **Send a receipt photo** — Karen reads it, confirms the details, logs it
2. **Log your time** — "3 hours on Acme today" and she'll track it
3. **Ask for a report** — she sends a formatted Excel file with just your data
4. **Set a reminder** — "remind me every Friday at 5pm" and she will
5. **Invoice a client** — she'll show you what's unbilled, you confirm, she generates it

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

## Why "Karen From Finance"?

[Karen From Finance](https://www.karenfromfinance.com) is the stage name of Richard Sawyer, a Sydney drag queen who burst onto the scene on RuPaul's Drag Race Down Under. Sharp-tongued, immaculately presented, and named after everyone's favourite person in accounts payable — she's the perfect namesake for an AI that tracks your receipts and doesn't let you forget your expenses.

This project is a fan tribute. If you're in Sydney, go see her live.

---

## See also

- [`agents.md`](agents.md) — full implementation plan, skill design, data model
