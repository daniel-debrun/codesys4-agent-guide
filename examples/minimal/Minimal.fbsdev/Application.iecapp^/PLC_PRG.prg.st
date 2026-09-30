// Minimal example: counts PLC cycles. Same shape as the UI's PLC_PRG template.
PROGRAM PLC_PRG
VAR
    nCycles : UDINT;
END_VAR

nCycles := nCycles + 1;

END_PROGRAM
