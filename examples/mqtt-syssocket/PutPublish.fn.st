// Write an MQTT 3.1.1 PUBLISH packet (QoS 0) at pBuf[pos]; returns the next position.
FUNCTION PutPublish : DINT
VAR_INPUT
    pBuf : POINTER TO BYTE;
    pos : DINT;
    sTopic : STRING(48);
    sPayload : STRING(230);
    xRetain : BOOL;
END_VAR
VAR
    rem, p, i, lp : DINT;
    pb : POINTER TO BYTE;
    pw, pr : POINTER TO BYTE;
END_VAR

lp := LEN(sPayload);
rem := 2 + LEN(sTopic) + lp;
p := pos;
IF xRetain THEN
    pw := pBuf + p;
    pw^ := 16#31;
ELSE
    pw := pBuf + p;
    pw^ := 16#30;
END_IF
p := p + 1;
REPEAT   // remaining length, 7 bits per byte
    IF rem >= 128 THEN
        pw := pBuf + p;
        pw^ := DINT_TO_BYTE(rem MOD 128) OR 16#80;
    ELSE
        pw := pBuf + p;
        pw^ := DINT_TO_BYTE(rem);
    END_IF
    rem := rem / 128;
    p := p + 1;
UNTIL rem = 0
END_REPEAT
p := PutStr(pBuf, p, sTopic);
pb := ADR(sPayload);
FOR i := 0 TO lp - 1 DO
    pw := pBuf + p + i;
    pr := pb + i;
    pw^ := pr^;
END_FOR
PutPublish := p + lp;

END_FUNCTION
