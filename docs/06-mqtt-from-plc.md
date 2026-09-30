# 06: MQTT from the PLC

Two approaches ran on the bench (CODESYS 4 1.0.0.0, Control for Linux SL 4.22, Mosquitto 2.0.18 on
`127.0.0.1:1883`, anonymous, MQTT 3.1.1):

1. The bundled **MQTT Client SL** library (IIoT Libraries 1.13.1, library 1.13.0). It works, but it is a
   licensed product with a 30-minute demo.
2. A small **MQTT 3.1.1 client written in ST on SysSocket** (about 150 lines, no licence needed). It is what
   the bench uses now.

## 1. MQTT Client SL

### Add the library [tested]

```bash
su - dev -c "c4-cli library install <proj>/Application.iecapp"
su - dev -c "c4-cli library install-placeholder MQTT MQTT_Client_SL <proj>/Application.iecapp"
```
This adds `"MQTT": {"$type": "Placeholder", "placeholder": "MQTT_Client_SL"}` to `Libraries.json` and resolves
63 libraries. It also pulls in Web Socket Client SL.

### API as found by compiling

The compiler's messages were used to find the names: put in a wrong input name, read
`'xFooBar' is no input of 'MQTTCLIENT'`, and so on. Everything below compiled and ran [tested]:

| Block | Inputs used | Outputs used |
|---|---|---|
| `MQTT.MQTTClient` | `xEnable`, `sHostname` (STRING), `uiPort` | `xConnectedToBroker` |
| `MQTT.MQTTPublish` | `xExecute`, `pbPayload := ADR(buf)`, `udiPayloadSize`, `eQoS := MQTT.MQTT_QOS.QoS0`, `xRetain`, `wsTopicName` (**VAR_IN_OUT WSTRING**), `mqttClient := client` (VAR_IN_OUT) | `xDone`, `xError`, `xBusy` |
| `MQTT.MQTTSubscribe` | `xEnable`, `wsTopicFilter` (VAR_IN_OUT WSTRING), `mqttClient`, `pbPayload`, `udiMaxPayloadSize` | `xReceived`, `udiPayloadSize` |

Errors on the way, and what fixed them [tested]:

| Compiler said | Fix |
|---|---|
| `Cannot convert type 'Unknown type: 'MQTT.QoS.AtMostOnce'' to type 'MQTT_QOS'` / `'MQTT CLIENT SL, 1.13.0.0 (CODESYS)' contains no definition for 'QoS'` | use `MQTT.MQTT_QOS.QoS0` |
| `'pwsTopicName' is no input of 'MQTTPUBLISH'` / `VAR_IN_OUT 'wsTopicName' must be assigned in call of 'MQTTPublish'` | pass the WSTRING variable itself: `wsTopicName := wsTopic` |
| `VAR_IN_OUT 'mqttClient' must be assigned in call of 'MQTTSubscribe'` | `mqttClient := client` |
| `String variable 'wsTopic' too short for the VAR_IN_OUT parameter 'wsTopicName' of 'MQTTPublish'` (declared `WSTRING(255)`) | declare `WSTRING(1024)`. 1024 and 65535 both compiled; the exact minimum was not found |
| `Identifier 'MQTT.GPL.MAX_TOPIC_LENGTH' not defined`, `Identifier 'MQTT.MAX_TOPIC_LENGTH' not defined` | those constant names do not exist; use a literal length |

### Minimal publisher that worked [tested]

It was built, deployed, and seen by `mosquitto_sub -t 'plant/#' -v` as `plant/bench/probe {"n":1}`,
`{"n":2}`, … about 56 s after the runtime started:

```iecst
PROGRAM PLC_PRG
VAR
    client : MQTT.MQTTClient;
    pub : MQTT.MQTTPublish;
    wsTopic : WSTRING(1024) := "plant/bench/probe";
    sPayload : STRING(200);
    xGo : BOOL;
    tLast : TIME;
    n : UDINT;
END_VAR

client(xEnable := TRUE, sHostname := '127.0.0.1', uiPort := 1883);
IF client.xConnectedToBroker AND NOT xGo AND TIME() - tLast > T#1S THEN
    tLast := TIME(); n := n + 1;
    sPayload := CONCAT('{"n":', CONCAT(UDINT_TO_STRING(n), '}'));
    xGo := TRUE;
END_IF
pub(xExecute := xGo, pbPayload := ADR(sPayload), udiPayloadSize := INT_TO_UDINT(LEN(sPayload)),
    eQoS := MQTT.MQTT_QOS.QoS0, xRetain := FALSE, wsTopicName := wsTopic, mqttClient := client);
IF pub.xDone OR pub.xError THEN xGo := FALSE; END_IF
END_PROGRAM
```

The production version (8 publishers in parallel, 5 subscriptions, a ring-buffer queue) is in
`examples/mqtt-client-sl/MqttComm.prg.st`. It ran a 44-simulated-hour capture of 52,661 events with no
sequence gaps [tested].

### The demo-licence limit (why the bench moved away from it)

- At every start the runtime logs [tested]:
  ```text
  **** ERROR: License for Web Socket Client SL library not installed. Running for 30 minutes in demo mode.
  **** ERROR: License for MQTTClientSL library not installed. Running for 30 minutes in demo mode.
  ```
