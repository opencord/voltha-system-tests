# Copyright 2022-2023 Open Networking Foundation (ONF) and the ONF Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem
Library           XML
Resource          ./k8s.robot

*** Variables ***

*** Keywords ***

Get BBF Device Aggregation
    [Documentation]     Extract, running an except script, the XML that
    ...     represent all the Network viewed by the BBF-Adapter and
    ...     copy it to the ${XMLDestPath}.
    [Arguments]     ${namespace}    ${XMLDestPath}      ${pathToScript}

    #Remove the previus XML (extract by previus tests)
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    rm ${XMLDestPath}
    #Retrive the Name of the BBF-Adapter Pod
    ${rc}    ${exec_pod_name}=    Run and Return Rc and Output
    ...    kubectl get pods -n ${namespace} -l app=bbf-adapter --no-headers | awk 'NR==1{print $1}'
    #Execute the script that access with SSH to the BBF-Adapter Pod
    #Run the netopeer2-cli, set up it, and ask to the device-aggregation XML
    ${rc}   ${output}=      Run and Return Rc and Output
    ...     expect ${pathToScript}/bbf_device_aggregation.exp ${exec_pod_name}
    Log     ${output}
    #Verify if there are some error of connectivity with the Adapter Pod
    ${expect}=      Get Length      ${output}
    Run Keyword If    ${expect} <= 100
    ...    Fail    Impossible to Reach the BBF-Adapter Pod (port-forward/key-exchange?)
    #Copy From the Pod to the ${XMLDestPath} the XML file
    Copy File From Pod      ${namespace}    app=bbf-adapter     home/voltha/output.xml     ${XMLDestPath}

OLT XML update From BBF
    [Documentation]     Extract, running an except script, the XML that
    ...     represent all the Network viewed by the BBF-Adapter and
    ...     copy it to the ${XMLDestPath}.
    [Arguments]    ${dirXML}      ${pathToScript}
    Get BBF Device Aggregation  ${NAMESPACE}  ${dirXML}  ${pathToScript}
    ${oltes_bbf}=   Get Olts From XML    ${dirXML}
    Set Global Variable     ${oltes_bbf}

ONU XML update From BBF
    [Documentation]     Extract, running an except script, the XML that
    ...     represent all the Network viewed by the BBF-Adapter and
    ...     copy it to the ${XMLDestPath}.
    [Arguments]    ${dirXML}      ${pathToScript}
    Get BBF Device Aggregation  ${NAMESPACE}  ${dirXML}  ${pathToScript}
    ${onus_bbf}=   Get Onus From XML   ${dirXML}
    Set Global Variable     ${onus_bbf}

ALL DEVICES XML update From BBF
    [Documentation]     Extract, running an except script, the XML that
    ...     represent all the Network viewed by the BBF-Adapter and
    ...     copy it to the ${XMLDestPath}.
    [Arguments]    ${dirXML}      ${pathToScript}
    Get BBF Device Aggregation  ${NAMESPACE}  ${dirXML}  ${pathToScript}
    ${all_devices_bbf}=     Get All Devices  ${dirXML}
    Set Global Variable     ${all_devices_bbf}

Get Devices By Type
    [Documentation]     Extract ALL the Devices viewed by the BBF-Adapter
    ...     that there are the type defined: OLT(bbf-dvct:olt), ONU(bbf-dvct:onu)
    ...     ${XML} is the path to XML file OR the XML itself.
    ...     Return a List of Defined Devices information
    [Arguments]     ${XML}      ${typeAsk}
    #Take the XML file o the XML itself
    Log     ${XML}
    ${root}=        Parse XML       ${XML}
    #Define a list of all the OLTs
    @{bbf_olts_xml}=    Create List
    #Navigate in the XML to enter in the Devices and get all Devices in XML
    @{device} =	Get Elements	${root}	    devices/device
    ${number_of_devices}=   Get Length  ${device}
    #Run on all the devices
    FOR    ${I}    IN RANGE    0    ${number_of_devices}
        #Verify the correct Type of device that is declared
        ${type}=    Get Element Text     ${device}[${I}]     type
        Continue For Loop If    "${type}" != "${typeAsk}"
        #Append the device with che correct type in the list
        Append To List    ${bbf_olts_xml}    ${device}[${I}]
    END
    Log     ${bbf_olts_xml}
    [Return]    ${bbf_olts_xml}

