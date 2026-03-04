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
- **An Anthropic API key** — stored in `.env` as `ANTHROPIC_API_KEY`

---

## Local setup

### 1. Install OpenClaw

```bash
npm install -g openclaw@latest
```

Verify:

```bash
openclaw --version
openclaw doctor
```

### 2. Onboard

Run the interactive setup wizard. It configures the Gateway, initialises the workspace, and registers your API key.

```bash
openclaw onboard --install-daemon
```

When prompted for the AI provider, select **Anthropic** and enter your key.

> ```bash
> export ANTHROPIC_API_KEY=$(grep ANTHROPIC_API_KEY .env | cut -d= -f2)
> ```

### 3. Install the skill

Symlink the skill from this repo into OpenClaw's skills directory:

```bash
mkdir -p ~/.openclaw/skills
ln -s $(pwd)/skills/karen-from-finance ~/.openclaw/skills/karen-from-finance
```

Verify OpenClaw picks it up:

```bash
openclaw skills list
```

`karen-from-finance` should appear in the list.

### 4. Create the data directory

```bash
mkdir -p ~/.openclaw/workspace/karen-data
cp sample-data/expenses.json ~/.openclaw/workspace/karen-data/expenses.json
```

### 5. Test the Excel generator

Verify the report script works before connecting WhatsApp:

```bash
source .venv/bin/activate

python3 skills/karen-from-finance/scripts/generate_report.py \
  --requester +61400000001 \
  --data ~/.openclaw/workspace/karen-data/expenses.json \
  --out /tmp/

# Expected output:
# Report saved: /tmp/expenses_2026-02-01_to_2026-03-01.xlsx
# 4 expenses | $112.50 total | 2026-02-01 to 2026-03-01
```

Open the `.xlsx` to confirm formatting (headers, currency, totals row).

Test the second demo user (should show 1 expense only):

```bash
python3 skills/karen-from-finance/scripts/generate_report.py \
  --requester +61400000002 \
  --data ~/.openclaw/workspace/karen-data/expenses.json \
  --out /tmp/
```

### 6. Test locally via the OpenClaw dashboard

Start the Gateway:

```bash
openclaw gateway
```

Open the dashboard:

```bash
openclaw dashboard
```

Send a message to Karen and verify she replies. Try: `"Give me my expense report"`.

### 7. Connect WhatsApp (full demo)

Karen needs a dedicated phone number (see `agents.md` — a prepaid SIM works):

```bash
openclaw channels login --channel whatsapp
```

Scan the QR code from Karen's dedicated phone. Once connected, send a message from your personal phone to Karen's number and verify the round-trip works.

---

## Project structure

```
skills/
└── karen-from-finance/
    ├── SKILL.md                   # Agent playbook (receipts, reports, reminders)
    └── scripts/
        └── generate_report.py    # Excel report generator

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
