# Minimal device project (CODESYS Control for Linux SL 4.22)

`Minimal.fbsdev/` is the smallest device project we know of: one PLC (`BenchPLC`, type 4102, id `0000 0005`,
version 4.22.0.0), one application, one program in one cyclic task.

```text
Minimal.fbsdev/
├── ProjectInfo.json
├── Communication.settings.json
├── Devices/DeviceTree.json
├── Devices/BenchPLC.device.json
├── Application.iecapp                 (contains {})
└── Application.iecapp^/
    ├── Libraries.json                 (placeholder "Standard")
    ├── TaskConfiguration.json         (DefaultTask, cyclic, calls PLC_PRG)
    └── PLC_PRG.prg.st
```

## Status

- The JSON files and `Application.iecapp` have the same content the v1.0.0.0 UI generated for the bench
  project. `ProjectInfo.json`, `Communication.settings.json`, `Application.iecapp` and `Devices/*` are copies
  of those files. `Libraries.json` and `TaskConfiguration.json` were retyped from a dump of the generated
  files, so their trailing whitespace may differ. With the UI's `PLC_PRG` template, that skeleton built with
  `Build complete -- 0 errors, 0 warnings`, and the boot application loaded and started on the runtime
  [tested].
- Two things differ from what was built, and **this exact folder has not been compiled** [unverified]:
  1. the project folder is named `Minimal.fbsdev` instead of `BenchLine.fbsdev`;
  2. `PLC_PRG` has a counter (`nCycles := nCycles + 1;`) instead of an empty body. Every construct in it
     compiled elsewhere in the bench.
- There is no `Libraries.lock.json`; `c4-cli library install` writes it.

## Build it

As a non-root user in group `codesys-4`, with an absolute library repository path (`docs/05`, step 0):

```bash
cp -r examples/minimal/Minimal.fbsdev /home/dev/work/
../scripts/c4-build.sh /home/dev/work/Minimal.fbsdev
# -> /home/dev/work/Minimal.fbsdev/Application.iecapp^/.bootapp/Application.{app,crc}
```

Expected: `Build complete -- 0 errors, 0 warnings : Ready for download` (the build is named
`Minimal.Application`). The SM3_Basic/SM3_CNC notice before the build is harmless (`docs/08`).

## Deploy it (root, on the runtime host; it replaces whatever application is running)

```bash
../scripts/deploy-bootapp.sh "/home/dev/work/Minimal.fbsdev/Application.iecapp^/.bootapp"
```

## Change the target device

Edit `identification` in both `Devices/DeviceTree.json` and `Devices/BenchPLC.device.json` (the ids are in
`docs/03`). Only Control for Linux SL was tried.
