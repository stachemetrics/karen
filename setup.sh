#!/usr/bin/env bash
# setup.sh — provision Karen From Finance on a fresh machine
# Run once after cloning. Re-running is safe (idempotent).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Karen From Finance — setup"
echo ""

# ── 1. Prerequisites ──────────────────────────────────────────────────────────

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "ERROR: .env not found."
  echo "  cp .env.example .env  # then add your ANTHROPIC_API_KEY"
  exit 1
fi

ANTHROPIC_API_KEY=$(grep -E '^ANTHROPIC_API_KEY=' "$REPO_DIR/.env" | cut -d= -f2-)
if [ -z "$ANTHROPIC_API_KEY" ] || [ "$ANTHROPIC_API_KEY" = "YOUR_KEY_HERE" ]; then
  echo "ERROR: ANTHROPIC_API_KEY not set in .env"
  exit 1
fi

NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo 0)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "ERROR: Node.js >= 22 required (found: $(node --version 2>/dev/null || echo 'not installed'))"
  echo "  Install via nvm: nvm install 22 && nvm use 22"
  exit 1
fi

if ! command -v openclaw &>/dev/null; then
  echo "--> Installing openclaw..."
  npm install -g openclaw@latest
fi

echo "    Node:      $(node --version)"
echo "    openclaw:  $(openclaw --version 2>/dev/null || echo unknown)"
echo ""

# ── 2. Onboard (sets up ~/.openclaw config + workspace) ───────────────────────

echo "--> Running openclaw onboard..."
openclaw onboard \
  --non-interactive \
  --accept-risk \
  --mode local \
  --auth-choice anthropic-api-key \
  --anthropic-api-key "$ANTHROPIC_API_KEY" \
  --gateway-bind loopback \
  --gateway-auth token \
  --no-install-daemon \
  --skip-channels \
  2>&1 | grep -v "gateway closed" || true   # suppress expected health-check noise

# ── 3. WhatsApp channel config ────────────────────────────────────────────────

echo "--> Configuring WhatsApp channel..."
openclaw config set channels.whatsapp.allowFrom '["*"]' 2>&1 | grep -E "^(Updated|Error)" || true
openclaw config set channels.whatsapp.dmPolicy open    2>&1 | grep -E "^(Updated|Error)" || true
openclaw config set channels.whatsapp.ackReaction.emoji "👀" 2>&1 | grep -E "^(Updated|Error)" || true
openclaw config set channels.whatsapp.ackReaction.direct true 2>&1 | grep -E "^(Updated|Error)" || true

echo "--> Setting tools profile..."
openclaw config set tools.profile coding 2>&1 | grep -E "^(Updated|Error)" || true

# ── 4. Agent identity ─────────────────────────────────────────────────────────

echo "--> Setting agent identity..."
openclaw agents set-identity --agent main --name "Karen" --emoji "💰" 2>&1 | grep -E "^(Updated|Agent|Name|Emoji|Error)" || true

# ── 5. Workspace files ────────────────────────────────────────────────────────

echo "--> Installing workspace files..."
WORKSPACE="$HOME/.openclaw/workspace"

cp "$REPO_DIR/workspace/SOUL.md"     "$WORKSPACE/SOUL.md"
cp "$REPO_DIR/workspace/IDENTITY.md" "$WORKSPACE/IDENTITY.md"
cp "$REPO_DIR/workspace/USER.md"     "$WORKSPACE/USER.md"
rm -f "$WORKSPACE/BOOTSTRAP.md"   # remove the blank-agent intro prompt

# ── 6. Skill symlink ──────────────────────────────────────────────────────────

echo "--> Symlinking skill..."
mkdir -p "$HOME/.openclaw/skills"
ln -sf "$REPO_DIR/skills/karen-from-finance" "$HOME/.openclaw/skills/karen-from-finance"

# ── 7. Data directory ─────────────────────────────────────────────────────────

echo "--> Creating karen-data directory..."
mkdir -p "$WORKSPACE/karen-data"
if [ ! -f "$WORKSPACE/karen-data/expenses.json" ]; then
  cp "$REPO_DIR/sample-data/expenses.json" "$WORKSPACE/karen-data/expenses.json"
  echo "    Seeded with sample data"
fi
if [ ! -f "$WORKSPACE/karen-data/seen_users.json" ]; then
  echo '[]' > "$WORKSPACE/karen-data/seen_users.json"
fi

# ── 8. Gateway service ────────────────────────────────────────────────────────

echo "--> Installing gateway service..."
openclaw gateway install 2>&1 | grep -v "^$" | tail -5 || true

# Inject API key via systemd drop-in (survives openclaw upgrades)
SERVICE_DROPIN="$HOME/.config/systemd/user/openclaw-gateway.service.d"
mkdir -p "$SERVICE_DROPIN"
cat > "$SERVICE_DROPIN/anthropic.conf" <<EOF
[Service]
Environment=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
EOF

systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service 2>/dev/null || true
systemctl --user restart openclaw-gateway.service

# Wait for gateway to come up
echo -n "    Waiting for gateway"
for i in $(seq 1 10); do
  sleep 1
  if openclaw gateway status 2>/dev/null | grep -q "RPC probe: ok"; then
    echo " ready"
    break
  fi
  echo -n "."
  if [ "$i" -eq 10 ]; then echo " timed out (check: openclaw logs --follow)"; fi
done

# ── 9. Done ───────────────────────────────────────────────────────────────────

echo ""
echo "✅  Karen is set up."
echo ""
echo "Next: connect WhatsApp (do this once per machine)"
echo "  openclaw channels login --channel whatsapp"
echo "  # Scan the QR from the Karen phone (WhatsApp > Linked Devices)"
echo ""
echo "Then verify:"
echo "  openclaw channels status"
echo "  openclaw skills list | grep karen"
echo ""
echo "Test without WhatsApp:"
echo "  openclaw dashboard  # opens http://127.0.0.1:18789/"
