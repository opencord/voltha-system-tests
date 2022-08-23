# Copyright 2017-present Open Networking Foundation
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
@{connection_list}
${alias}                  ONOS_SSH
${ssh_read_timeout}       60s
${ssh_prompt}             karaf@root >
${ssh_regexp_prompt}      REGEXP:k.*a.*r.*a.*f.*@.*r.*o.*o.*t.* .*>.*
${regexp_prompt}          (?ms)(.*)k(.*)a(.*)r(.*)a(.*)f(.*)@(.*)r(.*)o(.*)o(.*)t(.*) (.*)>(.*)
${ssh_width}              400
${disable_highlighter}    setopt disable-highlighter
# ${keep_alive_interval} is set to 0s means sending the keepalive packet is disabled!
${keep_alive_interval}    0s

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
    #Verify if there are some error of connectivity with the Adapter Pod
    ${expect}=      Get Length      ${output}
    Run Keyword If    ${expect} <= 100
    ...    Fail    Impossible to Reach the BBF-Adapter Pod (port-forward/key-exchange?)
    #Copy From the Pod to the ${XMLDestPath} the XML file
    Copy File From Pod      ${namespace}    app=bbf-adapter     home/voltha/output.xml     ${XMLDestPath}    

Get Devices By Type
    [Documentation]     Extract ALL the Devices viewed by the BBF-Adapter
    ...     that there are the type defined: OLT(bbf-dvct:olt), ONU(bbf-dvct:onu)
    ...     ${XML} is the path to XML file OR the XML itself.
    ...     Return a List of Defined Devices information
    [Arguments]     ${XML}      ${typeAsk}
    #Take the XML file o the XML itself
    ${root}=        Parse XML       ${XML}
    #Navigate in the XML to enter in the Devices
    ${devices}=       Get Element     ${root}     devices
    Dictionary Should Contain Key   ${devices.attrib}       xmlns

    #Define a list of all the OLTs
    @{bbf_olts_xml}=    Create List
    #Take a pointer of a device element of devices    
    @{device} =	Get Elements	${devices}	    device
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
    #Remeber that exist in VOLTHA also Admini State with: Preprovisioned and Downloading_Image
    ${voltha_admin_state}=    Run Keyword IF    "${ietf_admin_state}"=="locked"
    ...    Set Variable     DISABLE
    ...    ELSE
    ...    Run Keyword IF    "${ietf_admin_state}"=="unlocked"
    ...    Set Variable     ENABLED
    ...    ELSE
    ...    Set Variable     UNKNOWN
    Log     ${voltha_admin_state}
    [Return]    ${voltha_admin_state}

Admin State Translation From VOLTHA to IETF
    [Documentation]     Allow to translate the VOLTHA of a Admin-State to IETF Standard
    [Arguments]     ${voltha_admin_state}
    #Remeber that exist in VOLTHA also Admini State with: Preprovisioned and Downloading_Image
    ${ietf_admin_state}=    Run Keyword IF    "${voltha_admin_state}"=="DISABLE"
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
    [Return]    ${bbf_connect_state}all_devices_bbf

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
    END

    Log     ${sn}
    Log     ${astate}
    Log     ${ostate}
    #Log     ${cstate}
    #Log     ${oreason}
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

Correct representation check
    [Documentation]     Check if all the information the BBF-Adapter have about a device
    ...     is a correct representation of the device in VOLTHA
    ...     Is not necessary to do a test from VOLTHA to BBF-Adapter
    ...     because this test all the important features    
    [Arguments]      ${device_serial_number}    ${isONU}
    ${number_of_devices}=   Get Length  ${all_devices_bbf}
    FOR    ${I}    IN RANGE    0    ${number_of_devices}
        Continue For Loop If    "${device_serial_number}"!="${all_devices_bbf}[${I}][admin-state]"
        ${admin_state}=  Admin State Translation From IETF to VOLTHA  ${all_devices_bbf}[${I}][oper-state]
        ${oper_status}=  Oper State Translation From IETF to VOLTHA  ${all_devices_bbf}[${I}][name]
        #${connect_status_voltha}=   Connect State Translation From IETF to VOLTHA  ${all_devices_bbf}[${I}][connect-state]  
        #Define a command to execute voltctl combine to multiple grep that consider ALL
        #infomation that can be retrive from a device in VOLTHA.
        ${cmd}=    Run Keyword If      ${isONU}    
        ...     Catenate    voltctl -c ${VOLTCTL_CONFIG} device list |
        ...     grep    ${all_devices_bbf}[${I}][name] |
        ...     grep    ${all_devices_bbf}[${I}][parent-id] |
        ...     grep    ${all_devices_bbf}[${I}][serial-num] |
        ...     grep    ${admin_state} |
        ...     grep    ${oper_status} 
        #|
        #...     grep    ${connect_status_voltha} |
        #...     grep    ${all_devices_bbf}[${I}][onu-reason]
        ...     ELSE    Catenate    voltctl -c ${VOLTCTL_CONFIG} device list |
        ...     grep    ${all_devices_bbf}[${I}][name] |
        ...     grep    ${all_devices_bbf}[${I}][serial-num] |
        ...     grep    ${admin_state} |
        ...     grep    ${oper_status} 
        #|
        #...     grep    ${connect_status_voltha}
        ${rc}    ${output}=    Run and Return Rc and Output    ${cmd}
        Should Not Be Empty    ${output}
        ${Device_ID}=   Set Variable    ${all_devices_bbf}[${I}][name]
        Log     ${Device_ID}
    END