#!/usr/bin/env python3
"""API-level test coverage for PRISM (ADR 0004).

Lists every public function declared in core/, app/ and infra/ and reports the
ones that tests never reach. A function counts as reached when its name is
called in tests/, or when its class is used in tests/ and the name is called
somewhere in the source (polymorphic dispatch, e.g. ToolController calling
Tool.begin() on every registered tool). It is a cheap stand-in for line
coverage, which no reliable GDScript 4.7 tool provides.

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
    source = "\n".join(p.read_text() for d in SOURCE_DIRS + ["ui", "boot"] for p in (ROOT / d).rglob("*.gd"))
    source = re.sub(r"^\s*(?:static\s+)?(?:@abstract\s+)?func\s.*$", "", source, flags=re.MULTILINE)
    gaps = []
    total = 0
    for folder in SOURCE_DIRS:
        for path in sorted((ROOT / folder).rglob("*.gd")):
            text = path.read_text()
            cls = (CLASS_RE.search(text) or [None, path.stem])[1]
            for name in FUNC_RE.findall(text):
                total += 1
                call = re.compile(r"\.%s\(|\b%s\(" % (re.escape(name), re.escape(name)))
                class_used = re.search(r"\b%s\b" % re.escape(cls), tests)
                called_in_source = call.search(source) is not None
                if not call.search(tests) and not (class_used and called_in_source):
                    gaps.append(f"{path.relative_to(ROOT)}: {cls}.{name}()")
    covered = total - len(gaps)
    print(f"API coverage: {covered}/{total} public functions referenced by tests")
    for gap in gaps:
        print(f"  untested: {gap}")
    return 1 if gaps and "--strict" in sys.argv else 0


if __name__ == "__main__":
    sys.exit(main())
