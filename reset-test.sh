#!/usr/bin/env bash
# reset-test.sh — wipe conversation state for a fresh test run
# Usage: ./reset-test.sh [--keep-expenses]
set -euo pipefail

KAREN_DATA="$HOME/.openclaw/workspace/karen-data"
SESSIONS="$HOME/.openclaw/agents/main/sessions"

KEEP_EXPENSES=false
for arg in "$@"; do
  [[ "$arg" == "--keep-expenses" ]] && KEEP_EXPENSES=true
done

echo "==> Resetting Karen test state..."

# 1. Clear session history — sessions.json index + all .jsonl transcript files
echo '{}' > "$SESSIONS/sessions.json"
# Remove transcript files (the actual conversation memory the agent uses)
find "$SESSIONS" -name "*.jsonl" -not -name "*.reset.*" -delete 2>/dev/null || true
echo "    Cleared session history + transcripts"

# 2. Clear seen_users (so disclaimer fires again)
echo '[]' > "$KAREN_DATA/seen_users.json"
echo "    Cleared seen_users.json"

# 3. Reset expenses (unless --keep-expenses)
if [ "$KEEP_EXPENSES" = false ]; then
  echo '[]' > "$KAREN_DATA/expenses.json"
  echo "    Cleared expenses.json"
else
  echo "    Kept expenses.json (--keep-expenses)"
fi

# 4. Remove last report pointer
rm -f "$KAREN_DATA/.last_report"
echo "    Removed .last_report"

# 5. Restart gateway so agent starts fresh
systemctl --user restart openclaw-gateway.service
sleep 4

echo ""
echo "Done. Send Karen a message — she'll give the first-contact disclaimer."
