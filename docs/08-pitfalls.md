# 08: Pitfalls: error message → cause → fix

Every error the two agents hit on 2026-09-30 (CODESYS 4 1.0.0.0, Control for Linux SL 4.22, Ubuntu 24.04
container). Messages are quoted exactly; `…` marks a cut, `<…>` a substituted value.

## Install, users, IDE

| Message / symptom | Cause | Fix | Status |
|---|---|---|---|
| `Cannot run with administrative privileges (root / Administrator).` | `c4-server` run as root | run it as a user in group `codesys-4`: `su - dev -c 'c4-server --port 8090'` | [tested] |
| `InvalidCredentialException: User <email> not allowed!` in `c4-server.log` | an email address typed as the login name | log in with a **Linux account name** (in a `--login-groups` group) and its password | [observed] |
| Browser: `Server returned 403 forbidden, session cannot be accessed by external browsers` | a second browser opened a standalone-session URL that one browser already owns | keep a single browser or page alive for the session; restart the session for a new URL | [observed] |
| UI: `Parent path must be a directory: '/home/dev/c4work'`, then `Failed to create the project "BenchLine" at path "/home/dev/c4work"` | the Create Device Project path field wants a URL | enter `file:///home/dev/c4work/` | [tested] |
| Port 8080 already in use (Jupyter on the bench machine) | the `c4-server` default is 8080 | `--port 8090` or `C4_PORT=8090` | [tested] |
| apt reports unmet dependencies after installing the runtime .deb | `codesyscontrol` depends on `codemeter \| codemeter-lite` | install CodeMeter, or (dev only) an empty `codemeter-lite` stub package. Avoid `apt --fix-broken install`, which may remove CODESYS | [tested] stub / [observed] warning |
| The runtime is not running after `dpkg -i` in a container | the postinst skips the daemon when `CONTAINER=true`, `/.dockerenv` or `/run/.containerenv` is present | start it by hand (`docs/02`) | [tested] |

## Library resolution

| Message / symptom | Cause | Fix | Status |
|---|---|---|---|
| `Error building repositories for <global> System.ArgumentException: Path CODESYS-4/managed-libraries is not fully qualified (Parameter 'path')` | the default `~/.config/CODESYS-4/LibraryRepositories.prefs.json` holds a relative path; a stray `CODESYS-4/managed-libraries` also appears in the current directory | write an absolute path (`{"localRepositories": {"Default": "/home/dev/CODESYS-4/managed-libraries"}}`) and create the directory | [tested] |
| `Could not resolve the reference for the library with namespace Standard: Placeholder resolution for 'Standard' (defined by extension CODESYS.C4.GlobalLibraries.Ext.) to 'Standard, 3.5.22 (System)': Library not found in repositories.` (also for `_3S_LICENSE` → `3SLicense, 3.5.22 (CODESYS)`) | same as above | same as above | [tested] |
| `Failed to resolve all libraries for the project <…>/Application.iecapp. No Libraries.lock.json will be written.` (CLI, and in the UI as `Library resolution failed: …`) | same as above | same as above | [tested] |
| `Error: Path is outside a project: '/home/dev/'.` | `c4-cli library install` run without a target outside the project | pass the target: `c4-cli library install /abs/Project.fbsdev/Application.iecapp` | [tested] |
| `<…>/Libraries.lock.json does not exist. You must resolve your libraries first.` | `install-managed` on a project whose lock file was deleted | run `c4-cli library install <app>` first, then `install-managed` | [tested] |
| `Unknown type: 'SOCKADDRESS'` (and other SysSocket names) | a managed library reference is qualified-only by default | set `"allowUnqualifiedAccess": true` on the reference in `Libraries.json` (or use `set-managed -u` [unverified]) and install again | [tested] |
| `The device 'CODESYS Control for Linux SL' requires the following libraries which are missing from the Libraries.lock.json: { Placeholder: SM3_Basic, … Optional: True }, { Placeholder: SM3_CNC, … }` | the device lists optional motion libraries that are not installed | nothing to do: the build still succeeds | [tested] |

## CLI behaviour

| Message / symptom | Cause | Fix | Status |
|---|---|---|---|
| `Segmentation fault      c4-cli library install …` (bash), after `Finished processing N libraries.` was already printed | a crash on shutdown in `c4-cli` 1.0.0.0; the work is complete | judge success by the output text and the files; retry the step once | [tested, 4+ times] |
| `Error: Cannot find node (file:///tmp/t1/Bench.fbsdev/App.iecapp^/) in object model (Parameter 'path')` | a hand-made project with the wrong layout (a directory named `App.iecapp`, no `Devices/`, no `ProjectInfo.json`) | start from a generated skeleton (`examples/minimal/`) | [observed] |
| `c4-cli bootapp compile` still running hours after `timeout 100` (same malformed project) | the process hung and did not exit on SIGTERM | `timeout -k 10 <secs> c4-cli …`; afterwards check `pgrep -af '[c]4-cli'` | [observed] |
| Paths in messages split across lines (`…/Libraries.l` / `ock.json`) | the console output wraps at about 80 columns | parse summary lines, and unwrap before extracting paths (`docs/09`) | [tested] |
| Thousands of `Generate code for X...` lines with `-v` | verbose code-generation progress | filter `^[A-Z_0-9.]*\.\.\.$` and `Generate code for` | [tested] |

## Compiler (ST)

