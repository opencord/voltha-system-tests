*** Settings ***
Suite Setup       Get IP AND PORT
Library           Process
Library           OperatingSystem
Library           BuiltIn
Library           String
Library           Collections
Variables         ../../variables/variables.robot

*** Test Cases ***
Clear Subscribed Events
    [Documentation]    This test case excercises the API, ClearCurrentEventList, which clears all Redfish evets currently subscribed to.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/clear_all_subscribed_events.expected
    ${OUTPUT}=    Run Process    tests/clear_all_subscribed_events.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

Configure Data Polling Interval
    [Documentation]    This test case excercises the API, SetFrequency, which configures the interval of data polling.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/configure_data_polling_interval.expected
    ${OUTPUT}=    Run Process    tests/configure_data_polling_interval.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

List Subscribed Events
    [Documentation]    This test case excercises the API, GetCurrentEventList, which lists all Redfish evets currently subscribed to.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/list_subscribed_events.expected
    ${OUTPUT}=    Run Process    tests/list_subscribed_events.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

List Supported Events
    [Documentation]    This test case excercises the API, GetEventList, which lists all supported Redfish events.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/list_supported_events.expected
    ${OUTPUT}=    Run Process    tests/list_supported_events.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

Subscribe Events
    [Documentation]    This test case excercises the API, SubscribeGivenEvents, which subscribes to the specified events.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/subscribe_events.expected
    ${OUTPUT}=    Run Process    tests/subscribe_events.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

Unsubscribe Events
    [Documentation]    This test case excercises the API, UnsubscribeGivenEvents, which unsubscribes to the specified events.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/unsubscribe_events.expected
    ${OUTPUT}=    Run Process    tests/unsubscribe_events.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

Validate IP
    [Documentation]    This test case validates the format of IP, whcih is expected to be in the form of <ip>:<port>.
    ${EXPECTED}=    RUN    sed -e '/^\\/\\//d' -e 's/ip1/${IP1}/g' -e 's/port1/${PORT1}/g' tests/validate_ip.expected
    ${OUTPUT}=    Run Process    tests/validate_ip.tc    ${IP1}    ${PORT1}
    Should Be Equal    ${EXPECTED}    ${OUTPUT.stdout}

*** Keywords ***
Setup Suite
    [Documentation]    Set up the test suite
    Common Test Suite Setup

Get IP AND PORT
    [Documentation]    Obtain the ip and port of Redfish devices from ONF voltha-system-tests
    @{ADDR_LIST}      ${olt_ip}:${OLT_PORT}
    Sort List    ${ADDR_LIST}
    ${I1}=    Fetch From LEFT    ${ADDR_LIST}[0]    :
    Set Suite Variable    ${IP1}     ${I1}
    ${P1}=    Fetch From Right    ${ADDR_LIST}[0]    :
    Set Suite Variable    ${PORT1}    ${P1}
