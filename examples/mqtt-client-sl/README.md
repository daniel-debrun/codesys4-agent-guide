# MQTT with the MQTT Client SL library (licensed; 30-minute demo)

`MqttComm.prg.st` is the bench's first MQTT layer: 8 `MQTTPublish` blocks in parallel draining a queue, and
5 `MQTTSubscribe` blocks. It built and ran a 44-simulated-hour capture (52,661 events, no sequence gaps) on
2026-09-30 [tested]. It is shown with the one rename applied before that build (`GVL_Comm.Retain` →
`GVL_Comm.RetainFlag`, because `RETAIN` is a keyword). It uses the same `GVL_Comm.gvl` as
`../mqtt-syssocket/`, and the bench's `GVL_Safety` for commands.

Library reference (`Libraries.json`):

```json
"MQTT": { "$type": "Placeholder", "placeholder": "MQTT_Client_SL" }
```
added with `c4-cli library install-placeholder MQTT MQTT_Client_SL <app>` [tested].

**Why the bench stopped using it:** without a licence, the runtime logs
`License for MQTTClientSL library not installed. Running for 30 minutes in demo mode.`. Once that time was
used up, publishing stopped about 34 s after every runtime restart, and a restart did not reset it [observed,
twice]. A workflow that restarts the PLC on every deploy cannot live with that. See `docs/06`.
