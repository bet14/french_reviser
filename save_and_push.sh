#!/usr/bin/env bash
# save_and_push.sh — Copy a session HTML into this repo, update index.html, commit & push
#
# Usage:
#   ./save_and_push.sh <source_html_path> <title> <lang> [source_text]
#
#   <source_html_path>  : absolute or relative path to the generated HTML file
#   <title>             : human-readable title for index (e.g. "Vies minuscules — Dufourneau")
#   <lang>              : "fr" or "zh"
#   [source_text]       : optional — book/article source label (e.g. "Vies minuscules, Pierre Michon")
#
# Example:
#   ./save_and_push.sh ~/Desktop/session_foo.html "Achille — professeur de latin" fr "Vies minuscules"

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX="$REPO_DIR/index.html"
BRANCH="french_claude"

# ── Args ─────────────────────────────────────────────────────────────────────
if [ $# -lt 3 ]; then
  echo "Usage: $0 <html_file> <title> <lang> [source]"
  exit 1
fi

SRC_PATH="$1"
TITLE="$2"
LANG="$3"
SOURCE="${4:-}"
DATE=$(date +%Y-%m-%d)

if [ ! -f "$SRC_PATH" ]; then
  echo "Error: file not found: $SRC_PATH"
  exit 1
fi

FILENAME="$(basename "$SRC_PATH")"
DEST="$REPO_DIR/$FILENAME"

# ── Copy file ─────────────────────────────────────────────────────────────────
cp "$SRC_PATH" "$DEST"
echo "✓ Copied → $DEST"

# ── Update index.html SESSIONS array ─────────────────────────────────────────
# Build new entry JSON line
ESCAPED_TITLE="${TITLE//\"/\\\"}"
ESCAPED_SOURCE="${SOURCE//\"/\\\"}"
NEW_ENTRY="  {\"file\":\"$FILENAME\",\"title\":\"$ESCAPED_TITLE\",\"lang\":\"$LANG\",\"date\":\"$DATE\",\"source\":\"$ESCAPED_SOURCE\"},"

# Insert after the "const SESSIONS = [" marker line
MARKER="const SESSIONS = \["

if grep -q "$NEW_ENTRY" "$INDEX"; then
  echo "⚠ Entry already exists in index, skipping duplicate."
else
  # Use Python for safe in-place replacement (handles Windows line endings too)
  python3 - <<PYEOF
import re, sys

with open("$INDEX", "r", encoding="utf-8") as f:
    content = f.read()

new_entry = '  {"file":"$FILENAME","title":"$ESCAPED_TITLE","lang":"$LANG","date":"$DATE","source":"$ESCAPED_SOURCE"},\n'
marker = 'const SESSIONS = [\n'

if marker not in content:
    print("ERROR: Could not find SESSIONS marker in index.html", file=sys.stderr)
    sys.exit(1)

content = content.replace(marker, marker + new_entry, 1)

with open("$INDEX", "w", encoding="utf-8") as f:
    f.write(content)

print("✓ index.html updated")
PYEOF
fi

# ── Git add / commit / push ───────────────────────────────────────────────────
cd "$REPO_DIR"

git checkout "$BRANCH" 2>/dev/null || true

git add "$FILENAME" index.html

COMMIT_MSG="session: $TITLE ($DATE)"
git commit -m "$COMMIT_MSG"

git push origin "$BRANCH"

echo ""
echo "✅ Done! Pushed to origin/$BRANCH"
echo "   File : $FILENAME"
echo "   Title: $TITLE"
echo "   Date : $DATE"
