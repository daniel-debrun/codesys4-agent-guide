# 01: Installing the CODESYS 4 IDE on Ubuntu

Scope: `codesys-4_1.0.0.0_amd64.deb` on Ubuntu 24.04 (amd64), in a Docker container without systemd.
Last checked 2026-09-30.

## The package

| Fact | Status |
|---|---|
| File name `codesys-4_1.0.0.0_amd64.deb`; package `codesys-4`, version `1.0.0.0`, maintainer `CODESYS Development GmbH` | [tested] (`dpkg -s codesys-4`) |
| `Depends: aspnetcore-runtime-8.0 (>= 8.0.29)`; the machine had `Microsoft.AspNetCore.App 8.0.31` and `Microsoft.NETCore.App 8.0.31` under `/usr/lib/dotnet` | [tested] |
| Installs to `/opt/codesys-4` (the .NET assemblies, the web UI in `dist/c4/`, and `extensions/`) | [tested] |
| `dist/version.json`: `{ "version":"1.0.0.0-v1-0-0-0-12180","buildDate":"2026-09-23T15:42:26+02:00" }` | [tested] |

```bash
sudo apt install ./codesys-4_1.0.0.0_amd64.deb     # pulls aspnetcore-runtime-8.0   [observed, manual session]
c4-cli version                                      # -> "CODESYS 4 1.0.0.0"          [tested]
c4-cli version --json                               # -> {"CODESYS 4":"1.0.0.0"}      [tested]
```

### What the postinst does

This is read from `/var/lib/dpkg/info/codesys-4.postinst` [tested]:

- `ln -sf /opt/codesys-4/c4-cli /usr/bin/c4-cli`, and the same for `c4-pkm` and `c4-server`.
- On a fresh install (not on upgrade): `groupadd codesys-4` if the group is missing, and
  `echo /opt/codesys-4 > /etc/ld.so.conf.d/codesys-4.conf; ldconfig`. The script's comment says this lets the
  app find `libcpsrt.so`.
