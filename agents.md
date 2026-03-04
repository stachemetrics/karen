# Karen From Finance — Implementation Plan

**Prototype #3 of 42 | MMetrics.ai**
**Date:** 2026-03-04

---

## Purpose

A CEO of a growing company asked: "Do you need a technical background to implement OpenClaw successfully?"

Karen From Finance answers that question with a working demo and a lessons learned blog-post. This project contains an OpenClaw skill that turns WhatsApp into an expense tracker: snap a receipt photo, send it to Karen, set a reminder, or get a clean Excel report when you need one.

**Shipped = video walkthrough + public git repo + demo WhatsApp account anyone can message + blog post on mmetrics.ai about the pattern**

---

## The Demo Story (30-second pitch)

> Every Saturday I buy lunch for a program and need reimbursement.
> I send Karen a photo of the receipt on WhatsApp.
> She reads it, confirms the details, and logs it.
> When I need a report, I ask her, and she sends me an Excel file.
> No app. No login. No training. Just WhatsApp.

**Why this lands for the audience:**
- WhatsApp is already on their phone
- "Send photo, get data" is immediately understandable
- The Excel output is the format their bookkeeper already expects
- The cron reminder shows proactive behaviour ("Karen reminded me on Saturday")

---

## Architecture

```
[WhatsApp photo of receipt] OR
[message like "hey Karen give me an expense report"] OR
[message like "remind me every Saturday at 2pm to submit my receipt"] OR
[OpenClaw cron fires a user-set or admin-set reminder]
        │
        ▼
┌──────────────────────────────────────┐
│  Home Mini PC / VPS                  │
│  (always-on, SSH from tablet)        │
│                                      │
│  OpenClaw Gateway                    │
│  ├─ WhatsApp (Baileys, dedicated #)  │
│  │                                   │
│  │  karen-from-finance SKILL.md      │
│  │    ├─ Receipt OCR (Claude vision) │
│  │    ├─ Data extraction → JSON      │
│  │    ├─ Per-user expense storage    │
│  │    ├─ Excel generation (openpyxl) │
│  │    └─ Reminder mgmt (cron add/rm) │
│  │                                   │
│  │  OpenClaw Cron Scheduler          │
│  │    ├─ Admin cron (hardcoded)      │
│  │    └─ Per-user crons (dynamic)    │
│  └─ dmPolicy: open (public demo)     │
│                                      │
│  Also available for:                 │
│  ├─ Other OpenClaw skills            │
│  └─ General dev via SSH from tablet  │
└──────────────────────────────────────┘
        │
        ▼
[WhatsApp reply: "Got it — $27.50 at Café Roma"] OR
[WhatsApp file: expenses_report.xlsx] OR
[WhatsApp message: "REMINDER: Don't forget to submit your lunch receipt!"] OR
[WhatsApp message: "Done! I'll remind you every Saturday at 2pm. Reply 'cancel reminder' to stop."]
```

**What OpenClaw gives us for free:**
- WhatsApp channel (Baileys — WhatsApp Web protocol, no API registration needed)
- Image/media pipeline (receives photos, passes to agent)
- Claude vision (agent can "see" receipt photos natively)
- Cron scheduler (Saturday reminders)
- File read/write tools (workspace storage)
- Bash tool (run Python scripts for Excel generation)

---

## Public Demo: Security & Disclaimers

Since Karen's WhatsApp number will be shared publicly (blog post, video CTA), anyone can message her. This needs guardrails.

### WhatsApp Config (open access with ack reaction)

```json
{
  "channels": {
    "whatsapp": {
      "dmPolicy": "open",
      "allowFrom": ["*"],
      "ackReaction": {
        "emoji": "👀",
        "direct": true
      }
    }
  }
}
```

### SKILL.md Demo Disclaimers (added to agent instructions)

**When a new user messages for the first time:**
1. Reply with a welcome message:
   > "Hi! I'm Karen From Finance 💰 — a demo expense tracker built with OpenClaw.
   >
   > ⚠️ **This is a public demo.** A few things to know:
   > - Don't send anything sensitive (personal IDs, bank details, etc.)
   > - Your receipts are stored locally and may be wiped periodically
   > - This demo is for illustration — not production use
   >
   > Send me a photo of a receipt and I'll log it for you. Ask for a report anytime. Built by Geoff at [mmetrics.ai](https://mmetrics.ai)"
