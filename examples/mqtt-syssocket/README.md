# MQTT 3.1.1 client on SysSocket (no licence needed)

These files are verbatim copies from the bench project that ran on CODESYS 4 1.0.0.0 with Control for
Linux SL 4.22 on 2026-09-30. They built with 0 errors and ran a 44-simulated-hour capture (57,952 events,
0 sequence gaps, 0 dropped, 0 publish errors). Lock-out commands also reached the PLC through the
subscription [tested]. See `docs/06` for the design and its limits: QoS 0, no TLS, no auth, no keep-alive.

| File | Role |
|---|---|
| `GVL_Comm.gvl` | ring-buffer queue (`Topic[]`, `Payload[]`, `RetainFlag[]`, `Head`, `Tail`), broker host/port, counters |
| `Emit.fn.st` | queue one message (returns FALSE and counts `Dropped` when the queue is full) |
| `PutStr.fn.st` | write an MQTT length-prefixed string into a byte buffer |
| `PutPublish.fn.st` | write a QoS 0 PUBLISH packet into a byte buffer |
| `MqttComm.prg.st` | connect, subscribe, send the queue (non-blocking), receive and act on commands |

## To reuse

1. Copy the files into your `Application.iecapp^/` (any sub-folder).
2. Add SysSocket and make it unqualified (`docs/06`):
   `c4-cli library install <app>`, then
   `c4-cli library install-managed SysSocket 'SysSocket, 3.5.19 (System)' <app>`, then set
   `"allowUnqualifiedAccess": true` on that reference in `Libraries.json`, then run `c4-cli library install <app>`
   again.
3. Add `MqttComm` to a cyclic task's `calls` in `TaskConfiguration.json` (the bench used a 10 ms task).
4. **Edit the receive section.** `MqttComm.prg.st` refers to the bench's `GVL_Line.StName[k]` and
   `GVL_Safety.LockoutActive[k]` / `GVL_Safety.EStop`, and subscribes to `plant/bench/cmd/#`. Replace those
   lines with your own command handling, or delete them. As copied, the program does not compile without the
   bench's other GVLs [tested as part of the bench; standalone use is untested].
5. Publish from anywhere with `Emit('my/topic', 'payload', FALSE);`.
