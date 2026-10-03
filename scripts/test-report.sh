#!/usr/bin/env bash
# Run the Daml test suite and regenerate the contract-table screenshots in Img/.
#
# What it does
#   1. Runs `dpm test` once per file in daml/Test so scripts that share a name
#      (both lending tests export `testScript`) do not overwrite each other.
#   2. Splits the per-script table HTML emitted by `--table-output` into one
#      standalone page per template, with the compiler stylesheet inlined.
#   3. Screenshots each page with headless Google Chrome into Img/<Template>.png.
#
# Usage
#   scripts/test-report.sh                 # regenerate Img/*.png from the partial disburse/repay run
#   REPORT_SOURCE=LendingSuccessLoan scripts/test-report.sh
#   SKIP_PNG=1 scripts/test-report.sh      # only produce HTML under test-report/
#
# Requirements: dpm on PATH, python3, Google Chrome (for PNGs).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/test-report"
IMG_DIR="$ROOT/Img"
SOURCE="${REPORT_SOURCE:-LendingPartialDisburseRepay}"

# Pick a headless Chromium. Preference order:
#   1. CHROME_BIN (explicit override)
#   2. Playwright's chrome-headless-shell (classic headless; exits cleanly)
#   3. Google Chrome (new headless; can hang on exit on macOS, so it is run with a timeout)
find_chrome() {
  if [ -n "${CHROME_BIN:-}" ]; then echo "$CHROME_BIN"; return; fi
  local shell_bin
  shell_bin="$(ls -d "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-mac-*/chrome-headless-shell 2>/dev/null | sort -V | tail -n 1 || true)"
  if [ -n "$shell_bin" ] && [ -x "$shell_bin" ]; then echo "$shell_bin"; return; fi
  echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
}
CHROME="$(find_chrome)"

cd "$ROOT"

if ! command -v dpm >/dev/null 2>&1; then
  echo "dpm not found on PATH. Install it from https://docs.digitalasset.com and add ~/.dpm/bin to PATH." >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

# Locate the webview stylesheet shipped with the active damlc component.
CSS_FILE="$(find "${DPM_HOME:-$HOME/.dpm}/cache/components/damlc" -name webview-stylesheet.css 2>/dev/null | sort | tail -n 1 || true)"

# 1. Run each test file into its own output directory.
status=0
for test_file in daml/Test/*.daml; do
  name="$(basename "$test_file" .daml)"
  echo "==> dpm test $test_file"
  if ! dpm test --files "$test_file" \
        --table-output "$OUT/$name/tables" \
        --transactions-output "$OUT/$name/transactions" \
        2>&1 | grep -v 'SCRIPT SERVICE STDERR\|^\s*$\|\[ERROR\]  \[test ScriptService\]'; then
    status=1
  fi
done

# 2. Split each table HTML into standalone per-template pages.
python3 - "$OUT" "$CSS_FILE" <<'PY'
import html, pathlib, re, sys

out = pathlib.Path(sys.argv[1])
css_path = sys.argv[2]
css = pathlib.Path(css_path).read_text() if css_path else ""

theme = """
:root { color-scheme: dark; }
body { margin: 0; padding: 20px 24px 24px; background: #1e1e1e; color: #e6e6e6;
       font: 15px/1.35 -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif; display: inline-block; }
h1 { font-size: 24px; margin: 0 0 14px; }
table { border-color: #9a9a9a; }
th, td { padding: 4px 6px; white-space: nowrap; }
th { font-weight: 600; }
tr.archived td { color: #bdbdbd; }
.tooltiptext { display: none; }
"""

block_re = re.compile(r'<div class="(active|archived)"><h1>(.*?)</h1>(<table>.*?</table>)</div>', re.S)

for table_file in sorted(out.glob("*/tables/table-*.html")):
    raw = table_file.read_text()
    raw = re.sub(r"<style>.*?</style>", "", raw, count=1, flags=re.S)
    script_dir = table_file.parent.parent
    pages = script_dir / "templates"
    pages.mkdir(exist_ok=True)
    for state, title, table in block_re.findall(raw):
        template = html.unescape(title).split(":")[-1]
        page = (
            "<!doctype html><html><head><meta charset=\"utf-8\">"
            f"<title>{html.escape(title)}</title><style>{css}{theme}</style>"
            "<script>addEventListener('load',()=>{const r=document.body.getBoundingClientRect();"
            "document.documentElement.dataset.w=Math.ceil(r.width);"
            "document.documentElement.dataset.h=Math.ceil(r.height);});</script>"
            f"</head><body><div class=\"table\"><div class=\"{state}\"><h1>{title}</h1>{table}</div></div></body></html>"
        )
        (pages / f"{template}.html").write_text(page)
    print(f"split {table_file.relative_to(out)} -> {len(block_re.findall(raw))} template page(s)")
PY

if [ "${SKIP_PNG:-0}" = "1" ]; then
  echo "HTML written to $OUT (SKIP_PNG=1, no screenshots)."
  exit $status
fi

if [ ! -x "$CHROME" ]; then
  echo "Google Chrome not found at: $CHROME" >&2
  echo "Set CHROME_BIN to a Chrome/Chromium binary, or run with SKIP_PNG=1." >&2
  exit 1
fi

SRC_PAGES="$OUT/$SOURCE/templates"
if [ ! -d "$SRC_PAGES" ]; then
  echo "No template pages found for REPORT_SOURCE=$SOURCE under $OUT" >&2
  exit 1
fi

# 3. Screenshot each template page at its natural size.
mkdir -p "$IMG_DIR"
PROFILE="$(mktemp -d)"
trap 'rm -rf "$PROFILE"' EXIT

# Run a command, killing it after $1 seconds. macOS has no `timeout`, and
# Google Chrome's new headless mode sometimes finishes its work but never exits.
with_timeout() {
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) 2>/dev/null & local watchdog=$!
  wait "$pid" 2>/dev/null || true
  { kill "$watchdog" && wait "$watchdog"; } 2>/dev/null || true
}

chrome() {
  with_timeout 20 "$CHROME" --headless --disable-gpu --no-first-run --hide-scrollbars \
    --user-data-dir="$PROFILE" --force-device-scale-factor=2 "$@" 2>/dev/null
}

echo "Renderer: $CHROME"
for page in "$SRC_PAGES"/*.html; do
  template="$(basename "$page" .html)"
  dims="$(chrome --dump-dom --window-size=2400,2400 "file://$page" | sed -n 's/.*data-w="\([0-9]*\)" data-h="\([0-9]*\)".*/\1 \2/p' | head -n 1)"
  w="${dims%% *}"; h="${dims##* }"
  if [ -z "$w" ] || [ -z "$h" ]; then w=1400; h=600; fi
  chrome --screenshot="$IMG_DIR/$template.png" --window-size="$w,$h" "file://$page"
  echo "wrote Img/$template.png (${w}x${h} css px, 2x)"
done

echo
echo "Report HTML: $OUT"
echo "Screenshots: $IMG_DIR (source script: $SOURCE)"
exit $status
