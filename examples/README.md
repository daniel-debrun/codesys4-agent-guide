# examples

| Path | What | Status |
|---|---|---|
| `minimal/` | smallest device project (Control for Linux SL 4.22, one program, one task) | generated skeleton [tested]; this exact folder [unverified], see its README |
| `mqtt-syssocket/` | MQTT 3.1.1 client in ST on SysSocket (QoS 0, no licence) | verbatim from the bench [tested] |
| `mqtt-client-sl/` | the same job with the MQTT Client SL library (30-minute demo without a licence) | from the bench [tested] |
| `scripts/c4-build.sh` | `library install` + `bootapp compile`, success judged from the output, retry on segfault | real commands [tested]; the script was checked against a stub `c4-cli` only |
| `scripts/deploy-bootapp.sh` | back up, stop, copy `.app`/`.crc`, `chown`, start, wait for `Application … started` (root; **restarts the PLC**) | steps [tested]; the script as written [unverified] |
| `scripts/start-softplc.sh` | start the runtime without systemd | verbatim from the bench [tested] |
| `scripts/c4-standalone-url.sh` | start a headless standalone UI session and print its URL | adapted from the bench [tested] |
| `scripts/parse_build_log.py` | turn wrapped compiler output into JSON errors (file, line, column) | checked against the real logs in `scripts/testdata/` |
| `scripts/gvl_edit.py` | change initial values in a GVL, print the diff; refuses `Safety` paths | logic from the bench's write-back, which ran on the PLC [tested] |

The scripts assume the bench's layout: runtime in `/opt/codesys`, data in `/var/opt/codesys`, config in
`/etc/codesyscontrol`, build user `dev` in group `codesys-4`. Read them before you run them.