2. After the disclaimer, proceed normally with receipt handling.

**On every interaction:**
- Karen scopes all data by the sender's phone number (see data model below)
- Karen never shares one user's data with another
- Karen refuses requests that reference other users' expenses

### Rate Limiting / Abuse Prevention
- OpenClaw's `mediaMaxMb: 50` cap prevents large file abuse
- Outbound media capped at 5MB (default)
- If a user sends >10 messages without a receipt photo, Karen gently redirects:
  > "I'm best at tracking receipts! Send me a photo of one and I'll log it 📸"
- Consider adding a daily cap per phone number (Phase 2 — manual review of usage first)

---

## Skill Design: `karen-from-finance/SKILL.md`

```
~/.openclaw/workspace/skills/karen-from-finance/
├── SKILL.md                    # Agent playbook (receipts, reports, reminders)
├── scripts/
│   └── generate_report.py      # Creates Excel from stored expenses
└── sample-data/
    └── expenses.json           # Example data for testing

~/.openclaw/workspace/karen-data/
└── expenses.json               # Live expense records (all users, scoped by requester)

# Reminders are stored in OpenClaw's cron registry, not in karen-data/.
# Karen identifies user reminders by name prefix: karen-reminder-<e164_phone>-
```

### SKILL.md Content (draft)

```yaml
---
name: karen-from-finance
description: >
  Expense tracking assistant. Use when the user sends a receipt photo,
  mentions expenses, asks for an expense report, wants to set or cancel
  a reminder, or says "Karen".
  Handles receipt scanning, expense logging, Excel report generation,
  and per-user recurring reminders.
metadata:
  openclaw:
    emoji: "💰"
    requires:
      bins: ["python3"]
---
```

**Instructions for the agent (body of SKILL.md):**

### When the user sends a photo:
1. Look at the image carefully. Extract: vendor name, date, items purchased, subtotal, GST/tax, total amount.
2. If you can't read something clearly, say what you can see and ask the user to confirm.
3. Confirm the extracted data back to the user in a short, friendly message:
   "Got it — $27.50 at Café Roma on Saturday 1 March. Logged as lunch reimbursement. 🧾"
