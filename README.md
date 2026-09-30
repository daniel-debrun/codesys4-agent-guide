# CODESYS 4 agent guide

Field notes for AI coding agents (and people) who build, deploy and automate PLC programs with
**CODESYS 4** and **CODESYS Control for Linux SL** on Linux. CODESYS 4 v1.0.0.0 came out on 2026-09-24, and
almost none of what follows is documented publicly yet. Everything here comes from two agents that built a
working soft-PLC bench line by trial and error on 2026-09-30, and from read-only checks on the same machine.

**Start with [`AGENTS.md`](AGENTS.md)**. It is the short version.

## Versions covered

| Component | Version seen | Where |
|---|---|---|
| CODESYS 4 (browser IDE, `c4-cli`, `c4-pkm`, `c4-server`) | `1.0.0.0` (`dist/version.json`: `1.0.0.0-v1-0-0-0-12180`, build date 2026-09-23) | `/opt/codesys-4` |
| Compiler / x86-64 code generator | 3.5.22.30 | bundled extensions |
| CODESYS Control for Linux SL (runtime package) | `codesyscontrol` 4.22.0.0 (the runtime logs `<version>3.5.22.30</version>`) | `/opt/codesys`, `/var/opt/codesys`, `/etc/codesyscontrol` |
| OS | Ubuntu 24.04 in an unprivileged Docker container (no systemd, no CodeMeter) | |
| .NET | `aspnetcore-runtime-8.0` 8.0.31 | |

Anything about other versions, Windows, or real hardware is out of scope.

## Status labels

Every claim carries one label. Dates are 2026-09-30 unless stated.

- **[tested]**: seen working (or failing in exactly this way) on CODESYS 4 v1.0.0.0 / runtime 4.22.0.0, in
  the agents' command output or in a read-only check on the machine, more than once or in an end-to-end run.
- **[observed]**: seen once, or reported from a manual install session, and not reproduced.
- **[unverified]**: inferred, read from help text, UI code or vendor online help, or likely but not tried.
  Treat it as a lead, not a fact.

## Contents

| File | What |
|---|---|
| [`AGENTS.md`](AGENTS.md) | The things to know before touching CODESYS 4, and the safe workflow |
| [`docs/01-install-ubuntu.md`](docs/01-install-ubuntu.md) | IDE `.deb`, users and groups, `c4-server`, ports, browser over an ssh tunnel |
| [`docs/02-runtime-control-linux-sl.md`](docs/02-runtime-control-linux-sl.md) | Runtime install (containers, no systemd, no CodeMeter), demo limits, logs, ports, start/stop |
| [`docs/03-project-format.md`](docs/03-project-format.md) | The text-folder project format, file by file, with real examples |
| [`docs/04-c4-cli-reference.md`](docs/04-c4-cli-reference.md) | Every `c4-cli` / `c4-pkm` / `c4-server` subcommand, and what the ones we ran actually did |
| [`docs/05-build-and-deploy.md`](docs/05-build-and-deploy.md) | Source edit to boot application to a running soft PLC to verification |
| [`docs/06-mqtt-from-plc.md`](docs/06-mqtt-from-plc.md) | MQTT Client SL (and its demo limit), and a small SysSocket MQTT client |
| [`docs/07-structured-text-notes.md`](docs/07-structured-text-notes.md) | ST details learned from the compiler |
| [`docs/08-pitfalls.md`](docs/08-pitfalls.md) | Every error we hit: message, cause, fix |
| [`docs/09-automation-and-ci.md`](docs/09-automation-and-ci.md) | Headless builds, parsing output, git diffs, safe automated edits |
| [`examples/`](examples/) | A minimal project folder, the two MQTT clients, and build/deploy scripts |

## Where the knowledge comes from

- A bench project (`BenchLine.fbsdev`: a simulated production line in the PLC scan, publishing MQTT) was
  created once through the web UI driven headlessly, then edited as plain files, built with `c4-cli`,
  deployed as a boot application and run for several 44-simulated-hour captures (52,661 and 57,952 events,
  no sequence gaps).
- A write-back path that edits one GVL, rebuilds, redeploys and reads the values back ran three times end to
  end (125 s, 111 s, and one manual deploy).
- Help texts for every CLI subcommand were collected on the machine on 2026-09-30.

The bench project lives in a separate repository; the files quoted here are copied from it.

## Disclaimer

This is an unofficial, independent write-up. It is not affiliated with, endorsed by, or supported by CODESYS
Group or CODESYS GmbH. CODESYS is a registered trademark of CODESYS Development GmbH; other names and
trademarks belong to their owners. Nothing here is safety guidance: the bench had no certified safety logic,
ran in demo mode, and never controlled real equipment. Check the vendor's documentation and licence terms
before relying on any of this.
