# SPDX-FileCopyrightText: 2019 - present Open Networking Foundation <info@opennetworking.org>
#
# SPDX-License-Identifier: Apache-2.0

*** Variables ***
${BBSIM_OLT_SN}    BBSIM_OLT_0
${BBSIM_ONU_SN}    BBSM00000001
${ONOS_REST_PORT}    30120
${ONOS_SSH_PORT}    30115
${OLT_PORT}       9191
@{PODLIST1}       voltha-kafka    voltha-ofagent
@{PODLIST2}       bbsim    etcd-operator-etcd-operator-etcd-operator    radius    voltha-api-server
...               voltha-cli-server    voltha-ro-core    voltha-rw-core-11