| Message | Cause | Fix | Status |
|---|---|---|---|
| `Unexpected token 'sub' found` / `';' expected instead of ':'` | `sub` is reserved | rename (e.g. `subr`) | [tested] |
| `Unexpected token 'dt' found` / `';' expected instead of ':='`, plus a spurious `The code '…;' has no effect` warning | `DT` is a type name | rename (`dtSim`) | [tested] |
| `Unexpected token 's' found` / `';' expected instead of 'STRING'` | `S` is reserved | rename (`sMsg`) | [tested] |
| `'Retain' is no component of 'GVL_Comm'` | `RETAIN` is a keyword; the declaration did not take | rename (`RetainFlag`) | [tested] |
| `Unexpected token '(' found` / `'(pStr + k); ' is no valid statement` | `(ptr + off)^ := x;` is not accepted as a statement | `pw := ptr + off; pw^ := x;` | [tested] |
| `Cannot convert type 'LINT' to type 'DINT'` | adding an `__XINT` result (LINT on x86-64) to a DINT | `TO_DINT(n)` | [tested] |
| `Unknown type: 'RTS_IEC_HANDLE'`, `Unknown type: 'RTS_IEC_RESULT'`, `Identifier 'RTS_INVALID_HANDLE' not defined` | these types are not visible with only `SysSocket 3.5.19` referenced | use `POINTER TO BYTE` for the handle and `UDINT` for results | [tested] |
| `Function 'SysSockIoctl' requires exactly '3' inputs` | an extra `ADR(res)` argument | `SysSockIoctl(h, SOCKET_FIONBIO, ADR(one))` | [tested] |
| `'xFooBar' is no input of 'MQTTCLIENT'` / `Identifier 'xFooBar' not defined` | a wrong input name (a deliberate probe) | use the real names (`docs/06`); probing like this is a quick way to learn an unknown API | [tested] |
| `VAR_IN_OUT 'wsTopicName' must be assigned in call of 'MQTTPublish'` | an in-out parameter was not passed | pass a variable, not `ADR()` | [tested] |
| `String variable 'wsTopic' too short for the VAR_IN_OUT parameter 'wsTopicName' of 'MQTTPublish'` | `WSTRING(255)` is shorter than the parameter | `WSTRING(1024)` | [tested] |
| `Cannot convert type 'Unknown type: 'MQTT.QoS.AtMostOnce'' to type 'MQTT_QOS'` | wrong enum name | `MQTT.MQTT_QOS.QoS0` | [tested] |
| `Identifier 'MQTT.GPL.MAX_TOPIC_LENGTH' not defined` / `String length '…' is no constant value` | guessed constant names that do not exist | a literal length | [tested] |
| `Unknown type: 'NBS.IP_ADDR'`, `'ipAddr' is no input of 'TCP_CONNECTION'`, `'hConnection' is no input of 'TCP_WRITE'` | guessed Net Base Services (placeholder `NetBaseSrv` → `Net Base Services, 5.0.0 (CODESYS)`) names from older versions | not solved. We switched to SysSocket | [tested] |

## Runtime

| Log line / symptom | Cause | Fix | Status |
|---|---|---|---|
| `**** ERROR: CmRuntime could not be connected within 60[s]: iLastError=0` and a ~60 s delay before the app starts | no CodeMeter | wait (poll for your app's output) or install CodeMeter | [tested] |
| `CodeMWriteLicenseFile: CodeMeter access denied`, `CodeMCreateInitialSoftcontainer: Error creating initial empty soft container` | no CodeMeter | harmless for a demo-mode bench | [tested] |
| `USockConnect: No such file or directory /var/opt/codesysproxyapi/proxy.sock`, `Proxy_RemoteCall: connect failed 2`, `socket permissions: connection error to proxy`, `ServerThread: bind failed 2` | the runtime's proxy service is not running (it is not started without systemd) | harmless for the bench; SysSocket TCP clients worked regardless | [tested] |
| `Disabling DMA latency failed: 256` | the container cannot write `/dev/cpu_dma_latency` | harmless for a bench; matters for real-time | [tested] |
| `Not able to read file of Run/Stop switch. Functionality of component disabled` | no run/stop switch file | harmless | [tested] |
| `no runtime license - running in demo mode(~2 hours)` | no runtime licence | restart within 2 h (each deploy restarts it anyway), or license it | [tested] line / [observed] stop |
| `License for MQTTClientSL library not installed. Running for 30 minutes in demo mode.`, then publishing stops about 34 s after each restart | the library's demo time is used up and a restart does not reset it | license it, or use the SysSocket client (`docs/06`) | [tested] line / [observed] behaviour |
| The app does not start after copying files | `Application.1=Application` missing from `[CmpApp]` in `CODESYSControl_User.cfg`, wrong owner, or only `.app` copied | add the line, `chown -R codesyscontrol:codesyscontrol /var/opt/codesys/PlcLogic/Application`, copy both `.app` and `.crc` | [tested] as the working recipe; the failure modes themselves were [unverified] |
| `pkill -f codesyscontrol` over ssh kills the ssh session | the pattern matches the ssh command line itself | `pgrep -f '^/opt/codesys/bin/codesyscontrol.bin'` or `pgrep '[c]odesys…'` | [observed] (a rule the environment notes give) |
| State lost after a deploy (`No retain area in bootproject`) | no retain variables; a deploy restarts the runtime | design for it, or add RETAIN/PERSISTENT variables [unverified] | [tested] |
