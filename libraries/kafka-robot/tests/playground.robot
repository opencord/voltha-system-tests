*** Settings ***
Library    String

*** Test Cases ***
000
    ${mcp_device_name_real_DPU}  set variable  mix
    FOR  ${i}  IN RANGE  20
        ${var}  Evaluate  '%s-gfast%.2d-cpe' % ('${mcp_device_name_real_DPU}', ${i+1})
        Log  ${var}  WARN
    END
