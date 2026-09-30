# AGENTS.md: CODESYS 4 quick start for coding agents

CODESYS 4 v1.0.0.0 + CODESYS Control for Linux SL 4.22, Ubuntu 24.04. Labels: [tested] / [observed] /
[unverified] (see README). Details and sources are in `docs/`.

## Know this before you touch anything

1. **Projects are plain text folders.** A device project is `Name.fbsdev/` with `Devices/*.json`,
   `ProjectInfo.json`, `Communication.settings.json`, an `Application.iecapp` file containing `{}`, and the
   application's sources in the sibling folder `Application.iecapp^/` (`*.prg.st`, `*.fn.st`, `*.gvl`,
   `TaskConfiguration.json`, `Libraries.json`, `Libraries.lock.json`). You can edit them with any editor
   and diff them with git. [tested] → `docs/03`
2. **The CLI cannot create a project.** `c4-cli` has no "new project" command [tested], and no project
   templates were found on disk [observed]. Create the skeleton once in the UI, or copy `examples/minimal/`.
   A hand-made folder with a wrong layout fails with
   `Cannot find node (file:///…/App.iecapp^/) in object model`. [observed]
3. **Build = two commands, run as a non-root user in group `codesys-4`:**
   `c4-cli library install <proj>/Application.iecapp`, then
   `c4-cli bootapp compile <proj>/Application.iecapp -v`. Output:
   `<proj>/Application.iecapp^/.bootapp/Application.app` + `Application.crc`. [tested] → `docs/05`
4. **Fix the library repository path once per user before the first build.** The default
   `~/.config/CODESYS-4/LibraryRepositories.prefs.json` holds the relative path `CODESYS-4/managed-libraries`,
   and resolution fails with `Path CODESYS-4/managed-libraries is not fully qualified`. Write an absolute
   path and create that directory. [tested]
5. **Judge success from the output text, not the exit code.** `c4-cli library install` sometimes segfaults
   while exiting *after* finishing its work (bash prints `Segmentation fault`). Look for
   `Finished processing N libraries.` and `BootApp finished`, check that `Build complete -- 0 errors` is
   present and `Application.app` exists, and retry once. [tested]
6. **Put a hard timeout on every `c4-cli` call.** A compile on a malformed project was still running
   more than 2 h later despite `timeout 100`. Use `timeout -k 10 600 …` and check for leftover `c4-cli` processes.
   [observed]
7. **Output is wrapped at about 80 columns**, including file paths in error messages. Match on the summary
   lines, or unwrap before you parse paths. Compiler error positions are `file (line, column, length: n)`,
   with a 1-based line and a 0-based column. [tested]
8. **Deploy without the IDE:** as root, stop `codesyscontrol.bin`, copy `Application.app` and
   `Application.crc` to `/var/opt/codesys/PlcLogic/Application/`, `chown codesyscontrol`, make sure
   `/etc/codesyscontrol/CODESYSControl_User.cfg` has `[CmpApp]` `Application.1=Application`, then start the
   runtime again. [tested] We never used the IDE's online login or download.
9. **Expect about 60 s from runtime start to a running app without CodeMeter.** The log shows
   `CmRuntime could not be connected within 60[s]`, and after that `Application [<app>Application</app>] started`.
   MQTT output resumed 56-62 s after each restart. [tested]
10. **Demo limits.** Without a licence the runtime logs `no runtime license - running in demo mode(~2 hours)`
    [tested], and it stops after about 2 h [observed]. The MQTT Client SL library logs `Running for 30 minutes
    in demo mode`. On the bench it later stopped publishing about 34 s after every restart, and restarting the
    runtime did not reset it [observed, twice]. For long or restart-heavy runs, use the SysSocket MQTT client in
    `examples/mqtt-syssocket/` [tested]. → `docs/06`
11. **No systemd in containers.** The runtime postinst skips the daemon when it detects a container. Start
    it by hand as user `codesyscontrol` from `/var/opt/codesys`:
    `LD_LIBRARY_PATH=/opt/codesys/lib /opt/codesys/bin/codesyscontrol.bin /etc/codesyscontrol/CODESYSControl.cfg`.
    [tested] → `docs/02`
12. **Some short names are reserved words in ST.** `dt`, `s`, `sub` and `Retain` fail as variable names
    (`Unexpected token 's' found`). Rename them to `dtSim`, `sMsg` and so on. [tested]
13. **`(p + i)^ := x;` is rejected as a statement.** Assign the pointer first: `pw := p + i; pw^ := x;`.
    [tested] `__XINT` results (for example from `SysSockSend`) are LINT on x86-64: `txOff := txOff + TO_DINT(n);`.
    [tested]
14. **GVLs are namespaces.** The UI template is `{attribute 'qualified_only'}` / `NAMESPACE X` / `VAR_GLOBAL … END_VAR` /
    `END_NAMESPACE`, and the variables are accessed as `X.Name`. [tested]
15. **Libraries:** find a placeholder or library ID in `/opt/codesys-4/extensions/*/*/c4Placeholders.json`
    and `…/c4Libs/`. Add one with `c4-cli library install-placeholder NS PLACEHOLDER <app>` or
    `install-managed NS "Name, x.y.z (Vendor)" <app>`, after a plain `library install`. Set
    `"allowUnqualifiedAccess": true` by hand when the library's global names must be visible without a prefix
    (SysSocket needs it). [tested]
16. **No symbol configuration was found in 1.0.** [observed] We did not get IEC variables over OPC UA
    (4840 listens [tested]). To read values back, have the PLC publish them (for example as retained MQTT
    topics) and compare them after each deploy. [tested]
17. **Do not run `c4-server` as root.** It refuses (`Cannot run with administrative privileges (root / Administrator).`).
    [tested] `c4-cli version` does run as root [tested]. Builds were only ever run as a non-root user.
18. **The boot app does not keep state across restarts.** The log reports `No retain area in bootproject`, and every
    deploy restarts the runtime, so line state is lost. [tested]

## Safe workflow (the one that worked)

```text
edit source (plain files, git)        → git diff shows exactly what changed
c4-cli library install  (as dev)      → check "Finished processing"
c4-cli bootapp compile  (as dev)      → require "Build complete -- 0 errors" and .bootapp/Application.app
back up /var/opt/codesys/PlcLogic/Application/*
stop runtime → copy .app + .crc → chown → start runtime (as root)
wait ~60-70 s → read back the values the PLC publishes → compare to what you meant to change
on failure: restore the backup and the source, restart
```

Rules we kept, and recommend:
- Build in a scratch copy, not in the source tree. Ignore `.bootapp/`, `.intermediate/`,
  `.compileContexts/`, `.library-cache/` and `Devices/.devDesc-cache/`: a clean copy rebuilds them. [tested]
- Automated edits touch one whitelisted file (a parameter GVL), one declaration per line, and never a
  safety-related POU. Every deploy restarts the PLC, so never deploy to a machine that controls real
  equipment.
- Check a lock-out or permission signal from the running PLC before and right after the build. Treat
  "cannot read" as "not safe". [tested on the bench]

Scripts: `examples/scripts/c4-build.sh`, `examples/scripts/deploy-bootapp.sh`, `examples/scripts/start-softplc.sh`.
