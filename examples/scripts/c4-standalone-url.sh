#!/bin/bash
# c4-standalone-url.sh [user] : start a headless CODESYS 4 standalone session as <user> (default dev) and
# print its URL, for driving the UI with Playwright. Run as root. Adapted from the bench's c4sess.sh [tested].
# Open the URL in ONE browser only: a second browser gets HTTP 403 (docs/01). Kill the session when done:
#   pkill -u <user> -f '[s]tandalone-session'
set -u
user=${1:-dev}
cat > /tmp/fakebrowser.sh <<'FB'
#!/bin/bash
echo "$@" >> /tmp/c4url.txt
sleep 100000
FB
chmod 755 /tmp/fakebrowser.sh
for p in $(pgrep -u "$user" -f '[s]tandalone-session'); do kill "$p"; done
pkill -f '[f]akebrowser.sh'
sleep 2
rm -f /tmp/c4url.txt
home=$(getent passwd "$user" | cut -d: -f6)
mkdir -p "$home/c4work"; chown "$user:" "$home/c4work"
setsid nohup su - "$user" -c "cd $home/c4work && c4-cli standalone-session --with-browser /tmp/fakebrowser.sh -v" \
  </dev/null >/tmp/c4standalone.log 2>&1 &
for i in $(seq 40); do [ -s /tmp/c4url.txt ] && break; sleep 1; done
cat /tmp/c4url.txt 2>/dev/null || { echo "no URL; see /tmp/c4standalone.log" >&2; exit 1; }
