// A minimal MQTT 3.1.1 client on the runtime's SysSocket API: QoS 0 publishes drained from GVL_Comm's
// queue, and one subscription for the bench's stand-in field inputs (lock-out switches and e-stop):
//   plant/bench/cmd/lockout/<station>  payload 1 | 0
//   plant/bench/cmd/estop              payload 1 | 0
// Why not the MQTT Client SL library: without a licence it runs in 30-minute demo mode, and on this
// runtime it stopped publishing ~34 s after every restart once the demo time was used up.
PROGRAM MqttComm
VAR
    h : POINTER TO BYTE;          // socket handle (RTS_IEC_HANDLE)
    res : UDINT;
    addr : SOCKADDRESS;
    one : DINT := 1;
    connected : BOOL;
    tRetry : TIME;
    tProgress : TIME;
    tx : ARRAY[0..16383] OF BYTE;
    txLen, txOff : DINT;
    rx : ARRAY[0..4095] OF BYTE;
    rxLen : DINT;
    n : __XINT;
    i, k, rem, mult, hdr, tlen, plen : DINT;
    b, cmd : BYTE;
    sTopic : STRING(80);
    pStr, pw : POINTER TO BYTE;
    sClientId : STRING(23) := 'bench-plc';
    sFilter : STRING(48) := 'plant/bench/cmd/#';
END_VAR

IF NOT connected AND TIME() - tRetry >= T#2S THEN
    tRetry := TIME();
    h := SysSockCreate(SOCKET_AF_INET, SOCKET_STREAM, SOCKET_IPPROTO_TCP, ADR(res));
    IF res = 0 THEN
        addr.sin_family := SOCKET_AF_INET;
        addr.sin_port := SysSockHtons(GVL_Comm.BrokerPort);
        SysSockInetAddr(GVL_Comm.BrokerHost, ADR(addr.sin_addr));
        res := SysSockConnect(h, ADR(addr), SIZEOF(addr));
        IF res = 0 THEN
            SysSockIoctl(h, SOCKET_FIONBIO, ADR(one));
            // CONNECT: protocol level 4, clean session, keep-alive 0 (off)
            tx[0] := 16#10;
            tx[1] := INT_TO_BYTE(12 + LEN(sClientId));
            tx[2] := 0; tx[3] := 4; tx[4] := 16#4D; tx[5] := 16#51; tx[6] := 16#54; tx[7] := 16#54;
            tx[8] := 4; tx[9] := 2; tx[10] := 0; tx[11] := 0;
            txLen := PutStr(ADR(tx), 12, sClientId);
            // SUBSCRIBE, packet id 1, QoS 0
            tx[txLen] := 16#82;
            tx[txLen + 1] := INT_TO_BYTE(5 + LEN(sFilter));
            tx[txLen + 2] := 0;
            tx[txLen + 3] := 1;
            txLen := PutStr(ADR(tx), txLen + 4, sFilter);
            tx[txLen] := 0;
            txLen := txLen + 1;
            txOff := 0;
            rxLen := 0;
            tProgress := TIME();
            connected := TRUE;
        ELSE
            SysSockClose(h);
        END_IF
    END_IF
END_IF
GVL_Comm.Connected := connected;
IF NOT connected THEN
    RETURN;
END_IF

// fill the send buffer from the queue
IF txLen = 0 THEN
    WHILE GVL_Comm.Head <> GVL_Comm.Tail AND txLen < 16000 DO
        txLen := PutPublish(ADR(tx), txLen, GVL_Comm.Topic[GVL_Comm.Head], GVL_Comm.Payload[GVL_Comm.Head],
                            GVL_Comm.RetainFlag[GVL_Comm.Head]);
        GVL_Comm.Head := (GVL_Comm.Head + 1) MOD GVL_Comm.QSIZE;
    END_WHILE
END_IF

// send (non-blocking; a partial send continues next scan)
IF txOff < txLen THEN
    n := SysSockSend(h, ADR(tx[txOff]), txLen - txOff, 0, ADR(res));
    IF n > 0 THEN
        txOff := txOff + TO_DINT(n);
        tProgress := TIME();
    END_IF
END_IF
IF txOff >= txLen THEN
    txLen := 0;
    txOff := 0;
    tProgress := TIME();
ELSIF TIME() - tProgress > T#5S THEN   // no progress: drop the connection and start again
    GVL_Comm.PubErrors := GVL_Comm.PubErrors + 1;
    SysSockClose(h);
    connected := FALSE;
    txLen := 0;
    txOff := 0;
    RETURN;
END_IF

// receive and handle complete packets (only PUBLISH matters; CONNACK / SUBACK are skipped)
n := SysSockRecv(h, ADR(rx[rxLen]), 4096 - rxLen, 0, ADR(res));
IF n > 0 THEN
    rxLen := rxLen + TO_DINT(n);
END_IF
WHILE rxLen >= 2 DO
    rem := 0;
    mult := 1;
    i := 1;
    REPEAT
        b := rx[i];
        rem := rem + BYTE_TO_DINT(b AND 16#7F) * mult;
        mult := mult * 128;
        i := i + 1;
    UNTIL (b AND 16#80) = 0 OR i >= rxLen
    END_REPEAT
    IF (b AND 16#80) <> 0 OR i + rem > rxLen THEN
        EXIT;   // incomplete packet
    END_IF
    hdr := i;
    IF (rx[0] AND 16#F0) = 16#30 AND rem >= 2 THEN
        tlen := BYTE_TO_DINT(rx[hdr]) * 256 + BYTE_TO_DINT(rx[hdr + 1]);
        plen := rem - 2 - tlen;
        pStr := ADR(sTopic);
        FOR k := 0 TO MIN(tlen, 80) - 1 DO
            pw := pStr + k;
            pw^ := rx[hdr + 2 + k];
        END_FOR
        pw := pStr + MIN(tlen, 80);
        pw^ := 0;
        IF plen > 0 THEN
            cmd := rx[hdr + 2 + tlen];
            FOR k := 1 TO 4 DO
                IF sTopic = CONCAT('plant/bench/cmd/lockout/', GVL_Line.StName[k]) THEN
                    GVL_Safety.LockoutActive[k] := cmd = 16#31;   // '1'
                END_IF
            END_FOR
            IF sTopic = 'plant/bench/cmd/estop' THEN
                GVL_Safety.EStop := cmd = 16#31;
            END_IF
        END_IF
    END_IF
    k := hdr + rem;
    FOR i := k TO rxLen - 1 DO
        rx[i - k] := rx[i];
    END_FOR
    rxLen := rxLen - k;
END_WHILE
IF rxLen >= 4096 THEN
    rxLen := 0;
END_IF

END_PROGRAM
