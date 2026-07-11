#!/usr/bin/env bash
# Pull Homelab debug log from:
#  1) My Mac (Designed for iPad) host mirror / Containers
#  2) iOS Simulator containers
#  3) project tmp if app wrote there
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/tmp"
OUT_FILE="$OUT_DIR/homelab-debug.log"
LOG_NAME="homelab-debug.log"
mkdir -p "$OUT_DIR"

candidates=()
# Designed for iPad host mirrors (Logger hostMirror)
candidates+=("$HOME/Library/Logs/Homelab/$LOG_NAME")
candidates+=("$ROOT/tmp/$LOG_NAME")
# Bundle container if present
candidates+=("$HOME/Library/Containers/com.unitsung.myhomelab/Data/Documents/$LOG_NAME")
candidates+=("$HOME/Library/Containers/com.unitsung.myhomelab/Data/Library/Application Support/Homelab/$LOG_NAME")

while IFS= read -r f; do
  [[ -n "$f" ]] && candidates+=("$f")
done < <(find "$HOME/Library/Containers" -name "$LOG_NAME" -type f 2>/dev/null | head -n 30)

while IFS= read -r f; do
  [[ -n "$f" ]] && candidates+=("$f")
done < <(find "$HOME/Library/Developer/CoreSimulator/Devices" -name "$LOG_NAME" -type f 2>/dev/null | head -n 30)

newest=""
newest_mtime=0
for f in "${candidates[@]}"; do
  [[ -f "$f" ]] || continue
  mt=$(stat -f '%m' "$f" 2>/dev/null || echo 0)
  if (( mt > newest_mtime )); then
    newest_mtime=$mt
    newest=$f
  fi
done

if [[ -z "$newest" ]]; then
  echo "No $LOG_NAME found."
  echo "Xcode destination: My Mac (Designed for iPad) → Cmd+R with latest code,"
  echo "open OpenList text file once, then re-run this script."
  exit 1
fi

cp -f "$newest" "$OUT_FILE"
echo "Pulled: $newest"
echo "   -> $OUT_FILE ($(wc -l < "$OUT_FILE" | tr -d ' ') lines)"
echo "---- OpenList / errors ----"
grep -E "OpenList|textPreview|401|500|FAIL|WARN|ERROR|isiOSAppOnMac" "$OUT_FILE" || echo "(no OpenList lines yet)"
echo "---- tail 50 ----"
tail -n 50 "$OUT_FILE"
