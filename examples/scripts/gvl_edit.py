#!/usr/bin/env python3
"""Change initial values in a CODESYS 4 GVL (.gvl) without touching anything else.

Adapted from the bench project's orchestrate/core.py (edit_gvl, st_literal, read_gvl). The only change is that
values may be given as text on the command line. That code applied and reverted real changes on 2026-09-30.
Rules it enforces:
  - each variable must be declared exactly once, on one line, with an initial value:  Name : TYPE := value;
  - integer types get integer literals; STRING gets a quoted literal (' escaped as $'); anything else is
    written as a REAL/LREAL literal (e.g. 49500.0). Values tested on the PLC: 49500.0, 55000.0 and a STRING
    tag. An exponent form such as 1.0E-5 is produced for tiny values but was never compiled.

usage: gvl_edit.py FILE.gvl Name=value [Name=value ...]    (prints a unified diff, writes the file)
"""
import difflib
import re
import sys
from pathlib import Path

INT_TYPES = {"SINT", "INT", "DINT", "LINT", "USINT", "UINT", "UDINT", "ULINT"}


def _decl(name):
    return re.compile(rf"^(\s*{re.escape(name)}\s*:\s*(\w+)(?:\(\d+\))?\s*:=\s*)([^;]+)(;.*)$", re.M)


def st_literal(value, typ):
    if typ in INT_TYPES:
        if float(value) != int(float(value)):
            raise ValueError(f"{value} is not an integer ({typ})")
        return str(int(float(value)))
    if typ == "STRING":
        return "'" + str(value).replace("'", "$'") + "'"
    s = repr(float(value))
    mant, _, exp = s.partition("e")
    return (mant if "." in mant else mant + ".0") + (f"E{int(exp)}" if exp else "")


def edit_gvl(text, assignments):
    """New GVL text with `NAME := value` replaced for each {var_name: value}."""
    for name, value in assignments.items():
        pat = _decl(name)
        hits = pat.findall(text)
        if len(hits) != 1:
            raise ValueError(f"{name}: expected one declaration with an initial value, found {len(hits)}")
        text = pat.sub(lambda m: m.group(1) + st_literal(value, m.group(2).upper()) + m.group(4), text)
    return text


def read_gvl(text, names):
    out = {}
    for name in names:
        m = _decl(name).search(text)
        out[name] = m.group(3).strip() if m else None
    return out


if __name__ == "__main__":
    path = Path(sys.argv[1])
    if "safety" in str(path).lower():
        sys.exit("refusing to edit a safety-related file")   # keep automated edits away from safety logic
    old = path.read_text()
    new = edit_gvl(old, dict(a.split("=", 1) for a in sys.argv[2:]))
    sys.stdout.writelines(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                               f"a/{path.name}", f"b/{path.name}"))
    path.write_text(new)
