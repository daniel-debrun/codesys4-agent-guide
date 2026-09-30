#!/usr/bin/env bash
# c4-build.sh <Project.fbsdev> : resolve libraries and compile the boot application with c4-cli.
# Run as a NON-ROOT user in group codesys-4, with an absolute library repository path (docs/05 step 0).
# Output: <Project.fbsdev>/Application.iecapp^/.bootapp/Application.{app,crc}; full log in ./c4-build.log.
#
# Same logic as the bench's orchestrate/plc.py build step, which ran many times on CODESYS 4 1.0.0.0
# (2026-09-30): success is judged from the output text and the written file, not from exit codes, because
# `c4-cli library install` sometimes segfaults on exit after finishing. This bash version was checked only
# against a stub c4-cli (success, segfault-on-exit and compile-error paths); the real commands and success
# markers are [tested], this script against the real c4-cli is [unverified].
set -uo pipefail
proj=$(realpath "${1:?usage: c4-build.sh <Project.fbsdev>}")
app="$proj/Application.iecapp"
log=${LOG:-$PWD/c4-build.log}
[ "$(id -u)" -ne 0 ] || { echo "run as a non-root user in group codesys-4" >&2; exit 2; }
[ -f "$app" ] || { echo "no $app (Application.iecapp must be a file)" >&2; exit 2; }
: > "$log"

step() {   # step <success-marker> <c4-cli args...> ; up to 2 tries
  local marker=$1; shift
  for try in 1 2; do
    echo "\$ c4-cli $* (try $try)" >> "$log"
    out=$(timeout -k 10 600 c4-cli "$@" 2>&1); rc=$?
    printf '%s\n(exit %s)\n' "$out" "$rc" >> "$log"
    grep -q "$marker" <<<"$out" && return 0
  done
  return 1
}

step "Finished processing" library install "$app" -v || { echo "library install failed; see $log" >&2; exit 1; }
step "BootApp finished" bootapp compile "$app" -v || true
summary=$(grep '^Build complete' "$log" | tail -1)
echo "${summary:-no build summary}"
if [[ "$summary" != *" 0 errors"* || ! -f "$proj/Application.iecapp^/.bootapp/Application.app" ]]; then
  # show the error lines (message + position), without the per-POU progress noise
  grep -v -E '^[A-Z_0-9.]*\.\.\.$|Generate code for' "$log" | sed -n '/Build started/,/Build complete/p' | head -60 >&2
  exit 1
fi
echo "$proj/Application.iecapp^/.bootapp"
