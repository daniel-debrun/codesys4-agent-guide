// MQTT client (MQTT Client SL library): drains GVL_Comm's queue with 8 parallel publishers and
// subscribes to the bench's stand-in field inputs (lock-out switches and e-stop):
//   plant/bench/cmd/lockout/<station>  payload 1 | 0
//   plant/bench/cmd/estop              payload 1 | 0
PROGRAM MqttComm
VAR
    client : MQTT.MQTTClient;
    pub : ARRAY[1..8] OF MQTT.MQTTPublish;
    pubTopic : ARRAY[1..8] OF WSTRING(1024);
    pubData : ARRAY[1..8] OF STRING(230);
    pubRetain : ARRAY[1..8] OF BOOL;
    pubGo : ARRAY[1..8] OF BOOL;
    subs : ARRAY[1..5] OF MQTT.MQTTSubscribe;
    subTopic : ARRAY[1..5] OF WSTRING(1024) := ["plant/bench/cmd/lockout/stamp",
        "plant/bench/cmd/lockout/weld", "plant/bench/cmd/lockout/inspect",
        "plant/bench/cmd/lockout/assembly", "plant/bench/cmd/estop"];
    rx : ARRAY[1..5, 0..15] OF BYTE;
    k : INT;
END_VAR

client(xEnable := TRUE, sHostname := GVL_Comm.BrokerHost, uiPort := GVL_Comm.BrokerPort);
GVL_Comm.Connected := client.xConnectedToBroker;

FOR k := 1 TO 8 DO
    IF pubGo[k] AND (pub[k].xDone OR pub[k].xError) THEN
        IF pub[k].xError THEN
            GVL_Comm.PubErrors := GVL_Comm.PubErrors + 1;
        END_IF
        pubGo[k] := FALSE;
    ELSIF NOT pubGo[k] AND NOT pub[k].xBusy AND GVL_Comm.Connected AND GVL_Comm.Head <> GVL_Comm.Tail THEN
        pubTopic[k] := STRING_TO_WSTRING(GVL_Comm.Topic[GVL_Comm.Head]);
        pubData[k] := GVL_Comm.Payload[GVL_Comm.Head];
        pubRetain[k] := GVL_Comm.RetainFlag[GVL_Comm.Head];
        GVL_Comm.Head := (GVL_Comm.Head + 1) MOD GVL_Comm.QSIZE;
        pubGo[k] := TRUE;
    END_IF
    pub[k](xExecute := pubGo[k], pbPayload := ADR(pubData[k]), udiPayloadSize := INT_TO_UDINT(LEN(pubData[k])),
           eQoS := MQTT.MQTT_QOS.QoS0, xRetain := pubRetain[k], wsTopicName := pubTopic[k], mqttClient := client);
END_FOR

FOR k := 1 TO 5 DO
    subs[k](xEnable := GVL_Comm.Connected, wsTopicFilter := subTopic[k], mqttClient := client,
            pbPayload := ADR(rx[k, 0]), udiMaxPayloadSize := 16);
    IF subs[k].xReceived AND subs[k].udiPayloadSize > 0 THEN
        IF k <= 4 THEN
            GVL_Safety.LockoutActive[k] := rx[k, 0] = 16#31;   // '1'
        ELSE
            GVL_Safety.EStop := rx[k, 0] = 16#31;
        END_IF
    END_IF
END_FOR

END_PROGRAM
