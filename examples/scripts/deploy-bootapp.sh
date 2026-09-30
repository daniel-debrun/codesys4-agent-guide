#!/usr/bin/env bash
# deploy-bootapp.sh <dir with Application.app + Application.crc> : install a boot application into
# CODESYS Control for Linux SL 4.22 and restart it. Run as ROOT on the runtime host.
# THIS RESTARTS THE PLC. Never run it against equipment that can move.
#
# Same steps as the bench's plcdeploy.sh / orchestrate/plc.py deploy, which worked many times on 2026-09-30
# in a container without systemd [tested steps]. Set START to your start command (default: the no-systemd
# start script from docs/02; on a systemd host use "systemctl start codesyscontrol" [unverified]).
set -euo pipefail
src=${1:?usage: deploy-bootapp.sh <.bootapp dir>}
RT=/var/opt/codesys/PlcLogic/Application
CFG=/etc/codesyscontrol/CODESYSControl_User.cfg
START=${START:-/usr/local/bin/start-softplc}
PROC='^/opt/codesys/bin/codesyscontrol.bin'
BACKUPS=${BACKUPS:-/var/backups/codesys-bootapp}

[ -f "$src/Application.app" ] && [ -f "$src/Application.crc" ] || { echo "need Application.app and .crc in $src" >&2; exit 2; }

bak="$BACKUPS/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$bak"
cp -p "$RT/Application.app" "$RT/Application.crc" "$bak/" 2>/dev/null || true
echo "previous boot application saved in $bak"

grep -q '^Application.1=Application' "$CFG" || sed -i 's/^\[CmpApp\]$/[CmpApp]\nApplication.1=Application/' "$CFG"
grep -q '^Application.1=Application' "$CFG" || { echo "could not add Application.1=Application under [CmpApp] in $CFG" >&2; exit 1; }

for p in $(pgrep -f "$PROC" || true); do kill "$p"; done
for i in $(seq 60); do pgrep -f "$PROC" >/dev/null || break; sleep 1; done
pgrep -f "$PROC" >/dev/null && { echo "runtime did not stop" >&2; exit 1; }

mkdir -p "$RT"
cp "$src/Application.app" "$src/Application.crc" "$RT/"
chown -R codesyscontrol:codesyscontrol "$RT"
$START

# the app starts ~60 s later without CodeMeter; wait for the log line
for i in $(seq 120); do
  if grep -q "Application \[<app>Application</app>\] started" <(tail -n 200 /var/opt/codesys/codesyscontrol.log); then
    tail -n 200 /var/opt/codesys/codesyscontrol.log | grep -n 'Bootproject\|Application \[<app>' | tail -4
    exit 0
  fi
  sleep 1
done
echo "no 'Application ... started' line after 120 s; check /var/opt/codesys/codesyscontrol.log" >&2
exit 1
