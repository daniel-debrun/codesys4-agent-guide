#!/bin/bash
# start CODESYS Control (soft PLC) without systemd. Run as root. Verbatim from the bench machine's
# /usr/local/bin/start-softplc, used for every runtime start on 2026-09-30 [tested].
cd /var/opt/codesys
exec setsid su -s /bin/bash codesyscontrol -c "LD_LIBRARY_PATH=/opt/codesys/lib nohup /opt/codesys/bin/codesyscontrol.bin /etc/codesyscontrol/CODESYSControl.cfg > /var/opt/codesys/softplc.log 2>&1 &" </dev/null >/dev/null 2>&1