Get Olts From XML
    [Documentation]     Extract ALL the OLTs viewed by the BBF-Adapter
    ...     ${XML} is the path to XML file OR the XML itself.
    ...     Return a List of OLTs information.
    [Arguments]     ${XML}
    #Get from the XML all OLT
    ${bbf_olts}=    Get Devices By Type     ${XML}      bbf-dvct:olt
    #Create a List of OLTs
    @{bbf_olts_Info}=    Create List
    ${number_of_olts}=   Get Length  ${bbf_olts}
    FOR    ${I}    IN RANGE    0    ${number_of_olts}
        #Enter in the component where there are the information of the OLT
        ${component}=   Get Element     ${bbf_olts}[${I}]     data/hardware/component
        #Get from the XML the data
        ${name}=    Get Element Text     ${component}     name
        ${hardware_rev}=    Get Element Text     ${component}     hardware-rev
        ${firmware_rev}=    Get Element Text     ${component}     firmware-rev
        ${serial_number}=    Get Element Text     ${component}     serial-num
        ${mfg_name}=    Get Element Text     ${component}     mfg-name
        ${model_name}=    Get Element Text     ${component}     model-name
        ${admin_state}=    Get Element Text     ${component}     state/admin-state
        ${oper_state}=    Get Element Text     ${component}     state/oper-state

        #Define a Dictionary that containe all the information about the OLT
        #Need to modify when there are add in the XML the connect-state
        ${bbf_olt}    Create Dictionary
        ...     name    ${name}
        ...     hardware_rev    ${hardware_rev}
        ...     firmware_rev    ${firmware_rev}
        ...     serial-num    ${serial_number}
        ...     mfg-name    ${mfg_name}
        ...     model-name    ${model_name}
        ...     admin-state   ${admin_state}
        ...     oper-state    ${oper_state}
        ...     connect-state   unknown

        Append To List    ${bbf_olts_Info}    ${bbf_olt}
    END
    Log     ${bbf_olts_Info}
    [Return]    ${bbf_olts_Info}

Get Onus From XML
    [Documentation]     Extract ALL the ONUs viewed by the BBF-Adapter
    ...     Return a List of ONUs information.
    [Arguments]     ${XML}
    #Get all the devices of the specific type
    ${bbf_onus}=    Get Devices By Type     ${XML}      bbf-dvct:onu
    #Create a list that will contain all the information of the ONUs
    @{bbf_onus_Info}=    Create List
    #Run on the XML compose be ONUs information
    ${number_of_onus}=   Get Length  ${bbf_onus}
    FOR    ${I}    IN RANGE    0    ${number_of_onus}
        #Enter in the component where there are the information of the ONU
        ${component}=   Get Element     ${bbf_onus}[${I}]     data/hardware/component
        #Get from the XML the data
        ${name}=    Get Element Text     ${component}     name
        ${parent}=    Get Element Text     ${component}     parent
        ${parent_rel_pos}=    Get Element Text     ${component}     parent-rel-pos
        ${hardware_rev}=    Get Element Text     ${component}     hardware-rev
        ${firmware_rev}=    Get Element Text     ${component}     firmware-rev
        ${serial_number}=    Get Element Text     ${component}     serial-num
        ${mfg_name}=    Get Element Text     ${component}     mfg-name
        ${model_name}=    Get Element Text     ${component}     model-name
        ${admin_state}=    Get Element Text     ${component}     state/admin-state
        ${oper_state}=    Get Element Text     ${component}     state/oper-state
        #Enter in the interfaces part
        ${interfaces}=   Get Element     ${bbf_onus}[${I}]     data/interfaces
        #Retrive all the information about all the interface of the consider ONU
        @{onu_interfaces}=      Get Interfaces From Onu XML Interfaces      ${interfaces}

        #Define a Dictionary that containe all the information about the OLT
        #Need to modify when there are add in the XML the connect-state
        #Need to modify when there are add in the XML the Onu-Reason
        ${bbf_onu}    Create Dictionary
        ...     name    ${name}
        ...     parent-id      ${parent}
        ...     parent-rel-pos      ${parent_rel_pos}
        ...     hardware_rev    ${hardware_rev}
        ...     firmware_rev    ${firmware_rev}
        ...     serial-num    ${serial_number}
        ...     mfg-name    ${mfg_name}
        ...     model-name    ${model_name}
        ...     admin-state   ${admin_state}
        ...     oper-state    ${oper_state}
        ...     connect-state    unknown
        ...     onu-reason    omci-flows-pushed
        ...     interfaces    ${onu_interfaces}

        Append To List    ${bbf_onus_Info}    ${bbf_onu}
    END
    Log     ${bbf_onus_Info}
    [Return]    ${bbf_onus_Info}

