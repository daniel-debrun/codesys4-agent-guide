#!/usr/bin/env python3
"""Parse `c4-cli bootapp compile` console output (CODESYS 4 1.0.0.0) into a summary and a list of errors.

The console output is wrapped at 80 columns: a soft wrap leaves a trailing space, and a hard wrap (a long
path) breaks at exactly 80 characters. This script joins wrapped lines back together, then matches
    <message> <file> (<line>, <column>, length: <n>)
where line is 1-based and column 0-based. Tested on real build logs from 2026-09-30 (see
examples/scripts/testdata/). Heuristic: a message of exactly 80 characters that is not wrapped would be
joined wrongly with the next line; a line ending in a position "(l, c, length: n)" always ends a record.

usage: parse_build_log.py build.log      -> JSON on stdout; exit 0 if "Build complete -- 0 errors" was seen
"""
import json
import re
import sys

WIDTH = 80
POS = re.compile(r"^(?P<msg>.*?)\s*(?P<file>/.*?\.(?:st|gvl|json)) \((?P<line>\d+), (?P<col>\d+), "
                 r"length: (?P<len>\d+)\)\s*$")
END = re.compile(r"\(\d+, \d+, length: \d+\)\s*$")


def records(text):
    """Logical lines: join soft (trailing space) and hard (exactly WIDTH chars) wrapped lines."""
    out, cur = [], ""
    for raw in text.splitlines():
        cur += raw
        if not END.search(raw) and (raw.endswith(" ") or len(raw) == WIDTH):
            continue
        out.append(cur.strip())
        cur = ""
    if cur:
        out.append(cur.strip())
    return out


def parse(text):
    recs = records(text)
    errors = []
    for r in recs:
        m = POS.match(r)
        if m:
            errors.append({"message": m["msg"].strip(), "file": m["file"], "line": int(m["line"]),
                           "column": int(m["col"]), "length": int(m["len"])})
    summaries = [r for r in recs if r.startswith("Build complete")]
    summary = summaries[-1] if summaries else None
    ok = bool(summary and " 0 errors" in summary)
    return {"ok": ok, "summary": summary, "errors": errors,
            "bootapp_written": any(r.startswith("BootApp finished") for r in recs)}


if __name__ == "__main__":
    text = open(sys.argv[1], encoding="utf-8", errors="replace").read() if len(sys.argv) > 1 else sys.stdin.read()
    result = parse(text)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["ok"] else 1)
