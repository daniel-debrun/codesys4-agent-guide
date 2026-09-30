# 04: `c4-cli`, `c4-pkm` and `c4-server` reference (v1.0.0.0)

The help texts below were collected on 2026-09-30 by running `--help` on every command and subcommand, as a
user in group `codesys-4` [tested]. They are condensed, not verbatim. The **"What happened when run"** column
records only what the agents actually ran; every other row is help text, so read it as [unverified]
behaviour.

## Behaviour common to all `c4-cli` commands

| Fact | Status |
|---|---|
| `-h/--help` on every command; `-v/--verbose` is short for `--log-level=information`; `--log-level trace\|debug\|information\|warning\|error` (default: nothing is logged); `-d/--dry-run` on commands that write files | [tested help] |
| The examples in the help use Windows paths (`C:/path/to/...`). Linux absolute paths work | [tested] |
| Even without `-v`, the host prints ASP.NET lifetime lines: `Application started. Press Ctrl+C to shut down.`, `Hosting environment: Production`, `Content root path: <cwd>`, `Application is shutting down...`, and `Waiting for background processing to finish.` Filter them out | [tested] |
| Output is wrapped at about 80 columns, and long paths are split across lines (`…/Libraries.l` + `ock.json`) | [tested] |
| A log per run goes to `~/.config/CODESYS-4/logs/CLI-<user>-<yyyymmdd_HHMMSS>-<pid>.log.json` (81 log files after one day of agent work) | [tested] |
| `library install` sometimes segfaults **on exit, after finishing its work** (bash: `Segmentation fault`). The lock file and cache were complete. Retrying works | [tested, 4+ times] |
| Called with no target from a directory outside a project: `Error: Path is outside a project: '/home/dev/'.` | [tested] |
| Exit codes on compile errors or bad arguments were not recorded. Parse the output instead (`docs/09`) | [unverified] |
| A compile of a malformed project hung, and survived `timeout 100` for hours | [observed] |

## `c4-cli` top level

```text
c4-cli [OPTIONS] <COMMAND>
  version               Output version information
  about                 About the application and licenses
  standalone-session    Start a standalone CODESYS 4 session and open the user interface
  library               Work with libraries
  librepo               Manage library repositories and the libraries within
  bootapp               Work with boot applications
```

There is **no command that creates a project, application, device or POU** [tested: the complete list].

### `c4-cli version [-v|--verbose] [--json]`

| Invocation | What happened when run |
|---|---|
| `c4-cli version` | `CODESYS 4 1.0.0.0` (also as root) [tested] |
| `c4-cli version --json` | `{"CODESYS 4":"1.0.0.0"}` [tested] |
| `c4-cli version --verbose` | table of loaded components, including `Code386` 3.5.22.30, `CodeARM` 4.0.4.0, `CodeARM64` 4.0.2.0, `Codex86_64` 3.5.22.30, `RISCFrontend` 4.0.3.0, `C4Compiler` 3.5.22.30, `CODESYS.C4.Ladder.Object` 0.1.0.0, `CODESYS.C4.Modbus.Impl` 0.1.0.0, and the `CODESYS.C4.Modules.*` 1.0.0.0 set (BootApplicationService, Compiler, DryRunFileSystem, OnlineService, WorkspaceManager, …) [tested] |

### `c4-cli about [-v]`
Prints the licence summary; `-v` prints the full licence text of every component. [help only]

### `c4-cli standalone-session [open] [options]`

| Option | Meaning | What happened when run |
|---|---|---|
| `[open]` | workspace or projects to open after start | not used |
| `--with-browser <exe>` | "Use the given custom browser. Useful for testing" | `<exe>` is called with the session URL `http://localhost:<port>/index.html#<token>` as its argument. A shell script that writes `$@` to a file and sleeps made headless driving possible [tested] |
| `--default-browser` | use the system browser instead of the UI window | not used |

See `docs/01` for the one-browser rule (a second browser gets HTTP 403).

### `c4-cli bootapp compile [app-path] [target-path] [-v] [--log-level] [-d]`

"Compile a boot application for offline deployment." `app-path` defaults to the current directory, and
`target-path` defaults to the hidden `.bootapp/` in the application folder.

