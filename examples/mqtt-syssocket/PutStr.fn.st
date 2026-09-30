// Write an MQTT UTF-8 string (2-byte length + bytes) at pBuf[pos]; returns the next position.
FUNCTION PutStr : DINT
VAR_INPUT
    pBuf : POINTER TO BYTE;
    pos : DINT;
    sText : STRING(255);
END_VAR
VAR
    n, i : DINT;
    pb : POINTER TO BYTE;
    pw, pr : POINTER TO BYTE;
END_VAR

n := LEN(sText);
pw := pBuf + pos;
pw^ := DINT_TO_BYTE(n / 256);
pw := pBuf + pos + 1;
pw^ := DINT_TO_BYTE(n MOD 256);
pb := ADR(sText);
FOR i := 0 TO n - 1 DO
    pw := pBuf + pos + 2 + i;
    pr := pb + i;
    pw^ := pr^;
END_FOR
PutStr := pos + 2 + n;

END_FUNCTION
