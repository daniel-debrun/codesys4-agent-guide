# 02: CODESYS Control for Linux SL 4.22 (the soft PLC)

Scope: the `codesyscontrol` 4.22.0.0 amd64 package, in an unprivileged Ubuntu 24.04 Docker container
without systemd or CodeMeter. Last checked 2026-09-30.

## Getting the .deb

The runtime ships as a CODESYS `.package`, which is a zip file. Inside it, `Delivery/linux/` holds
`codesyscontrol_linux_4.22.0.0_amd64.deb`, plus `.rpm` and `.ipk` variants [observed, manual session]:

```bash
unzip -l CODESYS_Control_for_Linux_SL_*.package | grep Delivery/linux
unzip -j CODESYS_Control_for_Linux_SL_*.package 'Delivery/linux/codesyscontrol_linux_4.22.0.0_amd64.deb'
```

The IDE side already has the matching device description and libraries: the extension
`CODESYS.C4.Control.for.Linux.SL.Ext/4.22.0` holds device type 4102, id `0000 0005`, version 4.22.0.0 [tested].

## Package facts

| Fact | Status |
|---|---|
| `Package: codesyscontrol`, `Version: 4.22.0.0`, `Depends: codemeter \| codemeter-lite, libc6 (>= 2.34), systemd (>= 240)` | [tested] |
| Files: `/opt/codesys/bin/codesyscontrol.bin`, `/opt/codesys/lib/*.so`, `/opt/codesys/scripts/{pre_start.sh,pre_start_codemeter.sh,cfg_add_cmp.sh,PlcWink.sh,rts_set_baud.sh}`, `/etc/codesyscontrol/{CODESYSControl.cfg,CODESYSControl_User.cfg,3S.dat}`, `/etc/default/codesyscontrol`, `/etc/systemd/system/codesyscontrol.service` (+ `.d/override.conf`), `/etc/security/limits.d/codesyscontrol.conf` (rtprio 99, memlock unlimited) | [tested] (`dpkg -L`) |
| The postinst creates user `codesyscontrol` and groups `codesyscontrolapi` and `codesysproxyapi`, makes both cfg files `a+rw`, and runs `chmod o-rx` on `/var/opt/codesys`, `/opt/codesys` and `/etc/codesyscontrol` | [tested] (postinst read) |
| The postinst **skips `systemctl enable/start`** when `$CONTAINER = true`, `/.dockerenv` exists, or `/run/.containerenv` exists, and prints `Container-environment detected. Not installing daemon.` | [tested] (postinst read) |
| The runtime identifies itself in its log as `CODESYS Control for Linux SL`, `<version>3.5.22.30</version> <builddate>Aug 12 2026</builddate>` | [tested] |

### Without CodeMeter (development only)

apt refuses the package when neither `codemeter` nor `codemeter-lite` is installed, and it then leaves apt in a
broken-dependency state. On the bench machine an **empty stub package** satisfied the dependency [tested]:

```text
Package: codemeter-lite
Version: 0.0-stub1
Architecture: all
Maintainer: dev <dev@localhost>
Description: Empty stub so apt accepts codesyscontrol without CodeMeter (dev VM only, runtime stays in demo mode)
```

```bash
mkdir -p stub-codemeter/DEBIAN && $EDITOR stub-codemeter/DEBIAN/control   # the text above
dpkg-deb --build stub-codemeter codemeter-lite-stub.deb
dpkg -i codemeter-lite-stub.deb && dpkg -i codesyscontrol_linux_4.22.0.0_amd64.deb
```

With the stub installed, the runtime runs in **demo mode** only. Do not do this on anything that should run
licensed. Warning: `apt --fix-broken install` could remove CODESYS instead of fixing the dependency; one
setup note from the bench says so [observed].

## Starting and stopping without systemd

The unit file shows what systemd would do (`User=codesyscontrol`, `WorkingDirectory=/var/opt/codesys`,
`LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/codesys/lib`, `ExecStart=/opt/codesys/bin/codesyscontrol.bin /etc/codesyscontrol/CODESYSControl.cfg`,
plus `pre_start.sh`, which refuses to run without `systemctl`). The script below reproduces it by hand. It
was used for every start on the bench [tested]:

```bash
#!/bin/bash
# start CODESYS Control (soft PLC) without systemd  (/usr/local/bin/start-softplc on the bench)
cd /var/opt/codesys
exec setsid su -s /bin/bash codesyscontrol -c "LD_LIBRARY_PATH=/opt/codesys/lib nohup /opt/codesys/bin/codesyscontrol.bin /etc/codesyscontrol/CODESYSControl.cfg > /var/opt/codesys/softplc.log 2>&1 &" </dev/null >/dev/null 2>&1
```

Stop it with SIGTERM and wait for the process to exit [tested]:

```bash
for p in $(pgrep -f '^/opt/codesys/bin/codesyscontrol.bin'); do kill "$p"; done
for i in $(seq 60); do pgrep -f '^/opt/codesys/bin/codesyscontrol.bin' >/dev/null || break; sleep 1; done
```