Get Interfaces From Onu XML Interfaces
    [Documentation]     Extract ALL the Interfaces of a ONU viewed by the BBF-Adapter
    ...     Return a List of ONU Interfaces information
    [Arguments]     ${interfaces_bbf}
    #Intereate on the Interfaces
    @{interface}=	Get Elements	${interfaces_bbf}	    interface
    #Create a list of interface for each ONU
    @{interfaces_Info}=     Create List
    ${number_of_interfaces}=   Get Length  ${interface}
    FOR    ${I}    IN RANGE    0    ${number_of_interfaces}
        #Get from the XML information about the interface
        ${name}=    Get Element Text     ${interface}[${I}]     name
        ${type}=    Get Element Text     ${interface}[${I}]     type
        ${oper_status}=    Get Element Text     ${interface}[${I}]     oper-status
        #Define a Dictionary that contain all the information of single interface
        ${onu_interface}    Create Dictionary
        ...     name    ${name}
        ...     type    ${type}
        ...     oper_status    ${oper_status}
        #Appen interface
        Append To List    ${interfaces_Info}    ${onu_interface}
    END
    Log     ${interfaces_Info}
    [Return]    ${interfaces_Info}

Get All Devices
    [Documentation]     Extract all the Device (OLTs and ONUS) in a unique List of Devices
    [Arguments]     ${XML}
    ${onus_bbf}=    Get Onus From XML  ${XML}
    ${olts_bbf}=    Get Olts From XML   ${XML}
    ${all_devices_bbf}=     Combine Lists     ${onus_bbf}      ${olts_bbf}
    [Return]    ${all_devices_bbf}

Admin State Translation From IETF to VOLTHA
    [Documentation]     Allow to translate the IETF of a Admin-State to VOLTHA
    [Arguments]     ${ietf_admin_state}
    #Remeber that exist in VOLTHA also Admini State with: Downloading_Image
    #PREPROVISIONED is consider inside the DISABLED state
    ${voltha_admin_state}=    Run Keyword IF    "${ietf_admin_state}"=="locked"
    ...    Set Variable     DISABLED
    ...    ELSE
    ...    Run Keyword IF    "${ietf_admin_state}"=="unlocked"
    ...    Set Variable     ENABLED
    ...    ELSE
    ...    Set Variable     UNKNOWN
    Log     ${voltha_admin_state}
    [Return]    ${voltha_admin_state}

Create Device in BBF
    [Arguments]    ${device_id}
    [Documentation]    PlaceHolder Method to future Create Device from the BBF Adapter
    Should Be True  True

Delete Device in BBF
    [Arguments]    ${device_id}
    [Documentation]    PlaceHolder Method to future Delete Device from the BBF Adapter
    Should Be True  True

Enable Device in BBF
    [Arguments]    ${device_id}
    [Documentation]    PlaceHolder Method to future Enable Device from the BBF Adapter
    Should Be True  True