4. Save the expense by appending to `~/.openclaw/workspace/karen-data/expenses.json`
5. Each expense record must include the `requester` field (sender's phone number from the message context) — see data model below.

### When the user asks for a report:
1. Run: `python3 {baseDir}/scripts/generate_report.py --requester <sender_phone>`
2. The script reads expenses.json, filters to only that requester's expenses, and produces an Excel file.
3. Send the file to the user with a summary: "Here's your report — 6 expenses totalling $167.50 from Feb 1 to Mar 1."
4. **Never include another user's expenses in a report.**

### When the user asks to edit or delete an expense:
1. Only show/modify expenses belonging to the requesting user's phone number.
2. Confirm the change before making it.
3. Update expenses.json accordingly.

### When the user asks to set a reminder:
1. Parse what they want: day(s) of week, time, timezone (default to Australia/Sydney if not given), and a brief reminder text.
2. Generate a unique cron name scoped to their phone number: `karen-reminder-<e164_phone>-<yyyymmddHHMM>` (e.g. `karen-reminder-61412345678-202603041400`). Strip the leading `+`.
3. Run via bash:
   ```
   openclaw cron add \
     --name "karen-reminder-<generated_name>" \
     --cron "<cron_expression>" \
     --tz "Australia/Sydney" \
     --session isolated \
     --message "<reminder text>" \
     --announce \
     --channel whatsapp \
     --to "<sender_phone>"
   ```
4. Confirm to the user: "Done! I'll remind you every Saturday at 2pm Sydney time. Reply 'list reminders' to see yours, or 'cancel reminder' to stop it. ✅"
5. **Limit:** Each user may have at most 3 active reminders. If they already have 3, tell them: "You've already got 3 reminders set. Reply 'list reminders' to see them, or 'cancel reminder' to remove one first."

### When the user asks to list their reminders:
1. Run via bash: `openclaw cron list --json`
2. Parse the output and filter to entries whose `--to` value matches the sender's phone number (match on the `name` field prefix `karen-reminder-<e164_phone>`).
3. Format the list for WhatsApp:
   > Your reminders:
   > 1. Every Saturday at 2pm — "Don't forget your lunch receipt!"
   > 2. Every Friday at 5pm — "Submit any outstanding expenses"
   > Reply 'cancel reminder 1' (or 'cancel reminder 2') to remove one.
4. If no reminders found, say: "You don't have any reminders set. Want me to set one? Just say when and what."

### When the user asks to cancel a reminder:
1. Run `openclaw cron list --json`, filter to the sender's reminders as above.
2. If they specified a number (e.g. "cancel reminder 1"), match it to the list. If they said "cancel reminder" without a number and they have exactly one, cancel it directly. If multiple, ask which one.
3. Confirm the name of the reminder being cancelled before removing it.
4. Run via bash: `openclaw cron remove --name "<name>"`
5. Confirm: "Done — that reminder is cancelled. ✅"

### Tone:
- Friendly, efficient, slightly cheeky. Karen gets things done.
- Keep messages short — this is WhatsApp, not email.
- Use emojis sparingly but naturally: 🧾 ✅ 📊

### GST handling:
- Try to read GST from the receipt if itemised separately.
- If not visible, calculate as 1/11th of total (standard Australian GST).
- Note the assumption in the confirmation message.

### Data storage:
- All data lives in `~/.openclaw/workspace/karen-data/`
- Never access files outside this directory.
- expenses.json is the single source of truth for expense records.
- All expense records are scoped by `requester` phone number.
- Reminders are managed by OpenClaw's cron system (not stored in expenses.json). Karen identifies a user's reminders by the `karen-reminder-<e164_phone>-` prefix on the cron name.

---

## Data Model (phone-number scoped)

Each expense record includes a `requester` field — the E.164 phone number of the sender. This is the authentication layer: Karen only shows/reports expenses belonging to the requesting phone number.

```json
{
  "id": 1,
  "requester": "+61412345678",
  "date": "2026-02-01",
  "vendor": "Café Roma",
  "description": "Lunch x2 — flat white, chicken sandwich, brownie",
  "amount_ex_gst": 25.00,
  "gst": 2.50,
  "total": 27.50,
  "category": "lunch_reimbursement",
  "timestamp": "2026-02-01T12:34:00+11:00"
}
```

**How `requester` gets populated:**
- OpenClaw normalises WhatsApp senders to E.164 format
- The agent reads the sender from the message context (envelope)
- The SKILL.md instructs the agent to always include the sender's phone number as `requester` when writing to expenses.json
- The `generate_report.py` script accepts `--requester` flag and filters accordingly

---

## Excel Report Format

Generated by `generate_report.py` using openpyxl:

| Date | Vendor | Description | Amount (ex GST) | GST | Total | Category |
|------|--------|-------------|-----------------|-----|-------|----------|
| 01/03/2026 | Café Roma | Lunch x2 | $25.00 | $2.50 | $27.50 | Lunch reimbursement |
| 08/03/2026 | Bay Bakery | Sandwiches, coffee | $22.73 | $2.27 | $25.00 | Lunch reimbursement |
| **TOTAL** | | | **$152.27** | **$15.23** | **$167.50** | |

Features:
- Column widths auto-fitted
- Header row with bold + light blue fill
- Currency formatting on amount columns
- Summary/total row at bottom
- Sheet named "Expense Report"
- Filename includes date range: `expenses_2026-02-01_to_2026-03-01.xlsx`
- **Only includes expenses for the requesting phone number**

---

## Sample Data (with requester phone numbers)

### Receipt Photos Needed (1-2 real + sample JSON)

Prep 1-2 real receipt photos from actual expenses — these are used live in the video demo. Photograph on a table with reasonable lighting. Different venues/amounts help show Karen handling variety.

### Pre-loaded Test Data (for Excel script testing)

```json
[
  {
    "id": 1,
    "requester": "+61400000001",
    "date": "2026-02-01",
    "vendor": "Café Roma",
    "description": "Lunch x2 — flat white, chicken sandwich, brownie",
    "amount_ex_gst": 25.00,
    "gst": 2.50,
    "total": 27.50,
    "category": "lunch_reimbursement",
    "timestamp": "2026-02-01T12:34:00+11:00"
  },
  {
    "id": 2,
    "requester": "+61400000001",
    "date": "2026-02-08",
    "vendor": "Bay Bakery",
    "description": "Sandwiches, 2x coffee",
    "amount_ex_gst": 16.36,
    "gst": 1.64,
    "total": 18.00,
    "category": "lunch_reimbursement",
    "timestamp": "2026-02-08T12:15:00+11:00"
  },
  {
    "id": 3,
    "requester": "+61400000001",
    "date": "2026-02-15",
    "vendor": "Pad Thai Palace",
    "description": "Pad thai, green curry, 2x water",
    "amount_ex_gst": 29.09,
    "gst": 2.91,
    "total": 32.00,
    "category": "lunch_reimbursement",
    "timestamp": "2026-02-15T12:45:00+11:00"
  },
  {
    "id": 4,
    "requester": "+61400000002",
    "date": "2026-02-22",
    "vendor": "The Corner Deli",
    "description": "Wraps x2, juice",
    "amount_ex_gst": 22.73,
    "gst": 2.27,
    "total": 25.00,
    "category": "lunch_reimbursement",
    "timestamp": "2026-02-22T13:00:00+11:00"
  },
  {
    "id": 5,
    "requester": "+61400000001",
    "date": "2026-03-01",
    "vendor": "Grounds of Alexandria",
    "description": "Burger, salad, long black",
    "amount_ex_gst": 31.82,
    "gst": 3.18,
    "total": 35.00,
    "category": "lunch_reimbursement",
    "timestamp": "2026-03-01T12:20:00+11:00"
  }
]
```

Note: `+61400000001` and `+61400000002` are two different demo users. When `+61400000001` asks for a report, they get 4 expenses totalling $112.50. When `+61400000002` asks, they get 1 expense for $25.00. This tests the phone-number scoping.

---

## Cron Configuration

Two types of crons run in this setup. OpenClaw's scheduler handles both identically — the difference is who creates them and how they're scoped.

### Type 1: Admin-configured (hardcoded, one-off setup via CLI)

Used for the primary demo user. Set once via SSH on the server.

**Saturday lunch reminder for Geoff (2pm Sydney time):**
```
openclaw cron add \
  --name "karen-reminder-614XXXXXXXX-admin" \
  --cron "0 14 * * 6" \
  --tz "Australia/Sydney" \
  --session isolated \
  --message "Remind the user to photograph and send their lunch receipt for today's TARA session. Be friendly and brief." \
  --announce \
  --channel whatsapp \
  --to "<geoff-whatsapp-number>"
```

### Type 2: User-configured (dynamic, set via WhatsApp message)

Any user can ask Karen to set a recurring reminder from within their WhatsApp conversation. Karen runs `openclaw cron add` on their behalf via the bash tool, scoping the cron to that user's phone number.

**Flow:**
1. User says: "Karen, remind me every Friday at 5pm to submit my receipts"
2. Karen parses day/time/message, generates a name like `karen-reminder-61412345678-202603041700`
3. Karen runs `openclaw cron add` with `--to <sender_phone>`
4. OpenClaw registers the job — it fires at the scheduled time and sends a message back to that user
5. User can list or cancel their reminders via WhatsApp at any time

**Scoping and security:**
- Cron names are prefixed with `karen-reminder-<e164_phone>-` — Karen uses this to filter `openclaw cron list` output to the requesting user's jobs only
- Karen never lists or cancels another user's reminders
- Public demo cap: max 3 active reminders per phone number
- To list all active crons (admin view): `openclaw cron list`
- To remove a user's reminder manually (admin): `openclaw cron remove --name <name>`

---

## Infrastructure Setup

### Option A: Home Mini PC (preferred — ordered, arriving in a few days)

**Hardware:** Refurbished HP ProDesk 400 G3 Mini or similar — i3/i5, 8GB RAM, SSD, ~AU$80-100 from eBay AU.

**Setup steps:**
1. Install Ubuntu Server 24.04 LTS (headless, no GUI)
2. Connect to home router via Ethernet
3. Set static IP or DHCP reservation on router
4. Enable SSH: `sudo systemctl enable ssh`
5. Install Node.js 20 LTS: `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs`
6. Install Python 3 + openpyxl: `sudo apt install -y python3 python3-pip && pip3 install openpyxl --break-system-packages`
7. Install OpenClaw: `npm install -g openclaw@latest && openclaw onboard --install-daemon`
8. Configure WhatsApp channel + scan QR code
9. Set up SSH key auth from tablet (disable password auth)
10. Optional: Tailscale for remote access when away from home network

**Why this works for the demo:**
- Always-on — Karen is listening 24/7 on WhatsApp
- Local filesystem — credentials, data, and API keys stay on hardware you control
- SSH from tablet — start Claude Code sessions overnight, check on things in the morning
- Low power — ~10-15W, runs silent, sits behind the router

### Option B: VPS (fallback / interim while mini PC ships)

**Provider:** Vultr or DigitalOcean, Sydney region, $5-7/month, 1GB RAM, 25GB SSD.

**Setup steps:**
1. Spin up Ubuntu 24.04 instance
2. SSH in, same Node.js + Python + OpenClaw install as above
3. Configure WhatsApp channel + scan QR code (via `openclaw channels login` — QR displays in terminal)
4. Set up firewall: `ufw allow ssh && ufw enable`
5. Run OpenClaw daemon: `openclaw daemon start`

**Trade-offs vs mini PC:**
- ✅ Live in 10 minutes, no hardware wait
- ✅ Accessible from anywhere without Tailscale
- ❌ Monthly cost (small but recurring)
- ❌ Credentials stored on someone else's infrastructure
- ❌ Can't easily use for non-OpenClaw workloads (1GB RAM is tight)

**Recommendation:** If the mini PC arrives before the weekend, skip the VPS. If you want Karen live tonight for testing, spin up a VPS as interim and migrate to the mini PC later. The OpenClaw workspace directory (`~/.openclaw/`) just needs to be copied across.

---

## Implementation Sequence (2-3 hours)

### Phase 0: Infrastructure + SIM (30 min, today)
1. Pick up prepaid SIM from JB Hi-Fi Miranda ✅
2. Install WhatsApp (or WhatsApp Business) on spare phone with new SIM
3. Set profile: name "Karen From Finance", fun profile pic
4. Either: spin up VPS **or** wait for mini PC to arrive
5. SSH in and install Node.js + Python + OpenClaw

### Phase 1: OpenClaw + WhatsApp Setup (30-40 min)
1. Configure WhatsApp channel in `~/.openclaw/openclaw.json` (open policy, dedicated number)
2. `openclaw channels login` — scan QR code from Karen's phone
3. Test: send a text message from your personal phone → verify agent replies
4. Test: send a photo → verify agent can see it
5. Verify the welcome/disclaimer message fires on first contact

### Phase 2: Skill + Storage (30-40 min)
1. Create skill directory structure under `~/.openclaw/workspace/skills/`
2. Write SKILL.md with receipt handling + report instructions + disclaimer
3. Create `karen-data/` directory with empty `expenses.json`
4. Test: send a receipt photo via WhatsApp → verify extraction + storage + requester field
5. Test: send from a second phone number → verify data stays scoped
6. Iterate on SKILL.md wording until extraction is reliable

### Phase 3: Excel Generation (20-30 min)
1. Write `generate_report.py` using openpyxl with `--requester` filter
2. Test with pre-loaded sample data (both phone numbers) → verify scoping
3. Test via WhatsApp: "Karen, give me my expense report" → receive .xlsx with only your expenses
4. Polish formatting (column widths, currency, totals)

### Phase 4: Cron + Video (30-40 min)
1. Set up admin Saturday reminder cron job (hardcoded via CLI for Geoff's number)
2. Test admin cron fires correctly
3. Test user-set reminder flow via WhatsApp: "Karen, remind me every Friday at 5pm to submit my receipts" → verify cron is created → verify it fires → test "cancel reminder"
4. Test multi-user reminder scoping: two phones set reminders, verify each only sees their own
5. Full end-to-end walkthrough for the video
6. Record video (screen + WhatsApp side by side)
7. Push skill to GitHub repo

---

## Video Script Outline (3-5 minutes)

**[0:00] Hook**
"A CEO asked me: do you need to be technical to use OpenClaw? Here's my answer."

**[0:15] The Problem**
"Every Saturday I buy lunch for a program. I need to track receipts and submit expenses. Usually this means a spreadsheet I update manually, or a pile of photos in my camera roll I deal with later."

**[0:30] Meet Karen**
"I built Karen From Finance — an OpenClaw skill that turns WhatsApp into an expense tracker."

**[0:45] Demo: Send Receipt**
[Screen: WhatsApp conversation. Send photo of receipt.]
[Karen replies with extracted data.]

**[1:15] Demo: Send More Receipts**
[Quick montage of 2-3 more receipts sent and confirmed.]

**[1:45] Demo: Get Report**
[Type: "Karen, give me my expense report"]
[Karen sends Excel file. Open it — show formatted table.]

**[2:15] Demo: Proactive Reminder**
[Show Saturday cron message from Karen.]

**[2:30] The Answer**
"Do you need to be technical? To set it up — yes, or you need someone like me. To use it? You just need WhatsApp."

**[3:00] The Pattern**
"This isn't just about expenses. Same pattern works for any repetitive paperwork: receipts, timesheets, compliance forms. Snap a photo, talk to the agent, get a report."

**[3:15] CTA**
"Try it yourself — Karen's number is in the description. Or if you've got a spreadsheet that drives you crazy, let's talk. geoff@mmetrics.ai"

---

## Blog Post Outline (for mmetrics.ai)

**Title:** "Prototype #3: Meet Karen, from Finance"

**Structure:**
- The question (from the CEO)
- What I built (Karen — WhatsApp expense tracker)
- What it looks like to use (Video)
- What it took to set up (honest: Node.js, keys, config, ~3 hours)
- The pattern: photo → AI extraction → structured storage → report
- Security considerations for a public demo (disclaimers, phone-scoped data)
- Where this goes next
- CTA: try Karen yourself (WhatsApp number) + bring your spreadsheet

---

## Phase 2 Roadmap (post-demo)

1. **Invoice generation** — fill .docx template from stored expenses
2. **Google Form submission** — automate reimbursement submission
3. **Xero/QuickBooks integration** — push expenses to accounting software
4. **Multi-user** — other team members use Karen via WhatsApp group
5. **Daily per-user rate limiting** — prevent API cost blowout from public demo
6. **Publish to ClawHub** — let others install and adapt the skill

---

## Pre-Build Checklist

### 1. ✅ Get a Dedicated SIM (today, JB Hi-Fi Miranda)
- $10 Boost/Vodafone prepaid starter pack
- Only needs to receive one WhatsApp verification SMS

### 2. Install WhatsApp on the Dedicated Number
- Install WhatsApp (or WhatsApp Business) on spare phone
- Register with the dedicated SIM
- Set profile name to "Karen From Finance" + profile pic
- Phone stays on Wi-Fi and power

### 3. Prep 1-2 Receipt Photos
- Photograph real expense receipts with decent lighting
- Save to main phone camera roll for demo

### 4. Home Server (ordered) or VPS (interim)
- Mini PC: HP ProDesk 400 G3 Mini from eBay AU (~$80-100), Ubuntu Server, Ethernet to router
- VPS fallback: Vultr/DigitalOcean Sydney, $5-7/month, 1GB RAM
- Either way: Node.js 20 + Python 3 + openpyxl + OpenClaw

### 5. Anthropic API Key
- OpenClaw needs an API key for Claude
- Check existing key has enough credits (~20-30 calls during build, ongoing cost for public demo)
- **Budget note:** Public demo means ongoing API costs. Monitor usage and set a spending cap.

### 6. Spare Phone for Karen
- Old phone or borrow one — just needs WhatsApp + Wi-Fi
- Stays plugged in at home next to the mini PC / router