// Queue one MQTT message. FALSE (and Dropped + 1) when the queue is full.
FUNCTION Emit : BOOL
VAR_INPUT
    sTopic : STRING(48);
    sPayload : STRING(230);
    xRetain : BOOL;
END_VAR
VAR
    next : INT;
END_VAR

next := (GVL_Comm.Tail + 1) MOD GVL_Comm.QSIZE;
IF next = GVL_Comm.Head THEN
    GVL_Comm.Dropped := GVL_Comm.Dropped + 1;
    RETURN;
END_IF
GVL_Comm.Topic[GVL_Comm.Tail] := sTopic;
GVL_Comm.Payload[GVL_Comm.Tail] := sPayload;
GVL_Comm.RetainFlag[GVL_Comm.Tail] := xRetain;
GVL_Comm.Tail := next;
Emit := TRUE;

END_FUNCTION