Disable Device in BBF
    [Arguments]    ${device_id}
    [Documentation]    PlaceHolder Method to future Disable Device from the BBF Adapter
    Should Be True  True

Admin State Translation From VOLTHA to IETF
    [Documentation]     Allow to translate the VOLTHA of a Admin-State to IETF Standard
    [Arguments]     ${voltha_admin_state}
    #Remeber that exist in VOLTHA also Admini State with: Downloading_Image
    ${ietf_admin_state}=    Run Keyword IF    "${voltha_admin_state}"=="DISABLED"
    ...    Set Variable     locked
    ...    ELSE
    ...    Run Keyword IF    "${voltha_admin_state}"=="PREPROVISIONED"
    ...    Set Variable     locked
    ...    ELSE
    ...    Run Keyword IF    "${voltha_admin_state}"=="ENABLED"
    ...    Set Variable     unlocked
    ...    ELSE
    ...    Set Variable     unknown
    [Return]    ${ietf_admin_state}

Oper State Translation From IETF to VOLTHA
    [Documentation]     Allow to translate the IETF of a Oper-State to VOLTHA
    [Arguments]     ${ietf_oper_state}
    #Remeber that exist in VOLTHA also Admini State with: Discovered and Activating and Failed
    ${voltha_oper_state}=    Run Keyword IF    "${ietf_oper_state}"=="disable"
    ...    Set Variable     RECONCILING_FAILED
    ...    ELSE
    ...    Run Keyword IF    "${ietf_oper_state}"=="enabled"
    ...    Set Variable     ACTIVE
    ...    ELSE
    ...    Run Keyword IF    "${ietf_oper_state}"=="testing"
    ...    Set Variable     TESTING
    ...    ELSE
    ...    Set Variable     UNKNOWN
    Log     ${voltha_oper_state}
    [Return]    ${voltha_oper_state}

Oper State Translation From VOLTHA to IETF
    [Documentation]     Allow to translate the VOLTHA of a Oper-State to IETF Standard
    [Arguments]     ${voltha_oper_state}
    #Remeber that exist in VOLTHA also Admini State with: Discovered and Activating and Failed
    ${ietf_oper_state}=   Run Keyword IF    "${voltha_oper_state}"=="RECONCILING_FAILED"
    ...    Set Variable     disable
    ...    ELSE
    ...    Run Keyword IF    "${voltha_oper_state}"=="ACTIVE"
    ...    Set Variable     enabled
    ...    ELSE
    ...    Run Keyword IF    "${voltha_oper_state}"=="TESTING"
    ...    Set Variable     testing
    ...    ELSE
    ...    Set Variable     unknown
    Log     ${ietf_oper_state}
    [Return]    ${ietf_oper_state}

Connect State Translation From IETF to VOLTHA
    [Documentation]     Allow to translate the IETF of a Connect-State to VOLTHA
    [Arguments]     ${bbf_connect_state}
    #Only REACHABLE because we don't know the IETF status
    ${voltha_connect_state}=   Set Variable     REACHABLE
    [Return]    ${voltha_connect_state}

Connect State Translation From VOLTHA to IETF
    [Documentation]     Allow to translate the VOLTHA of a Connect-State to IETF Standard
    [Arguments]     ${voltha_connect_state}
    ${bbf_connect_state}=   Set Variable     unknown
    [Return]    ${bbf_connect_state}

