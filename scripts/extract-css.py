#!/usr/bin/env python3
"""Extract every scrap of CSS from a rendered Quarto revealjs HTML file.

Why this exists: with `embed-resources: true`, Quarto inlines stylesheets as
`<link href="data:text/css,...">` where the payload is PERCENT-encoded, not
base64. Grepping the raw HTML for a selector therefore finds nothing even when
the rule is present and working. Any check that greps the HTML directly will
give a false negative. This script is the only trustworthy way to ask "did my
theme actually make it into the deck?".

Usage:
  extract-css.py <file.html>              # print a size summary
  extract-css.py <file.html> <probe>...   # count occurrences of each probe
"""

import base64
import re
import sys
import urllib.parse
from pathlib import Path


def extract(html: str) -> str:
    css = "\n".join(re.findall(r"<style[^>]*>(.*?)</style>", html, re.S))
    for m in re.finditer(r'href="data:text/css([;,])([^"]*)"', html):
        payload = m.group(2)
        if payload.startswith("base64,"):
            css += "\n" + base64.b64decode(payload[7:]).decode("utf-8", "replace")
        else:
            css += "\n" + urllib.parse.unquote(payload)
    return css


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"no such file: {path}", file=sys.stderr)
        return 1
    css = extract(path.read_text(errors="replace"))
    probes = sys.argv[2:]
    if not probes:
        print(f"{path}: {len(css)} chars of CSS recovered")
        return 0
    missing = 0
    for p in probes:
        n = css.count(p)
        flag = "ok " if n else "MISSING"
        print(f"  {flag} {p:26} {n}")
        if not n:
            missing += 1
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