What happened when run [tested, dozens of runs]:
- `c4-cli bootapp compile /abs/path/Project.fbsdev/Application.iecapp -v`. Passing the path of the
  **`.iecapp` file** works, even though the help says "directory of the application".
- It writes `Project.fbsdev/Application.iecapp^/.bootapp/Application.app` (320,308 bytes for the bench) and
  `Application.crc` (28 bytes).
- A successful run ends like this:
  ```text
  ------ Build started: Application: BenchLine.Application -------
  Typify code...
  Generate code...
  Generate global initializations...
  Generate code initialization...
  Generate relocations...
  Memory area 0 contains  Data, Input, Output, Memory and Nonsafe data: size: 1048576 bytes, highest used address: 739544, ...
  Memory area 3 contains  Code: size: 1048576 bytes, highest used address: 341432, ...
  Build complete -- 0 errors, 0 warnings : Ready for download
  Compilation successful: 00:00:02.3711202
  Writing boot application at /…/Application.iecapp^/.bootapp/Application.app: 00:00:02.3711987
  Code generator: CODESYS.C4.Codex86-64.Ap.Codex86-64.Impl, Version=3.5.22.30 (little endian).
  BootApp finished: 00:00:02.4312635 /…/Application.iecapp^/
  ```
- A failed run ends with `Compile complete -- 41 errors, 2 warnings` (sometimes missing), then
  `Build complete -- 41 errors, 2 warnings : No download possible` and `Compilation failed: 00:00:01.11`.
- Before the build it may print a notice about device libraries that are missing from the lock file:
  `The device 'CODESYS Control for Linux SL' requires the following libraries which are missing from the Libraries.lock.json: { Placeholder: SM3_Basic, … Optional: True }, { Placeholder: SM3_CNC, … Optional: True }. Resolving the libraries of your project fixes this, provided the libraries exist in a reachable repository`.
  Both are `Optional: True`, and the build still succeeded. Ignore it.
- With `-v`, one `Generate code for X...` line is printed per POU, thousands of lines once a large library
  is linked. Filter out lines matching `^[A-Z_0-9.]*\.\.\.$` and `Generate code for`.
- Time: 0.9 s for an empty program, 2-8 s for the bench (about 20 POUs plus libraries) [tested].
- `--dry-run` and `target-path`: [unverified].

## `c4-cli library …`

Targets: most subcommands take `[target-path]`, which is "an application directory, a Libraries.json file or a
Libraries.lock.json file", and defaults to the current directory. Passing `<proj>/Application.iecapp`
worked [tested].