- `cd /opt/codesys-4` (the comment cites a .NET stack-overflow bug, dotnet/runtime#113855), then
  `c4-pkm install --install-all /opt/codesys-4/extensions`.
  Note that `c4-pkm install --help` lists this option as `-a, --all`, not `--install-all`. [tested]

### Bundled extensions

On this machine `/opt/codesys-4/extensions` holds 58 directory entries: a capitalised and a lower-case copy of
most extensions, plus `spectre.console*` [tested]. The 26 capitalised extensions are:

`BaseLibraries`, `Code386`, `CodeARM`, `CodeARM64`, `Codex86-64`, `Compiler`, `Control.SL.Extension.Package`,
`Control.for.IOT2000.SL`, `Control.for.Linux.ARM.SL`, `Control.for.Linux.ARM64.SL`, `Control.for.Linux.SL`,
`Control.for.PFC100.SL`, `Control.for.PFC200.SL`, `Control.for.Raspberry.PI`,
`Control.for.WAGO.Touch.Panels.600.SL`, `Control.for.emPC-A-iMX6.SL`, `GlobalDevices`, `GlobalLibraries`,
`IIoTLibraries`, `Ladder`, `MathLibraries`, `Modbus`, `Peripherals.for.Linux.SL`, `RISCFrontEnd`,
`SourceCodeEditor`, `Virtual.Control.for.Linux.SL`. Each name is prefixed `CODESYS.C4.` and suffixed `.Ext`.

Useful paths inside an extension [tested]:

```text
/opt/codesys-4/extensions/<Ext>/<ver>/c4Libs/<Vendor>/<Library>/<ver>/<Library>.compiled-library[-v3]
/opt/codesys-4/extensions/<Ext>/<ver>/c4Placeholders.json      # placeholder -> "Name, x.y.z (Vendor)"
/opt/codesys-4/extensions/<Ext>/<ver>/cdsV3Devs/<type>/<id>/<ver>/device.xml   # device descriptions
/opt/codesys-4/extensions/<Ext>/<ver>/inst-info.json            # install date and flags
```

`inst-info.json` for the Linux SL extension read
`"InstallationFlags":"AllowUnsignedPackages, AllowExpiredPackages, SkipSignatureVerification"` [observed].

The IIoT extension (`CODESYS.C4.IIoTLibraries.Ext/1.13.1`) contains AWS IoT Core Client SL, Azure IoT Hub
Client SL, CSV Utility SL, INI File Utility SL, JSON Utilities SL, JSON Web Token SL, MQTT Client SL (1.13.0),
Mail Service SL, Memory Block Manager, OpenWeather Client SL, SMS Service SL, SNMP Service SL, SNTP Service SL,
String Util Intern, Web Client SL, Web Socket Client SL and XML Utility SL [tested]. Most of these are licensed
products; see `docs/06` for what that means for MQTT Client SL.

## Users, groups, root

| Fact | Status |
|---|---|
| `c4-server` refuses root: `Cannot run with administrative privileges (root / Administrator).` | [tested] |
| `c4-cli version` / `--help` run as root without complaint | [tested] |
| Builds (`library install`, `bootapp compile`) were only ever run as a non-root user in group `codesys-4` (`dev`); running them as root was not tried | [unverified] |
| Per-user state lives in `~/.config/CODESYS-4/` (`LibraryRepositories.prefs.json`, `logs/`) | [tested] |

```bash
sudo useradd -m -s /bin/bash dev
sudo usermod -aG codesys-4 dev          # `id dev` -> groups=...,1001(codesys-4)   [tested]
sudo passwd dev                          # the web login uses this Linux password   [observed]
```

Right after installing, fix the library repository path for that user. The default is relative and breaks
library resolution; see `docs/05` step 0 and `docs/08`. [tested]

## Server mode (`c4-server`): the browser IDE for several users

```text
c4-server [OPTIONS] [COMMAND]
  --port             default 8080, or env C4_PORT
  --login-groups     comma-separated groups allowed to log in, default 'codesys-4'
  --session-timeout  seconds, default 300, minimum 120; disconnected sessions are cleaned up after this
  --log-level        default 'information'
  commands: version, about, standalone-session, library, librepo, bootapp,
            multisession ("Serve as a proxy server for multi user usage on local host")
```
(from `c4-server --help` [tested]; `c4-server multisession --help` has the same options.)

How it was run on the bench machine, where Jupyter already used port 8080 [tested]:

```bash
su - dev -c 'cd /opt/codesys-4 && nohup c4-server --port 8090 > /home/dev/c4-server.log 2>&1 &'
ss -ltn | grep 8090      # LISTEN on *:8090, all interfaces   [tested]
```

What the server logged at start [tested]:

```text
info: ...MultiSessionProxyServerCommand[0] Container detected: True
info: ...SessionProcessManagerService[0] Group(s) permitted for login: codesys-4
```

- **Log in with a Linux account name and password**, for an account in one of the `--login-groups` [observed].
  An email address as the user name was rejected:
  `System.Security.Authentication.InvalidCredentialException: User <email> not allowed!` (raised in
  `CheckValidUserName`) [observed].
- Each login starts a session process for that user. The frontend logs go to
  `~/.config/CODESYS-4/logs/MultiUserFrontend-<user>-<date>_<time>-<pid>.log.json` [tested].
- The server listens on all interfaces, and we did not check what authentication covers beyond the login
  page. **Do not expose it to the internet.** Reach it through an ssh tunnel:

```bash
ssh -N -L 8090:localhost:8090 user@build-host     # then open http://localhost:8090 locally   [observed]
```

## Standalone session (single user, no login)

`c4-cli standalone-session [open] [--with-browser <exe>] [--default-browser] [-v]` starts a private UI
server on a random localhost port and opens it in "the UI window" [tested help text]. On a headless machine,
pass a fake browser that records the URL [tested]:

```bash
cat > /tmp/fakebrowser.sh <<'EOF'
#!/bin/bash
echo "$@" >> /tmp/c4url.txt
sleep 100000
EOF
chmod 755 /tmp/fakebrowser.sh
su - dev -c 'cd /home/dev/c4work && c4-cli standalone-session --with-browser /tmp/fakebrowser.sh -v'
cat /tmp/c4url.txt   # http://localhost:35969/index.html#<one-time token>
```

- The URL carries a token in the fragment. A second browser that opens the same URL gets
  `Server returned 403 forbidden, session cannot be accessed by external browsers` [observed]. Keep **one**
  browser (for example one Playwright page) alive for the whole session.
- The start page embeds `https://startpagec4.codesys.com/` in an iframe, which needs internet access [tested].
- The first start logged `Created Default repository at CODESYS-4/managed-libraries` and then
  `Error building repositories for <global> System.ArgumentException: Path CODESYS-4/managed-libraries is not fully qualified`
  [tested]. See `docs/08`.
- Logs: `~/.config/CODESYS-4/logs/StandaloneSession-<user>-<date>_<time>-<pid>.log.json` [tested].
- A standalone session keeps running after the browser goes away. On the bench machine, one started at
  17:44 was still running hours later [tested]. Kill it when you are done.

## Online help

The UI start page links the vendor's CODESYS 4 help, for example
`https://content.helpme-codesys.com/en/CODESYS%204/_c4_howto_first_project.html` (create a workspace, create a
device project, add a PLC, add a program, build, communication settings, download) [tested that the link exists;
its content is vendor documentation and was only summarised, so treat details from it as unverified].