Validate Onu in BBF
    [Documentation]    Validate an ONU in BBF and its states
    [Arguments]    ${admin_state_voltha}    ${oper_status_voltha}    ${connect_status_voltha}
    ...     ${onu_serial_number}    ${onu_reasons}
    #Translate some states from VOLTHA to IETF to verify it in the BBF
    ${admin_state}=  Admin State Translation From VOLTHA to IETF  ${admin_state_voltha}
    ${oper_status}=  Oper State Translation From VOLTHA to IETF  ${oper_status_voltha}
    #${connect_status_voltha}=   Connect State Translation From VOLTHA to IETF  ${connect_status_voltha}
    #Define passed to understand if there are or not the consider ONU
    ${passed}=      Set Variable    False
    ${number_of_onus}=   Get Length  ${onus_bbf}
    FOR    ${I}    IN RANGE    0    ${number_of_onus}
        Continue For Loop If    "${onu_serial_number}"!="${onus_bbf}[${I}][serial-num]"
        #The ONU is in the BBF
        ${passed}=      Set Variable    True
        #Get all the information of the ONU
        ${sn}=      Set Variable    ${onus_bbf}[${I}][serial-num]
        ${astate}=      Set Variable    ${onus_bbf}[${I}][admin-state]
        ${ostate}=      Set Variable    ${onus_bbf}[${I}][oper-state]
        #To modify when will add
        #${cstate}=      ${onus_bbf}[${I}][connect-state]
        ${oreason}=      Set Variable    ${onus_bbf}[${I}][onu-reason]
        #Check if status is correct to consider the ONU in a correct setup state
        Should Be True    ${passed}    No match found for ${sn} to validate device
        Log    ${passed}
        Should Be Equal    '${admin_state}'    '${astate}'    Device ${sn} admin_state != ${admin_state}
        ...    passed=False
        Should Be Equal    '${oper_status}'    '${ostate}'    Device ${sn} oper_status != ${oper_status}
        ...    passed=False
        #To modify when will add
        #Should Be Equal    '${connect_status}'    '${cstate}'    Device ${sn} conn_status != ${connect_status}
        #...    passed=False
        #Should Be Equal    '${onu_reasons}'    '${oreason}'    Device ${sn} reason != ${onu_reasons}
        #...    passed=False
        #Run Keyword If    '${onu}' == 'True'    Should Contain    '${onu_reason}'   '${mib_state}'
        #...    Device ${sn} mib_state incorrect (${mib_state}) passed=False
        Log     ${sn}
        Log     ${astate}
        Log     ${ostate}
        #Log     ${cstate}
        #Log     ${oreason}
    END
    #If false can not are the ONU or there are problem with the states status
    Should Be True    ${passed}    BBF Problem with this ONU SN: ${onu_serial_number}

Validate Olt in BBF
    [Documentation]    Verify if the Olts are present inside the XML of the BBF adapter
    ...     and if the states are correct.
    [Arguments]    ${admin_state_voltha}    ${oper_status_voltha}    ${connect_status_voltha}
    ...     ${olt_serial_number}    ${olt_device_id}
    #Translate some states from VOLTHA to IETF to verify it in the BBF
    ${admin_state}=  Admin State Translation From VOLTHA to IETF  ${admin_state_voltha}
    ${oper_status}=  Oper State Translation From VOLTHA to IETF  ${oper_status_voltha}
    #${connect_status_voltha}=   Connect State Translation From VOLTHA to IETF  ${connect_status_voltha}
    #Define passed to understand if there are or not the consider OLT
    ${passed}=      Set Variable    False
    ${number_of_oltes}=   Get Length  ${oltes_bbf}
    FOR    ${I}    IN RANGE    0    ${number_of_oltes}
        Continue For Loop If    "${olt_serial_number}"!="${oltes_bbf}[${I}][serial-num]"
        #The OLT is in the BBF
        ${passed}=      Set Variable    True
        #Get information of the OLT
        ${sn}=      Set Variable    ${oltes_bbf}[${I}][serial-num]
        ${astate}=      Set Variable    ${oltes_bbf}[${I}][admin-state]
        ${ostate}=      Set Variable    ${oltes_bbf}[${I}][oper-state]
        #To modify when will add
        #${cstate}=      ${oltes_bbf}[${I}][connect-state]
        #Check all the state status
        Should Be True    ${passed}    No match found for ${sn} to validate device
        Log    ${passed}
        Should Be Equal    '${admin_state}'    '${astate}'    Device ${sn} admin_state != ${admin_state}
        ...    passed=False
        Should Be Equal    '${oper_status}'    '${ostate}'    Device ${sn} oper_status != ${oper_status}
        ...    passed=False
        #To modify when will add
        #Should Be Equal    '${connect_status}'    '${cstate}'    Device ${sn} conn_status != ${connect_status}
        #...    passed=False
    END
    #If false can not are the OLT or there are problem with the states status
    Should Be True    ${passed}    BBF Problem with this ONU SN: ${olt_serial_number}

