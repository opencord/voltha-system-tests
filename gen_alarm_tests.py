ALARMS="""LossOfKeySyncFailure
LossOfOmciChannel
LossOfPloam
LossOfSignal
PonLossOfSignal
ProcessingError
SignalDegrade
SignalsFailure
StartupFailure
TransmissionInterference"""

ALARMS = ALARMS.split("\n")

NAME_MAP = {"LossOfKeySyncFailure": "LossOfKeySync",
            "PonLossOfSignal": "LossOfSignal",
            "SignalsFailure": "SignalsFail"}
SUB_MAP = {"LossOfOmciChannel": "${EMPTY}",
           "SignalDegrade": "${EMPTY}",
           "SignalsFailure": "${EMPTY}",
           "PonLossOfSignal": "OLT"}
DEV_MAP = {"PonLossOfSignal": "OLT"}

def GenRaise(alarm, snip, spaced, sub, dev):
    templ="""Test RaiseLossOfFrameAlarm
    [Documentation]    Raise Loss Of Frame Alarm and verify event received
    [Tags]    active
    ${header}    ${deviceEvent}    Raise Alarm And Get Event    LossOfFrame
    ...     ${onu_sn}    ONU_LOSS_OF_FRAME_RAISE_EVENT
    Verify Header   ${header}    Voltha.openolt.ONU_LOSS_OF_FRAME\\.(\\\\d+)    SUB
    Should Be Equal    ${deviceEvent}[deviceEventName]    ONU_LOSS_OF_FRAME_RAISE_EVENT
    Should Be Equal    ${deviceEvent}[resourceId]    ${parent_id}
"""
    return templ.replace("LossOfFrame", alarm).replace("LOSS_OF_FRAME", snip).replace("Loss Of Frame", spaced).replace("SUB", sub).replace("ONU_", dev+"_")

def GenClear(alarm, snip, spaced, sub, dev):
    raiseStr = GenRaise(alarm, snip, spaced, sub, dev)
    return raiseStr.replace("Raise", "Clear").replace("RAISE", "CLEAR")

for alarm in ALARMS:
    alarm1 = NAME_MAP.get(alarm, alarm)
    sub = SUB_MAP.get(alarm, "ONU")
    dev = DEV_MAP.get(alarm, "ONU")
    snip = ""
    spaced = ""
    first = True
    for ch in alarm1:
        if ch.isupper() and not first:
            snip = snip + "_"
            spaced = spaced + " "
        first = False
        snip = snip + ch.upper()
        spaced = spaced + ch

    print GenRaise(alarm, snip, spaced, sub, dev)
    print GenClear(alarm, snip, spaced, sub, dev)

