# 07: Structured Text notes (CODESYS 4 1.0.0.0 compiler 3.5.22.30, x86-64 target)

What the compiler accepted and rejected while the bench project (about 20 POUs, 1,700 lines) was written.
The dialect is CODESYS V3 ST with namespaces. Anything not listed here was not tried.

## Languages

- We wrote **ST only**. The UI bundle mentions only `"ST"` and `"LD"` as implementation languages, and a
  Ladder extension (`CODESYS.C4.Ladder.Ext`, component 0.1.0.0) is installed [observed]. The claim that v1.0
  supports exactly ST and LD, and nothing like FBD, SFC, CFC or IL, is [unverified].
- A non-ST body is stored in the same file between `__BEGIN_IMPLEMENTATION('LD')` and `__END_IMPLEMENTATION`
  [observed in UI code only].

## Reserved words that bite as identifiers [tested]

| Declared name | Compiler said | Why | Used instead |
|---|---|---|---|
| `sub : MQTT.MQTTSubscribe;` | `Unexpected token 'sub' found` / `';' expected instead of ':'` | `SUB` is reserved | `subr` |
| `dt : LREAL;` | `Unexpected token 'dt' found` / `';' expected instead of ':='` | `DT` (DATE_AND_TIME) | `dtSim` |
| `s : STRING(230);` | `Unexpected token 's' found` / `';' expected instead of ':'` | `S` is reserved (the set operator) | `sMsg`, `sIp` |
| `Retain : ARRAY[...] OF BOOL;` in a GVL | `'Retain' is no component of 'GVL_Comm'` at the use site | `RETAIN` keyword | `RetainFlag` |

Identifiers are case-insensitive, so `S`, `s`, `DT` and `dt` all clash. Other one-letter names (`n`, `i`,
`k`, `b`, `h`, `p`, `t`) compiled fine [tested]. We would expect `R` (the reset operator) to clash like `S`,
but did not try it [unverified]. One bad declaration can cause dozens of follow-on errors (41 in one build).
Fix the first error and rebuild.

## Pointers [tested]

```iecst
(pBuf + pos)^ := 16#30;          // REJECTED: Unexpected token '(' found / '(pStr + k);' is no valid statement
pw := pBuf + pos;                // OK: assign the address first
pw^ := 16#30;                    // OK
pr := pb + i;  pw^ := pr^;       // OK (the bench also rewrote reads this way; a direct (pb + i)^ read was not tested)
```
`ADR(x)`, `SIZEOF(x)`, `POINTER TO BYTE` arithmetic with DINT offsets, and `ADR(tx[txOff])` (the address of
an array element) all work [tested].

## Integer widths [tested]

- `__XINT` (the pointer-sized integer that SysSocket functions return) is LINT on this target.
  `txOff := txOff + n;` with `txOff : DINT` gives `Cannot convert type 'LINT' to type 'DINT'`, so write
  `TO_DINT(n)`.
- Explicit conversions that compiled: `INT_TO_UDINT`, `INT_TO_LREAL`, `INT_TO_BYTE`, `DINT_TO_BYTE`,
  `BYTE_TO_DINT`, `UDINT_TO_LREAL`, `TIME_TO_LREAL`, `LREAL_TO_LINT`, and the generic `TO_DINT`.
- The `*_TO_STRING` functions that compiled: `UDINT_TO_STRING`, `INT_TO_STRING`, `LINT_TO_STRING`,
  `LREAL_TO_STRING`. `LREAL_TO_STRING` prints `5.0e-2` for 0.05 (`docs/06`).

## Strings [tested]

- `STRING` literals use single quotes (`'127.0.0.1'`). `WSTRING` literals use double quotes
  (`"plant/bench/probe"`), including in array initialisers: `ARRAY[1..5] OF WSTRING(1024) := ["a", "b", …]`.
- Inside a STRING literal, `"` needs no escape: `'{"n":'` works. A single quote inside a STRING literal
  would be written `$'` (IEC escape) [unverified: no such literal was built].
- `CONCAT(a, b)` takes two arguments; nest it for more. `LEN`, `STRING_TO_WSTRING` and `=` comparison of
  strings all work.
- `STRING(n)` sets the capacity. The bench used up to `STRING(255)` for function inputs and `STRING(230)`
  for payloads. A `VAR_IN_OUT` WSTRING parameter must be declared at least as long as the callee's
  declaration (`String variable 'wsTopic' too short for the VAR_IN_OUT parameter …`).

## Declarations and POUs [tested]

- Comment lines (`// …`) before `PROGRAM`/`FUNCTION` at the top of a file are fine.
- `VAR_GLOBAL CONSTANT` inside a `NAMESPACE` GVL is usable as an array bound and in expressions
  (`GVL_Comm.QSIZE`).
- Array initialisers with repetition: `ARRAY[1..4] OF BOOL := [4(TRUE)]`. Multi-dimensional arrays:
  `ARRAY[1..3, 0..31] OF UDINT`.
- Multiple names per line: `u1, u2, z, s2 : LREAL;`.
- A FUNCTION without inputs still needed an (empty) `VAR_INPUT` / `END_VAR` block the way the bench wrote it,
  and was called as `QueueLevel()`. Whether the empty block is required is [unverified].
- A FUNCTION with `VAR_IN_OUT State : UDINT;` accepts an array element as the argument
  (`Rng_Uniform(GVL_Line.RngCt[i])`).
- A call used as a statement with its result discarded is accepted (`LoadParams();`, `Emit(...);`,
  `SysSockClose(h);`).
- Function blocks are called with named inputs, and their outputs are read as `fb.xDone`. Arrays of
  function blocks work (`pub : ARRAY[1..8] OF MQTT.MQTTPublish; pub[k](xExecute := …)`).
- `RETURN` inside functions and programs; `EXIT` and `CONTINUE` inside loops; `FOR i := 4 TO 1 BY -1`;
  `REPEAT … UNTIL … END_REPEAT`; `WHILE`; `CASE … OF` with integer labels; `ELSIF`.
- Standard functions used: `MAX`, `MIN`, `LIMIT`, `MOD`, `SHL`, `SHR`, `XOR` (on UDINT), `LN`, `EXP`, `SQRT`,
  `COS`, `TIME()` (current time as TIME), and `T#1S`-style literals and `TIME` arithmetic
  (`TIME() - tLast > T#1S`). Hex literals: `16#80`.
- GVL access is always qualified: `GVL_Params.WeldCycle_ms` (the UI template puts
  `{attribute 'qualified_only'}` on each GVL namespace).
- Library namespaces: `MQTT.MQTTClient`, where `MQTT` is the key in `Libraries.json`. With
  `"allowUnqualifiedAccess": true`, names are used bare (`SysSockCreate`, `SOCKADDRESS`).

## Warnings seen

- `The code 'GVL_Params.SimSpeed; ' has no effect. Is this the intent?` came from a parse error one line
  later (the `dt` clash). Warnings can be side effects of errors [tested].

## Retain and persistence

The bench declared no `RETAIN`/`PERSISTENT` variables. The runtime logs `No retain area in bootproject`, and
all state restarts from the initial values on every deploy [tested]. The runtime config has
`Bootproject.RetainMismatch.Init=0` and a commented-out `RetainType.Applications=InSRAM`; retain behaviour
was not explored [unverified].
