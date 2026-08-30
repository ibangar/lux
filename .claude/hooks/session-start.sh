#!/bin/bash
# SessionStart hook: make the document skills (docx, xlsx, pptx, pdf) usable
# in Claude Code on the web.
#
# Why this exists: those skills assume their Python libraries are preinstalled
# (the xlsx skill says so explicitly and tells you not to run pip install).
# In the remote web container they are NOT installed, so any request to build
# a Word doc / spreadsheet / deck / PDF fails on the first import.
#
# Two things are needed, and the second is not obvious:
#   1. the document libraries themselves
#   2. cffi -- without it, `import pypdf` / `import pdfplumber` do not raise a
#      normal ImportError. They abort with:
#         ModuleNotFoundError: No module named '_cffi_backend'
#         pyo3_runtime.PanicException: Python API call failed
#      because pypdf imports `cryptography`, which resolves to Debian's
#      system build at /usr/lib/python3/dist-packages whose Rust extension
#      needs _cffi_backend. That package cannot be upgraded by pip
#      ("Cannot uninstall cryptography 41.0.7, RECORD file not found"),
#      so installing cffi is the fix -- do not try to upgrade cryptography.
#
# LibreOffice (soffice) is already present in the image; qpdf, pdftotext and
# tesseract are not, but they are only used by optional/advanced flows.

set -uo pipefail

# Local machines already have their own setup; only fix the remote container.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PACKAGES=(
  python-docx
  python-pptx
  openpyxl
  pandas
  pypdf
  pdfplumber
  reportlab
  markitdown
  pillow
  cffi
)

# Idempotent: on a cached container everything is already there, so verify
# first and skip the network round-trip entirely.
if python3 - <<'PY' >/dev/null 2>&1
import docx, pptx, openpyxl, pandas, pypdf, pdfplumber, reportlab, PIL
PY
then
  echo "session-start: document skill dependencies already present"
  exit 0
fi

echo "session-start: installing document skill dependencies..."

# Keep pip's own exit status: piping straight into `grep -v` would report a
# failure whenever grep filters out every line (grep exits 1 on no match),
# which is exactly what happens on a clean, warning-only install.
pip_log="$(mktemp)"
if python3 -m pip install --quiet --disable-pip-version-check "${PACKAGES[@]}" \
     >"$pip_log" 2>&1; then
  grep -viE 'Running pip as the .root. user' "$pip_log" || true
else
  echo "session-start: WARNING - pip install did not complete cleanly" >&2
  cat "$pip_log" >&2
fi
rm -f "$pip_log"

# Report, but never block the session on this.
python3 - <<'PY'
mods = ["docx", "pptx", "openpyxl", "pandas", "pypdf", "pdfplumber", "reportlab", "PIL"]
missing = []
for m in mods:
    try:
        __import__(m)
    except BaseException:
        missing.append(m)
print("session-start: document skills ready" if not missing
      else "session-start: WARNING - still unavailable: " + ", ".join(missing))
PY

exit 0