The log then shows `CODESYS Control shutdown...` and `Server OPC UA stopped!`, about 5 s later [tested].
If you script this over ssh, do not use `pkill -f <pattern>` with a pattern that also appears in your own ssh
command line, because it kills your own session. Use the `pgrep "[c]odesyscontrol"` trick or anchor the
pattern as above [observed: a rule from the bench environment's notes].

## Ports

Checked with `ss -ltnup` while the runtime ran [tested]:

| Port | Protocol | Bound to | Use |
|---|---|---|---|
| 11740 | TCP | `0.0.0.0` | programming / gateway communication |
| 1740 | UDP | container IP and broadcast address | network scan |
| 4840 | TCP | `127.0.0.1` and the container IP | OPC UA server (log: `URL: opc.tcp://<hostname>:4840`) |

OPC UA runs [tested]: the log shows `Valid license found for OPC UA IecVarAccess provider.`. Reading IEC
variables over it was **not** achieved, because no symbol configuration was found in CODESYS 4 1.0
[observed, see `docs/05`].

## Startup timeline and what the log says

File: `/var/opt/codesys/codesyscontrol.log` (CSV-like: `timestamp, CmpId, ClassId, ErrorId, InfoId, text`,
where ClassId 1 is info, 2 warning, 4 error, 8 exception). Stdout goes to `softplc.log` in the script above.
The logger rotates at 1 MB × 3 files (`CODESYSControl.cfg [CmpLog]`) [tested].

Typical sequence on this container, with no CodeMeter [tested, many restarts]. The listing combines several
starts, shows only the text column, and may not match the exact order within one second:

```text
**** ERROR: CmRuntime could not be connected within 60[s]: iLastError=0      <- ~60 s wait
Running as proxy client
**** ERROR: USockConnect: No such file or directory /var/opt/codesysproxyapi/proxy.sock
**** ERROR: Proxy_RemoteCall: connect failed 2
**** ERROR: Disabling DMA latency failed: 256
Local network address: <ipaddress>172.17.0.2</ipaddress>
**** ERROR: CodeMWriteLicenseFile: CodeMeter access denied
**** ERROR: CodeMCreateInitialSoftcontainer: Error creating initial empty soft container
Not able to read file of Run/Stop switch. Functionality of component disabled
CODESYS Control for Linux SL ... <version>3.5.22.30</version>
Bootproject of application [<app>Application</app>] load started ...
Application [<app>Application</app>] loaded via [Bootproject]
No retain area in bootproject of application [<app>Application</app>]
Bootproject of application [<app>Application</app>] loaded
**** ERROR: socket permissions: connection error to proxy
**** ERROR: ServerThread: bind failed 2
Application [<app>Application</app>] started
Number of licensed cores for IEC-tasks: 1 from 16
no runtime license - running in demo mode(~2 hours)
CODESYS Control ready
```

- **All the `**** ERROR` lines above were harmless** for a boot application that runs ST logic and uses
  sockets. The application started and ran for hours every time [tested]. They come from the missing
  CodeMeter, the missing proxy socket (`/var/opt/codesysproxyapi/proxy.sock`) and container limits.
- **About 60 s pass from process start to `Application ... started`**, and all of it is the CodeMeter wait.
  After a deploy, MQTT output resumed after 56-62 s [tested, at least 6 restarts].
- One manual first-install session reported about 1 minute of certificate generation before 11740, 1740 and
  4840 listened [observed]. In the logs we have, `Create asymmetric key in progress...` / `done!` took less
  than a second, so the 60 s CodeMeter wait is the likelier cause of the delay [unverified].
- `Number of licensed cores for IEC-tasks: 1 from 16`: in demo mode, IEC tasks use one core [tested log line].

## Demo mode and licences

| Item | What we saw | Status |
|---|---|---|
| Runtime | `no runtime license - running in demo mode(~2 hours)` at every start | [tested] |
| Runtime stop after ~2 h | The environment notes say demo mode stops the runtime after about 2 h and that restarting fixes it; every deploy restarts the runtime anyway | [observed] |
| MQTT Client SL library | `**** ERROR: License for MQTTClientSL library not installed. Running for 30 minutes in demo mode.` | [tested log line] |
| Web Socket Client SL (pulled in by MQTT Client SL) | `**** ERROR: License for Web Socket Client SL library not installed. Running for 30 minutes in demo mode.` | [tested log line] |
| MQTT Client SL after its demo time was used up | client connects, publishes for about 34 s after each restart, then stops. Restarting the runtime did not reset this | [observed, twice] |

See `docs/06` for the workaround.

## Files the runtime keeps in `/var/opt/codesys`

[tested listing] `PlcLogic/` (boot applications go in `PlcLogic/Application/`, plus `visu`, `trend`, `alarms`,
`ac_persistence`, `_cnc`), `cert/`, `.pki/`, `OPCUAServer/`, `OPCUAClient/`, `SysFileMap.cfg`,
`.ObjectDatabase.csv`, `.AuditLog.csv`, CodeMeter soft-container files (`.UFC_SoftContainer_CmRuntime.WibuCmLif`
and others), `bacstac.ini`, and the log files.

After it loads a boot application, the runtime rewrote `Application.crc` (28 bytes as built, 20 bytes after
load) and recorded the app in `SysFileMap.cfg`, e.g.
`PlcLogic/Application/Application.app=0x5E8AC, 0x21C71FA5, 21C71FA5.app` [observed].

## Config you will touch

`/etc/codesyscontrol/CODESYSControl_User.cfg`, section `[CmpApp]`, on the working bench [tested]:

```ini
[CmpApp]
Application.1=Application
Bootproject.RetainMismatch.Init=0
SECURITY.UnsignedApplicationFileTransfer=DENY
;RetainType.Applications=InSRAM
```

- `Application.1=Application` makes the runtime load `PlcLogic/Application/Application.app` at start. The
  deploy script adds the line if it is missing. We did not test whether the runtime loads the app without it
  [unverified].
- `SECURITY.UnsignedApplicationFileTransfer=DENY` was present, and it did **not** stop a boot application
  copied in as a file from loading [tested]. We do not know whether the package sets it by default
  [unverified].
- `CODESYSControl.cfg` has `[CmpSettings] IsWriteProtected=1` and references the `_User.cfg` file. Edit
  `_User.cfg`, not the main file [observed].
