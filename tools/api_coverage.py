#!/usr/bin/env python3
"""API-level test coverage for PRISM (ADR 0004).

Lists every public function declared in core/, app/ and infra/ and reports the
ones whose name never appears as a call in tests/. It is a cheap stand-in for
line coverage, which no reliable GDScript 4.7 tool provides.

Usage: python3 tools/api_coverage.py [--strict]   (--strict exits 1 on gaps)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ["core", "app", "infra"]
FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([a-zA-Z]\w*)\s*\(", re.MULTILINE)
CLASS_RE = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)


def main() -> int:
    tests = "\n".join(p.read_text() for p in (ROOT / "tests").rglob("*.gd"))
    gaps = []
    total = 0
    for folder in SOURCE_DIRS:
        for path in sorted((ROOT / folder).rglob("*.gd")):
            text = path.read_text()
            cls = (CLASS_RE.search(text) or [None, path.stem])[1]
            for name in FUNC_RE.findall(text):
                total += 1
                if not re.search(r"\b%s\(" % re.escape(name), tests):
                    gaps.append(f"{path.relative_to(ROOT)}: {cls}.{name}()")
    covered = total - len(gaps)
    print(f"API coverage: {covered}/{total} public functions referenced by tests")
    for gap in gaps:
        print(f"  untested: {gap}")
    return 1 if gaps and "--strict" in sys.argv else 0


if __name__ == "__main__":
    sys.exit(main())
