"""
Patch germinal/filters/af3.py for ARM64 (aarch64) compatibility.

The upstream file hard-codes LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
when building the singularity exec command for AF3.  On aarch64 the
correct path is /usr/lib/aarch64-linux-gnu.  This script replaces the
hard-coded architecture suffix with platform.machine() so the same code
works on both x86-64 and aarch64.

Usage (run from the root of the germinal repo):
    python germinal-patches/patch_af3.py
"""

import re
import sys
from pathlib import Path

TARGET = Path("germinal/filters/af3.py")

if not TARGET.exists():
    sys.exit(f"ERROR: {TARGET} not found — run from the root of the germinal repo.")

original = TARGET.read_text(encoding="utf-8")
patched = original

# ------------------------------------------------------------------
# 1. Add "import platform" after the last stdlib import if not present
# ------------------------------------------------------------------
if "import platform" not in patched:
    # Insert after "import os" line (present in af3.py)
    patched = re.sub(
        r"^(import os\b.*)",
        r"\1\nimport platform",
        patched,
        count=1,
        flags=re.MULTILINE,
    )
    if "import platform" not in patched:
        # Fallback: prepend at top of file
        patched = "import platform\n" + patched

# ------------------------------------------------------------------
# 2. Replace the hard-coded x86_64 library path with platform.machine()
# ------------------------------------------------------------------
OLD = '"LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu"'
NEW = 'f"LD_LIBRARY_PATH=/usr/lib/{platform.machine()}-linux-gnu"'

if OLD not in patched:
    sys.exit(
        f"ERROR: expected string\n  {OLD}\nnot found in {TARGET}.\n"
        "The upstream file may have changed — inspect and patch manually."
    )

patched = patched.replace(OLD, NEW, 1)

# ------------------------------------------------------------------
# Write result
# ------------------------------------------------------------------
if patched == original:
    print(f"{TARGET}: nothing changed (already patched?).")
else:
    TARGET.write_text(patched, encoding="utf-8")
    print(f"{TARGET}: patched successfully.")
    print("  + added 'import platform'")
    print(f"  + replaced {OLD!r}")
    print(f"    with      {NEW!r}")
