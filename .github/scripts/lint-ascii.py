#!/usr/bin/env python3
# Reject non-ASCII characters appearing outside `#` comments in the four
# user-facing setup/install scripts. Run from the repo root.
#
# Why this exists:
#   Windows PowerShell 5.1 (default on Win10/11) reads .ps1 files as
#   Windows-1252 unless they carry a UTF-8 BOM. A stray em-dash or curly
#   quote inside a "..." string literal gets mojibaked into bytes that
#   include a literal `"`, which closes the string early and cascades
#   parser errors through the rest of the file. A real client install
#   broke on exactly this. Enforcing ASCII outside comments is simpler
#   than managing UTF-8 BOMs across editors, git archive zip flows, and
#   PowerShell tooling.
#
# Approximation:
#   The trailing-`#`-comment detection tracks single-line "..." and '...'
#   quote state. It does NOT model multi-line PowerShell here-strings
#   (@"..."@ / @'...'@) or bash heredocs. Those tolerate stray quotes
#   internally, but our rule treats their contents as code anyway, which
#   is fine: the enforced rule (no non-ASCII outside `#`) is a strict
#   superset of "no non-ASCII in a place that breaks PowerShell parsing".
#
# Exit codes:
#   0 - all scripts clean
#   1 - one or more non-ASCII chars found outside a comment

from __future__ import annotations

import pathlib
import sys
import unicodedata

FILES = [
    "setup-windows.ps1",
    "install.ps1",
    "setup-mac.sh",
    "install.sh",
]


def code_part(line: str) -> str:
    """Return the portion of `line` that is NOT a trailing `#` comment.

    A `#` only starts a comment when it appears at the start of the line or
    after whitespace, AND when we are not currently inside a quoted string.
    """
    n = len(line)
    i = 0
    in_dq = False
    in_sq = False
    prev = ""
    while i < n:
        c = line[i]
        if not in_dq and not in_sq:
            if c == "'":
                in_sq = True
            elif c == '"':
                in_dq = True
            elif c == "#" and (i == 0 or prev.isspace()):
                return line[:i]
        elif in_sq and c == "'":
            in_sq = False
        elif in_dq and c == '"':
            in_dq = False
        prev = c
        i += 1
    return line


def main() -> int:
    bad = 0
    for f in FILES:
        p = pathlib.Path(f)
        if not p.exists():
            # Hard fail: if a tracked setup script is renamed or deleted
            # without updating FILES, silent skipping would let non-ASCII
            # slip into the renamed file and break PowerShell parsing on
            # Win10/11. Force the rename to update both places.
            print(f"::error file={f}::expected file is missing - update FILES list")
            bad += 1
            continue
        text = p.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.split("\n"), 1):
            for ch in code_part(line):
                if ord(ch) > 127:
                    name = unicodedata.name(ch, "?")
                    print(
                        f"::error file={f},line={lineno}::"
                        f"non-ASCII {ch!r} ({hex(ord(ch))}, {name}) outside # comment"
                    )
                    bad += 1
                    break  # one error per line is enough noise

    if bad:
        print()
        print(f"Found {bad} problem(s) above (missing files and/or non-ASCII chars outside # comments).")
        print("Windows PowerShell 5.1 reads .ps1 files as Windows-1252 unless they")
        print("have a UTF-8 BOM, so non-ASCII bytes inside string literals get")
        print("mojibaked mid-string and break parsing. Replace with ASCII (e.g.")
        print("em-dash to '-', smart quotes to straight, box-drawings to '+|-').")
        print("If a file is reported missing, update the FILES list in this script")
        print("to match the rename.")
        return 1

    print(f"OK: all {len(FILES)} setup/install scripts are ASCII outside # comments.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
