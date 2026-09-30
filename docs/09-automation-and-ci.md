# 09: Driving CODESYS 4 from scripts and CI

CODESYS 4 1.0 can be driven without a person at the UI: sources are text, and `c4-cli` builds boot
applications. This page covers what held up when an agent built, deployed and verified changes in a loop
on 2026-09-30, and what to watch for.

## What can be headless, and what cannot

| Task | Headless? | How | Status |
|---|---|---|---|
| Create a device project or application | **no CLI** | UI once (Playwright on `standalone-session --with-browser`), or copy a skeleton | [tested] |
| Add or remove POUs, GVLs, folders | yes | create or delete files under `Application.iecapp^/` | [tested] |
| Change task configuration | yes | edit `TaskConfiguration.json` | [tested] |
| Add a library reference | yes | `c4-cli library install-placeholder/install-managed`, or edit `Libraries.json` then `library install` | [tested] |
| Compile | yes | `c4-cli bootapp compile` | [tested] |
| Deploy to a local runtime | yes, as root on the runtime host | copy `.app` + `.crc`, restart (`docs/05`) | [tested] |
| Deploy to a remote runtime | not tried | copy the files over ssh and restart it there [unverified]; IDE online download [unverified] |
| Read variables from the running PLC | no built-in way found | have the program publish them (MQTT) | [tested] |
| Unit-test ST code | not tried | — | [unverified] |

## A CI job that builds a project

```bash
set -euo pipefail
PROJ=$PWD/plc/MyLine.fbsdev
APP=$PROJ/Application.iecapp
# runner: a non-root user in group codesys-4, with an absolute library repository path (docs/05 step 0)
timeout -k 10 600 c4-cli library install "$APP" -v 2>&1 | tee install.log || true   # may segfault on exit
grep -q 'Finished processing' install.log || timeout -k 10 600 c4-cli library install "$APP" -v 2>&1 | tee -a install.log
timeout -k 10 600 c4-cli bootapp compile "$APP" -v 2>&1 | tee build.log || true
python3 examples/scripts/parse_build_log.py build.log      # exit 1 unless "Build complete -- 0 errors"
test -f "$PROJ/Application.iecapp^/.bootapp/Application.app"
```

This is the same logic as `examples/scripts/c4-build.sh`, and as the `plc.py` build step, which ran many
times [tested logic]. Also worth trying in CI: `c4-cli library verify <app>`, which checks that the lock file
matches `Libraries.json` and the cache, and `c4-cli library clean-install <proj>` [unverified; help text only].

### Parsing the output

- The compiler prints two lines per problem: `<message> ` (with a trailing space), then
  `<file> (<line>, <column>, length: <n>)`. The line is 1-based and the column 0-based. Both are wrapped at
  80 columns, and long paths are split mid-word [tested].
- `examples/scripts/parse_build_log.py` joins wrapped lines and returns `{ok, summary, errors[], bootapp_written}`.
  It was tested against four real logs in `examples/scripts/testdata/` (14, 2 and 1 errors, and one success;
  every error was found).
- The per-run JSON log `~/.config/CODESYS-4/logs/CLI-*.log.json` contains only host lifecycle lines
  (`Application started…`, `Content root path…`) and some library-repository errors. **It does not contain
  compiler messages** [tested]. Capture stdout and stderr yourself.
- Success signals: `Finished processing N libraries.` (install), the last
  `Build complete -- 0 errors, … : Ready for download`, `BootApp finished` (compile), and the `.app` file.
  Do not rely on the exit status: a segfault on exit after success happens, and the exit status on compile
  errors was never recorded [tested / unverified].

## Git and diffs

- Commit: `*.json` (device, tasks, `Libraries.json`, `Libraries.lock.json`, `ProjectInfo.json`,
  `Communication.settings.json`), `Application.iecapp`, and all `*.st` and `*.gvl` files.
- Ignore: `.bootapp/ .intermediate/ .compileContexts/ .library-cache/ .devDesc-cache/ CODESYS-4/`. A clean
  checkout builds without them [tested].
- A parameter change is a one-line diff that anyone can review [tested]:
  ```diff
  --- a/BenchLine.fbsdev/Application.iecapp^/GVL_Params.gvl
  +++ b/BenchLine.fbsdev/Application.iecapp^/GVL_Params.gvl
  @@ -20,7 +20,7 @@
       Buf1Capacity : INT := 4;
   
       // st20_weld with robot pool r_weld (robots split one fixture)
  -    WeldCycle_ms : LREAL := 55000.0;
  +    WeldCycle_ms : LREAL := 49500.0;
       WeldCv : LREAL := 0.10;
  ```
- `Libraries.lock.json` changes a lot whenever libraries change (hundreds of lines). Review `Libraries.json`,
  and treat the lock diff as generated.
- The JSON files use **tabs** (as the UI writes them), except the generated `Libraries.json`, which uses 4
  spaces and a stray trailing space. Keep the existing style to avoid noisy diffs [tested: file contents].

## Keeping automated edits safe

These rules were enforced in code on the bench, and each has a unit test. The live refusals marked
[tested] happened on the real PLC:

1. **Whitelist the target.** Edit one parameter GVL only, with one declaration per line. Refuse any path that
   contains `Safety`, and any variable not declared in that file. Rejecting "any GVL except the parameter
   file" keeps logic changes out of an automatic path.
2. **Change values, not structure.** Replace only the initial value of an existing declaration, and check the
   type (integer vs real vs string). `examples/scripts/gvl_edit.py` refuses anything else. Changes to logic go
   through human review.
3. **Require a named approver** and record every step (refused, planned, built, deployed, verified,
   rolled back, applied) in an append-only log. [tested: a wrong approver was refused live]
4. **Check interlocks from the running program, live.** The bench refused while a lock-out was active on the
   PLC [tested live]. It ignores retained MQTT messages, so a stopped PLC cannot look safe, and it checks
   again right before the deploy, after the build.
5. **Build in a scratch copy.** Back up the running boot application, verify by read-back with a build
   tag, and restore the source and the old program on any failure.
6. **Every deploy restarts the PLC** (a stop and start, then about 60 s until the app runs). Outputs go to
   their initial values and state is lost. The bench accepted that because it was a simulation. On real
   equipment this is a machine stop, and it falls under the plant's change and safety procedures. No tool here
   should deploy to equipment that moves.
7. **Do not trust the retained values of the previous program.** Include a build or change id in the values
   the PLC reports back.

## Handy one-liners (bench machine, root)

```bash
pgrep -af '[c]odesyscontrol.bin'                                      # is the runtime up?
grep -n 'Application \[<app>' /var/opt/codesys/codesyscontrol.log | tail -3   # did the app start?
ss -ltnup | grep -E ':(11740|1740|4840)\b'                            # runtime ports
pgrep -af '[c]4-cli'                                                  # leftover CLI processes?
ls -t ~dev/.config/CODESYS-4/logs | head                              # newest CLI/session logs
```