Validate Device in BBF
    [Documentation]    Verify if the Device (Olt or Onu) are present inside the XML of the BBF adapter
    ...     and if the states are correct.
    [Arguments]    ${admin_state_voltha}    ${oper_status_voltha}    ${connect_status_voltha}
    ...     ${serial_number}    ${device_id}    ${isONU}
    Run Keyword If  ${isONU}
    ...     Wait Until Keyword Succeeds    ${timeout}    5s
    ...     Validate Onu in BBF     ${admin_state_voltha}    ${oper_status_voltha}    ${connect_status_voltha}
    ...     ${serial_number}    ${device_id}
    ...     ELSE
    ...     Wait Until Keyword Succeeds    ${timeout}    5s
    ...     Validate Olt in BBF     ${admin_state_voltha}    ${oper_status_voltha}    ${connect_status_voltha}
    ...     ${serial_number}    ${device_id}

Validate ONUs After OLT Disable in BBF
    [Documentation]    Validates the ONUs state in BBF, ONUs port state in ONOS
    ...    and that pings do not succeed After corresponding OLT is Disabled
    [Arguments]     ${olt_serial_number}
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        ${dst}=    Set Variable    ${hosts.dst[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${of_id}=    Get ofID From OLT List    ${src['olt']}
        ${onu_port}=    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Get ONU Port in ONOS    ${src['onu']}    ${of_id}    ${src['uni_id']}
        ${onu_device_id}=    Get Device ID From SN    ${src['onu']}
        Wait Until Keyword Succeeds   ${timeout}    2s
        ...    Verify UNI Port Is Disabled   ${ONOS_SSH_IP}    ${ONOS_SSH_PORT}    ${src['onu']}    ${src['uni_id']}
        Run Keyword If    ${has_dataplane}    Run Keyword And Continue On Failure
        ...    Wait Until Keyword Succeeds    ${timeout}    2s
        ...    Check Ping    False    ${dst['dp_iface_ip_qinq']}    ${src['dp_iface_name']}
        ...    ${src['ip']}    ${src['user']}    ${src['pass']}    ${src['container_type']}    ${src['container_name']}
        ${onu_reasons}=  Create List     omci-flows-deleted
        Run Keyword If    ${supress_add_subscriber}    Append To List    ${onu_reasons}    stopping-openomci
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...    Validate Onu in BBF     ENABLED     DISCOVERED
        ...    UNREACHABLE    ${src['onu']}   ${onu_reasons}
    END

Validate Olt Disabled in BBF
    [Documentation]    Validates the ONUs state in BBF, ONUs port state in ONOS
    ...    and that pings do not succeed After corresponding OLT is Disabled
    [Arguments]     ${olt_serial_number}    ${olt_device_id}
    Validate Olt in BBF  admin_state_voltha=DISABLED  oper_status_voltha=UNKNOWN
    ...     connect_status_voltha=REACHABLE     olt_serial_number=${olt_serial_number}
    ...     olt_device_id=${olt_device_id}

Validate Device Removed in BBF
    [Documentation]    Verify if the device with that ${serial_number}, has been removed
    [Arguments]    ${device_serial_number}
    ${eliminated}=      Set Variable    True
    ${number_of_devices}=   Get Length  ${all_devices_bbf}
    FOR    ${I}    IN RANGE    0    ${number_of_devices}
        Continue For Loop If    "${device_serial_number}"!="${all_devices_bbf}[${I}][serial-num]"
        ${eliminated}=      Set Variable    False
    END
    Should Be True    ${eliminated}    Device with ${device_serial_number} not eliminated

Validate all ONUS for OLT Removed in BBF
    [Arguments]    ${olt_serial_number}
    [Documentation]    Verifys that all the ONUS for OLT ${serial_number}, has been removed
    @{removed_onu_list}=    Create List
    FOR    ${I}    IN RANGE    0    ${num_all_onus}
        ${src}=    Set Variable    ${hosts.src[${I}]}
        Continue For Loop If    "${olt_serial_number}"!="${src['olt']}"
        ${removed_onu_seria_number}=     Set Variable    ${src['onu']}
        Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
        ...     Validate Device Removed in BBF   ${removed_onu_seria_number}
        Append To List    ${removed_onu_list}    ${removed_onu_seria_number}
    END
    Log     ${removed_onu_list}

Get Device ID From SN in BBF
    [Documentation]     Retrive from the XML the Device Id of a Device
    ...     using the Serial Number
    [Arguments]      ${device_serial_number}
    ${Device_ID}=   Set Variable    0
    ${number_of_devices}=   Get Length  ${all_devices_bbf}
    FOR    ${I}    IN RANGE    0    ${number_of_devices}
        Continue For Loop If    "${device_serial_number}"!="${all_devices_bbf}[${I}][serial-num]"
        ${Device_ID}=   Set Variable    ${all_devices_bbf}[${I}][name]
        Log     ${Device_ID}
    END
    [Return]    ${Device_ID}

Correct representation check VOLTHA-IETF
    [Documentation]     Check if all the information the VOLTHA have about a device
    ...     is a correct representation of the device in BBF-Adapter
    ...     Do to Ambiguity from Stats in IETF and VOLTHA is not possible to do
    ...     the reverse test.
    [Arguments]      ${device_serial_number}    ${isONU}
    ${cmd}=     Catenate    voltctl -c ${VOLTCTL_CONFIG} device list | grep ${device_serial_number}
    ${rc}    ${rest}=    Run and Return Rc and Output    ${cmd}
    Should Not Be Empty    ${rest}
    Run Keyword If   ${isONU}
    ...     Correct Representation check ONU Voltha-IETF    ${rest}
    ...     ELSE
    ...     Correct Representation check OLT Voltha-IETF    ${rest}

Correct Representation check ONU Voltha-IETF
    [Documentation]     Check if all the information the VOLTHA have about a device
    ...     is a correct representation of the device in BBF-Adapter
    ...     Do to Ambiguity from Stats in IETF and VOLTHA is not possible to do
    ...     the reverse test.
    [Arguments]      ${rest}
    ${rest}    ${onu_reason} =      Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${connect_state} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${oper_state} =      Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${admin_state} =     Split String From Right	${rest} ${SPACE}    max_split=1
    ${rest}    ${serial_number} =   Split String From Right	${rest} ${SPACE}    max_split=1
    ${rest}    ${parent_id} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${root} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${id}    ${type} =   Split String From Right	${rest} ${SPACE}	max_split=1

    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate Onu in BBF     ${admin_state}      ${oper_state}       ${connect_state}
    ...    ${serial_number}    ${onu_reason}

Correct Representation check OLT Voltha-IETF
    [Documentation]     Check if all the information the VOLTHA have about a device
    ...     is a correct representation of the device in BBF-Adapter
    ...     Do to Ambiguity from Stats in IETF and VOLTHA is not possible to do
    ...     the reverse test.
    [Arguments]      ${rest}
    ${rest}    ${connect_state} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${oper_state} =      Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${admin_state} =     Split String From Right	${rest} ${SPACE}    max_split=1
    ${rest}    ${serial_number} =   Split String From Right	${rest} ${SPACE}    max_split=1
    ${rest}    ${parent_id} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${rest}    ${root} =   Split String From Right	${rest} ${SPACE}	max_split=1
    ${id}    ${type} =   Split String From Right	${rest} ${SPACE}	max_split=1

    Run Keyword And Continue On Failure    Wait Until Keyword Succeeds    ${timeout}    5s
    ...    Validate Olt in BBF     ${admin_state}      ${oper_state}       ${connect_state}
    ...    ${serial_number}    ${id}