| Subcommand | Purpose (help) | What happened when run |
|---|---|---|
| `install [target]` (alias `i`) | Resolve all libraries of the application and restore missing ones into the library cache | Writes `Libraries.lock.json` and fills `<proj>/.library-cache/`. Ends with `Finished processing 63 libraries.`. Before that it prints one `Library 'X, v (Vendor)' found at '<path>'` line per library, and `Successfully resolved library with namespace …` lines. Takes seconds. Sometimes segfaults on exit after finishing [tested] |
| `install-placeholder <ns> <placeholder> [target]` | Add or replace a placeholder reference in Libraries.json, then install | `install-placeholder MQTT MQTT_Client_SL <app>` added `"MQTT": {"$type":"Placeholder","placeholder":"MQTT_Client_SL"}` and resolved everything [tested] |
| `install-managed <ns> <library> [target]` | Add or replace a managed reference, then install | `install-managed SysSocket "SysSocket, 3.5.19 (System)" <app>` added `{"$type":"ManagedLibrary","libraryId":"SysSocket, 3.5.19 (System)"}`. It failed with `…Libraries.lock.json does not exist. You must resolve your libraries first.` until a plain `install` had run. It has **no** `-u` option, so `allowUnqualifiedAccess` was set by editing the JSON afterwards [tested] |
| `install-relative <ns> <path> [target]` | same for a relative path | not run |
| `set-managed <ns> <library> [target]` | Add or replace a managed reference (no install) | not run. Options: `-u/--allow-unqualified-access`, `-c/--publish-symbols-in-container`, `-o/--optional`, `--no-hash`, `-p/--include-prerelease`, `--link-all-content`, `--default-resolution`, `-d` |
| `set-relative <ns> <path> [target]` | same, path to a (packed) library project or compiled library | not run. Same options as `set-managed` |
| `set-placeholder <ns> <placeholder> [target]` | same, placeholder | not run. Same options as `set-managed` |
| `restore [target] [library-id]` | Restore missing libraries into the cache | not run |
| `clean-install [target]` (alias `ci`) | Verify lock files, remove the library cache, install everything in the lock files. The target may also be a device project directory | not run. Looks like the right command for CI [unverified] |
| `uninstall <ns> [target]` | Remove the library and the dependencies only it used | not run |
| `resolve [target] [ns] [-a/--all]` | Resolve references and write `Libraries.lock.json`; `--all` discards the current lock file | not run |
| `remove <ns> [target]` | Remove a reference from Libraries.json | not run |
| `prune [target]` | Remove unused indirect references from the lock file | not run |
| `outdated [target] [library-id] [-a] [-p]` | Check the repositories for newer versions | not run |
| `list [target] [-a/--all]` | List references (from the lock file) | not run |
| `explain <library> [target] [-p/--show-paths]` | Show why a library is referenced | not run |
| `pack [target] [zip-path]` | Create a source library archive from a `.fbslib` folder | not run |
| `save-compiled <library-path> <dest>` | Save a library as `{LibraryName}.compiled-library-v3`. Options: `--overwrite`, `--compiler-version`, `--set-version`, `--assert-version`, `--compression-level`, `--set-released-flag`, `--set-prerelease-labels`, `--set-buildinfo-labels`, `--assert-prerelease-labels`, `--assert-buildinfo-labels`, `--include-libdoc` | not run |
| `verify [target]` | Check that the lock file still matches Libraries.json, and look for missing cache entries, duplicates, updated packages and orphans | not run. Useful as a CI gate [unverified] |
| `check [library-path] [--pointer-size 32\|64] [--compiler-defines a,b]` | Check a library project (the default pointer size is 32) | not run |

Library IDs have the form `"Name, x.y.z (Vendor)"`, e.g. `"SysSocket, 3.5.19 (System)"` or
`"MQTT Client SL, 1.13.0 (CODESYS)"`. Placeholder names come from each extension's `c4Placeholders.json`
(e.g. `MQTT_Client_SL`, `JSON_Utilities_SL`, `NetBaseSrv` → `Net Base Services, 5.0.0 (CODESYS)`) [tested].

## `c4-cli librepo install <library-repository> <library-paths…>`

"Installs specified libraries into the given library repository." The repository is either a name from the
repository preferences or a path to its root folder (`.` for the current one). Options: `-a/--all` (scan
folders recursively), `--overwrite` or `--skip-existing` (mutually exclusive), `-d`. [help only]

The repository preferences file is `~/.config/CODESYS-4/LibraryRepositories.prefs.json`
(`{"localRepositories": {"Default": "<path>"}}`) [tested]. Its default value is broken; see `docs/08`.

## `c4-pkm` (extension package manager)

```text
c4-pkm install <extension> [-a/--all] [--overwrite] [--create-config-folder (Windows only)] [-d]
c4-pkm remove <Extension.Id[/version]> [-d]
c4-pkm refresh-cache            # rebuild _extensionCache.json
c4-pkm version [-v] [--json] ;  c4-pkm about
```
`install`, `remove` and `refresh-cache` need write access to `/opt/codesys-4` (root) [help]. The package
postinst runs `c4-pkm install --install-all /opt/codesys-4/extensions` from `/opt/codesys-4`, although the
help only documents `-a/--all` [tested: postinst text]. None of these was run by hand.

## `c4-server`

```text
c4-server [--port N | env C4_PORT, default 8080] [--login-groups g1,g2 (default codesys-4)]
          [--session-timeout S (default 300, min 120)] [--log-level L (default information)] [-v]
          [COMMAND]   # version, about, standalone-session, library, librepo, bootapp, multisession
```
- Refuses to run as root [tested].
- `c4-server --port 8090` (no subcommand), run as user `dev`, served the multi-user UI on `*:8090` [tested].
- `c4-server multisession` has the same options ("Serve as a proxy server for multi user usage on local
  host") [help only].
- The `c4-server` binary also offers the `c4-cli` subcommands (`library`, `bootapp` and so on) [help only].