- The first 23-minute capture ran to completion. A later capture stopped after 2,553 events. After that,
  every restart of the runtime (and so every deploy) gave the same pattern in the Mosquitto log: the PLC
  client connects, publishes for about **34 s** (first message 61 s after start, last at 95 s), then goes
  silent while the runtime keeps running [observed, twice].
- Restarting the runtime did **not** reset the library's demo period [observed]. We did not find out where
  the used-up state is kept, or whether a machine or container restart resets it [unverified].
- Any workflow that restarts the PLC on every change (all file-based deploys do) cannot rely on this library
  without a licence. With a licence none of this should apply [unverified: no licence was tried].

## 2. MQTT 3.1.1 over SysSocket (no licence)

Files, copied verbatim from the running bench: `examples/mqtt-syssocket/` (`MqttComm.prg.st`, `PutStr.fn.st`,
`PutPublish.fn.st`, `GVL_Comm.gvl`). It is built, deployed, and ran a 44-simulated-hour capture (57,952
events, 0 gaps, 0 dropped, 0 publish errors), plus lock-out commands going back to the PLC [tested].

### Add SysSocket [tested]

```bash
su - dev -c "c4-cli library install <proj>/Application.iecapp"
su - dev -c "c4-cli library install-managed SysSocket 'SysSocket, 3.5.19 (System)' <proj>/Application.iecapp"
# then set "allowUnqualifiedAccess": true on the SysSocket reference in Libraries.json, and install again
```

Without `allowUnqualifiedAccess`, `SOCKADDRESS` was an `Unknown type` [tested].

### SysSocket API facts learned from the compiler [tested]

| Fact | Detail |
|---|---|
| The types `RTS_IEC_HANDLE`, `RTS_IEC_RESULT` and the constant `RTS_INVALID_HANDLE` were **unknown**, even with unqualified access | declare the handle as `POINTER TO BYTE` and results as `UDINT` |
| `SysSockCreate(SOCKET_AF_INET, SOCKET_STREAM, SOCKET_IPPROTO_TCP, ADR(res))` | returns the handle; `res = 0` means OK |
| `SOCKADDRESS` with `.sin_family`, `.sin_port := SysSockHtons(port)`, `.sin_addr` | filled by `SysSockInetAddr(sIp, ADR(addr.sin_addr))` |
| `SysSockConnect(h, ADR(addr), SIZEOF(addr))` | returns 0 on success. It was called in **blocking** mode, before switching to non-blocking, which was fine on localhost |
| `SysSockIoctl` takes **exactly 3** inputs | `SysSockIoctl(h, SOCKET_FIONBIO, ADR(one))` with `one : DINT := 1` makes the socket non-blocking. With 4 inputs: `Function 'SysSockIoctl' requires exactly '3' inputs` |
| `SysSockSend(h, ADR(buf), len, 0, ADR(res))` and `SysSockRecv(…)` return `__XINT` | `__XINT` is LINT on this 64-bit target; `DINT := DINT + n` fails with `Cannot convert type 'LINT' to type 'DINT'`, so use `TO_DINT(n)` |
| `SysSockClose(h)` | |
| Calling these as statements and discarding the result (`SysSockInetAddr(...);`) is allowed | |

### What the client does

- CONNECT: protocol level 4 (3.1.1), clean session, keep-alive 0 (off), client id `bench-plc`. It sends one
  SUBSCRIBE (`plant/bench/cmd/#`, QoS 0) right after CONNECT, in the same send buffer.
- It publishes QoS 0 only (retain flag supported). Messages from a ring-buffer queue in `GVL_Comm` are batched
  into a 16 KB send buffer. Sends are non-blocking; a partial send continues on the next scan.
- Receive: it parses whole packets from a 4 KB buffer and handles only incoming PUBLISH (topic compare, first
  payload byte `'1'`/`'0'`). CONNACK and SUBACK are skipped without checking.
- Reconnect: retries every 2 s while disconnected. If a send makes no progress for 5 s, it closes the socket
  and counts `PubErrors`.
- The task runs every 10 ms, and the program is called once per cycle after the line logic.

Limits, by design: no TLS, no authentication (the CONNECT flags byte is `2`, clean session only), no QoS 1/2,
no keep-alive pings (keep-alive 0 means the broker never times the client out), payloads up to `STRING(230)`,
topics up to `STRING(48)` (queue) or `STRING(80)` (received). It is fine for a bench on localhost. For
anything real, use a licensed library or add TLS, authentication and keep-alive yourself.

### Tell a live publisher from stale data

- Publish a heartbeat (the bench sends one every 5 s with a sequence number, the queue level, dropped
  messages and publish errors). Number every event so that gaps show message loss.
- Put a build tag in retained status payloads, so a reader can tell the new program's values from the old
  program's retained ones (`docs/05` step 10).

### JSON number formatting

`LREAL_TO_STRING` gives `120.0`, `5.0e-2` (for 0.05) and `9.95e-1` (for 0.995) [tested]. These are valid
JSON numbers, and Python's `json` parses them, but they are not what a person expects to read. Use
`LINT_TO_STRING(LREAL_TO_LINT(x * 1000.0))` for fixed-point values such as milliseconds [tested].
