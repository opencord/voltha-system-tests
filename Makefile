# -*- makefile -*-
# -----------------------------------------------------------------------
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
# -----------------------------------------------------------------------

.DEFAULT_GOAL := sanity-kind

TOP         ?= .
MAKEDIR     ?= $(TOP)/makefiles

# Assign early: altered by include
ROOT_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

##--------------------##
##---]  INCLUDES  [---##
##--------------------##
include $(MAKEDIR)/include.mk
include $(MAKEDIR)/patches/include.mk

# Configuration and lists of files for linting/testing
VERSION   ?= $(shell cat ./VERSION)

PYTHON_FILES := $(wildcard libraries/*.py)
ROBOT_FILES  := $(shell find . -name *.robot -print)
YAML_FILES   := $(shell find ./tests -type f \( -name *.yaml -o -name *.yml \) -print)
JSON_FILES   := $(shell find ./tests -name *.json -print)

# Robot config
ROBOT_SANITY_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_DT_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-dt.yaml
ROBOT_SANITY_MULTIPLE_OLT_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-2OLTx2ONUx2PON.yaml
ROBOT_SANITY_DT_MULTIPLE_OLT_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-2OLTx2ONUx2PON-dt.yaml
ROBOT_SANITY_TT_MULTIPLE_OLT_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-2OLTx2ONUx2PON-tt.yaml
ROBOT_FAIL_SINGLE_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind.yaml
ROBOT_SANITY_MULT_PON_FILE      ?= $(ROOT_DIR)/tests/data/bbsim-kind-2x2.yaml
ROBOT_SCALE_SINGLE_PON_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-16.yaml
ROBOT_SCALE_MULT_PON_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x2.yaml
ROBOT_SCALE_MULT_ONU_FILE       ?= $(ROOT_DIR)/tests/data/bbsim-kind-8x8.yaml
ROBOT_DEBUG_LOG_OPT             ?=
ROBOT_MISC_ARGS                 ?=
ROBOT_SANITY_TT_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tt.yaml
ROBOT_DMI_SINGLE_BBSIM_FILE     ?= $(ROOT_DIR)/tests/data/dmi-components-bbsim.yaml
ROBOT_DMI_SINGLE_ADTRAN_FILE     ?= $(ROOT_DIR)/tests/data/dmi-components-adtran.yaml
ROBOT_SW_UPGRADE_FILE     ?= $(ROOT_DIR)/tests/data/software-upgrade.yaml
ROBOT_PM_DATA_FILE     ?= $(ROOT_DIR)/tests/data/pm-data.yaml
ROBOT_SANITY_MULTI_UNI_SINGLE_PON_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-multi-uni.yaml
ROBOT_SANITY_MULTI_UNI_MULTIPLE_OLT_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-multi-uni-2OLTx2ONUx2PON.yaml
ROBOT_SANITY_TT_MULTI_UNI_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-multi-uni-tt.yaml
ROBOT_SANITY_TT_MULTI_UNI_MULTIPLE_OLT_FILE     ?= $(ROOT_DIR)/tests/data/bbsim-kind-multi-uni-2OLTx2ONUx2PON-tt.yaml
ROBOT_SANITY_DT_FTTB_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-dt-fttb-1OLTx1PONx2ONUx2UNI.yaml
ROBOT_SANITY_TIM_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tim.yaml
ROBOT_SANITY_TIM_SINGLE_PON_MULTI_ONU_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tim-OLTxPONx2ONU.yaml
ROBOT_SANITY_TIM_MULTI_PON_MULTI_ONU_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tim-OLTx2PONx2ONU.yaml
ROBOT_SANITY_TIM_MULTI_OLT_MULTI_PON_MULTI_ONU_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-tim-2OLTx2PONx2ONU.yaml
ROBOT_SANITY_BBF_ADPATER_SINGLE_PON_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-bbf-adapter.yaml
ROBOT_SANITY_BBF_ADPATER_ADD_DELETE_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-bbf-adapter_addDelete_tests.yaml
ROBOT_SANITY_DT_SINGLE_PON_MULTI_ONU_FILE    ?= $(ROOT_DIR)/tests/data/bbsim-kind-dt-1OLTx1PONx2ONU.yaml

# for backwards compatibility
sanity-kind: sanity-single-kind

# to simplify ci
sanity-kind-att: sanity-single-kind

# ATT Multi-UNI Sanity Target
sanity-kind-multiuni-att: ROBOT_MISC_ARGS += -X -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-multiuni-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_SINGLE_PON_FILE)
sanity-kind-multiuni-att: ROBOT_FILE := Voltha_PODTests.robot
sanity-kind-multiuni-att: voltha-test

# ATT Multi-UNI Functional Suite Target
functional-single-kind-multiuni-att: ROBOT_MISC_ARGS += -X -i sanityORmulti-uni $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-multiuni-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_SINGLE_PON_FILE)
functional-single-kind-multiuni-att: ROBOT_FILE := Voltha_PODTests.robot
functional-single-kind-multiuni-att: voltha-test

# for scale pipeline
voltha-scale: ROBOT_MISC_ARGS += -i activation -v NAMESPACE:voltha $(ROBOT_DEBUG_LOG_OPT)
voltha-scale: voltha-scale-test

# for onu-upgrade scale pipeline
# Requirement: Pass ONU image details in following parameters
# image_version, image_url, image_vendor, image_activate_on_success, image_commit_on_success, image_crc
voltha-scale-onu-upgrade: ROBOT_MISC_ARGS += -i setup -i activation -i onu-upgrade -v NAMESPACE:voltha -v image_version:BBSM_IMG_00002 -v image_url:http://bbsim0:50074/images/software-image.img -v image_vendor:BBSM -v image_activate_on_success:false -v image_commit_on_success:false -v image_crc:0 $(ROBOT_DEBUG_LOG_OPT)
voltha-scale-onu-upgrade: voltha-scale-test

# target to invoke DT Workflow Sanity
sanity-kind-dt: ROBOT_MISC_ARGS += -i sanityDt $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
sanity-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
sanity-kind-dt: voltha-dt-test

# target to invoke DT FTTB Workflow Sanity
sanity-kind-dt-fttb: ROBOT_MISC_ARGS += -i sanityDtFttb $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-dt-fttb: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_FTTB_SINGLE_PON_FILE)
sanity-kind-dt-fttb: ROBOT_FILE := Voltha_DT_FTTB_Tests.robot
sanity-kind-dt-fttb: voltha-dt-test

functional-single-kind: ROBOT_MISC_ARGS += -i sanityORfunctional -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
functional-single-kind: bbsim-kind

# to simplify ci
functional-single-kind-att: functional-single-kind

# target to invoke DT Workflow Functional scenarios
functional-single-kind-dt: ROBOT_MISC_ARGS += -i sanityDtORfunctionalDt -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
functional-single-kind-dt: ROBOT_FILE := Voltha_DT_PODTests.robot
functional-single-kind-dt: voltha-dt-test

# target to invoke TT Workflow Sanity
sanity-kind-tt: ROBOT_MISC_ARGS += -i sanityTT $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
sanity-kind-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
sanity-kind-tt: voltha-tt-test

sanity-kind-tt-maclearning: ROBOT_MISC_ARGS += -i sanityTT -v with_maclearning:True $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tt-maclearning: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
sanity-kind-tt-maclearning: ROBOT_FILE := Voltha_TT_PODTests.robot
sanity-kind-tt-maclearning: voltha-tt-test

sanity-kind-multiuni-tt: ROBOT_MISC_ARGS += -i sanityTT $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-multiuni-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTI_UNI_SINGLE_PON_FILE)
sanity-kind-multiuni-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
sanity-kind-multiuni-tt: voltha-tt-test

# target to invoke TT Workflow Functional scenarios
functional-single-kind-tt: ROBOT_MISC_ARGS += -i sanityTTORfunctionalTT -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
functional-single-kind-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
functional-single-kind-tt: voltha-tt-test

functional-single-kind-multiuni-tt: ROBOT_MISC_ARGS += -i sanityTTORfunctionalTT -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-single-kind-multiuni-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTI_UNI_SINGLE_PON_FILE)
functional-single-kind-multiuni-tt: ROBOT_FILE := Voltha_TT_PODTests.robot
functional-single-kind-multiuni-tt: voltha-tt-test

# target to invoke TIM Workflow Sanity
sanity-kind-tim: ROBOT_MISC_ARGS += -i sanityTIM $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tim: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TIM_SINGLE_PON_FILE)
sanity-kind-tim: ROBOT_FILE := Voltha_TIM_PODTests.robot
sanity-kind-tim: voltha-tim-test

sanity-kind-tim-multi-onu: ROBOT_MISC_ARGS += -i sanityTIM $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tim-multi-onu: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TIM_SINGLE_PON_MULTI_ONU_FILE)
sanity-kind-tim-multi-onu: ROBOT_FILE := Voltha_TIM_PODTests.robot
sanity-kind-tim-multi-onu: voltha-tim-test

sanity-kind-tim-multi-pon-multi-onu: ROBOT_MISC_ARGS += -i sanityTIM $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tim-multi-pon-multi-onu: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TIM_MULTI_PON_MULTI_ONU_FILE)
sanity-kind-tim-multi-pon-multi-onu: ROBOT_FILE := Voltha_TIM_PODTests.robot
sanity-kind-tim-multi-pon-multi-onu: voltha-tim-test

sanity-kind-tim-multi-olt-multi-pon-multi-onu: ROBOT_MISC_ARGS += -i sanityTIM $(ROBOT_DEBUG_LOG_OPT)
sanity-kind-tim-multi-olt-multi-pon-multi-onu: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TIM_MULTI_OLT_MULTI_PON_MULTI_ONU_FILE)
sanity-kind-tim-multi-olt-multi-pon-multi-onu: ROBOT_FILE := Voltha_TIM_PODTests.robot
sanity-kind-tim-multi-olt-multi-pon-multi-onu: voltha-tim-test


# target to invoke multiple OLTs Functional scenarios
functional-multi-olt: ROBOT_MISC_ARGS += -i sanityORfunctional -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
functional-multi-olt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
functional-multi-olt: ROBOT_FILE := Voltha_PODTests.robot
functional-multi-olt: voltha-test

functional-multiuni-multiolt-att: ROBOT_MISC_ARGS += -X -i sanityORmulti-uni $(ROBOT_DEBUG_LOG_OPT)
functional-multiuni-multiolt-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_MULTIPLE_OLT_FILE)
functional-multiuni-multiolt-att: ROBOT_FILE := Voltha_PODTests.robot
functional-multiuni-multiolt-att: voltha-test

# target to invoke test with openonu go adapter applying 1T1GEM tech-profile at single ONU
1t1gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T1GEM
1t1gem-openonu-go-adapter-test: openonu-go-adapter-test

# target to invoke test with openonu go adapter applying 1T4GEM tech-profile at single ONU
1t4gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T4GEM
1t4gem-openonu-go-adapter-test: openonu-go-adapter-test

# target to invoke test with openonu go adapter applying 1T8GEM tech-profile at single ONU
1t8gem-openonu-go-adapter-test: ROBOT_MISC_ARGS += -v techprofile:1T8GEM
1t8gem-openonu-go-adapter-test: openonu-go-adapter-test

# target to invoke openonu go adapter
openonu-go-adapter-test: ROBOT_MISC_ARGS += -v state2test:omci-flows-pushed -v testmode:SingleStateTime
openonu-go-adapter-test: ROBOT_MISC_ARGS += -i sanityOnuGo -i functionalOnuGo
openonu-go-adapter-test: ROBOT_MISC_ARGS += -e notreadyOnuGo $(ROBOT_DEBUG_LOG_OPT)
openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUStateTests.robot
openonu-go-adapter-test: openonu-go-adapter-tests

# target to invoke bbf adapter
bbf-adapter: ROBOT_MISC_ARGS += -i sanityBbfAdapter $(ROBOT_DEBUG_LOG_OPT)
bbf-adapter: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_BBF_ADPATER_SINGLE_PON_FILE)
bbf-adapter: ROBOT_FILE := Voltha_BBF_Adapter_Tests.robot
bbf-adapter: voltha-bbf-adapter-test

bbf-adapter-functionality: ROBOT_MISC_ARGS += -i bbfAdapterFunctionality $(ROBOT_DEBUG_LOG_OPT)
bbf-adapter-functionality: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_BBF_ADPATER_ADD_DELETE_FILE)
bbf-adapter-functionality: ROBOT_FILE := Voltha_BBF_Adapter_Tests.robot
bbf-adapter-functionality: voltha-bbf-adapter-test

bbf-adapter-functionality-single: ROBOT_MISC_ARGS += -i bbfAdapterFunctionalitySingleTest $(ROBOT_DEBUG_LOG_OPT)
bbf-adapter-functionality-single: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_BBF_ADPATER_ADD_DELETE_FILE)
bbf-adapter-functionality-single: ROBOT_FILE := Voltha_BBF_Adapter_Tests.robot
bbf-adapter-functionality-single: voltha-bbf-adapter-test

# target to invoke test with openonu go adapter applying MIB-Upload-Templating
mib-upload-templating-openonu-go-adapter-test: ROBOT_MISC_ARGS += -i functionalOnuGo
mib-upload-templating-openonu-go-adapter-test: ROBOT_MISC_ARGS += -e notreadyOnuGo $(ROBOT_DEBUG_LOG_OPT)
mib-upload-templating-openonu-go-adapter-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
mib-upload-templating-openonu-go-adapter-test: ROBOT_FILE := Voltha_ONUTemplateTests.robot
mib-upload-templating-openonu-go-adapter-test: openonu-go-adapter-tests

# target to invoke test with openonu go adapter applying 1T8GEM tech-profile at single ONU with OMCI hardening
# timeout is determined for omci_response_rate=9 and omci_timeout=1s
openonu-go-adapter-omci-hardening-passed-test: ROBOT_MISC_ARGS += -v timeout:180s -v techprofile:1T8GEM
openonu-go-adapter-omci-hardening-passed-test: openonu-go-adapter-test

# target to invoke openonu go adapter failed state test at single ONU with OMCI hardening
# test should show in case of too small omci_response_rate (<=7) in BBSIM that OMCI hardening does not work
# test is PASS when ONU does not leave state 'starting-openomci'
openonu-go-adapter-omci-hardening-failed-test: ROBOT_MISC_ARGS += -v timeout:300s -i NegativeStateTestOnuGo
openonu-go-adapter-omci-hardening-failed-test: ROBOT_MISC_ARGS += -e notreadyOnuGo $(ROBOT_DEBUG_LOG_OPT)
openonu-go-adapter-omci-hardening-failed-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
openonu-go-adapter-omci-hardening-failed-test: ROBOT_FILE := Voltha_ONUNegativeStateTests.robot
openonu-go-adapter-omci-hardening-failed-test: openonu-go-adapter-tests

# target to invoke reconcile tests with openonu go adapter at single ONU with ATT workflow (default workflow)
reconcile-openonu-go-adapter-test-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
reconcile-openonu-go-adapter-test-att: reconcile-openonu-go-adapter-tests-att

# target to invoke reconcile tests with openonu go adapter at single ONU with DT workflow
reconcile-openonu-go-adapter-test-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
reconcile-openonu-go-adapter-test-dt: reconcile-openonu-go-adapter-tests-dt

# target to invoke reconcile tests with openonu go adapter at single ONU with TT workflow
reconcile-openonu-go-adapter-test-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
reconcile-openonu-go-adapter-test-tt: reconcile-openonu-go-adapter-tests-tt

# target to invoke reconcile tests with openonu go adapter at single ONU multi UNI with TT workflow
reconcile-openonu-go-adapter-multi-uni-test-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTI_UNI_SINGLE_PON_FILE)
reconcile-openonu-go-adapter-multi-uni-test-tt: ROBOT_MISC_ARGS += -v unitag_sub:True
reconcile-openonu-go-adapter-multi-uni-test-tt: reconcile-openonu-go-adapter-tests-tt

# target to invoke reconcile tests with openonu go adapter with multiple OLTs scenario with ATT workflow (default workflow)
reconcile-openonu-go-adapter-multi-olt-test-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
reconcile-openonu-go-adapter-multi-olt-test-att: reconcile-openonu-go-adapter-tests-att

# target to invoke reconcile tests with openonu go adapter with multiple OLTs scenario with DT workflow
reconcile-openonu-go-adapter-multi-olt-test-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_MULTIPLE_OLT_FILE)
reconcile-openonu-go-adapter-multi-olt-test-dt: reconcile-openonu-go-adapter-tests-dt

# target to invoke reconcile tests with openonu go adapter with multiple OLTs scenario with TT workflow
reconcile-openonu-go-adapter-multi-olt-test-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTIPLE_OLT_FILE)
reconcile-openonu-go-adapter-multi-olt-test-tt: reconcile-openonu-go-adapter-tests-tt

# target to invoke reconcile tests with openonu go adapter with multiple OLTs multi UNI scenario with TT workflow
reconcile-openonu-go-adapter-multi-olt-multi-uni-test-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTI_UNI_MULTIPLE_OLT_FILE)
reconcile-openonu-go-adapter-multi-olt-multi-uni-test-tt: ROBOT_MISC_ARGS += -v unitag_sub:True
reconcile-openonu-go-adapter-multi-olt-multi-uni-test-tt: reconcile-openonu-go-adapter-tests-tt

# target to invoke reconcile tests with openonu go adapter with ATT workflow
reconcile-openonu-go-adapter-tests-att: ROBOT_MISC_ARGS += -v workflow:ATT
reconcile-openonu-go-adapter-tests-att: reconcile-openonu-go-adapter-tests

# target to invoke reconcile tests with openonu go adapter with DT workflow
reconcile-openonu-go-adapter-tests-dt: ROBOT_MISC_ARGS += -v workflow:DT
reconcile-openonu-go-adapter-tests-dt: reconcile-openonu-go-adapter-tests

# target to invoke reconcile tests with openonu go adapter with TT workflow
reconcile-openonu-go-adapter-tests-tt: ROBOT_MISC_ARGS += -v workflow:TT
reconcile-openonu-go-adapter-tests-tt: reconcile-openonu-go-adapter-tests

# target to invoke reconcile tests with openonu go adapter at single ONU resp. multiple OLTs
reconcile-openonu-go-adapter-tests: ROBOT_MISC_ARGS += -i functionalOnuGo
reconcile-openonu-go-adapter-tests: ROBOT_MISC_ARGS += -e notreadyOnuGo $(ROBOT_DEBUG_LOG_OPT)
reconcile-openonu-go-adapter-tests: ROBOT_FILE := Voltha_ONUReconcileTests.robot
reconcile-openonu-go-adapter-tests: openonu-go-adapter-tests

# target to invoke test with openonu go adapter applying 1T1GEM tech-profile with multiple OLTs scenarios with ATT workflow
1t1gem-openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -v techprofile:1T1GEM
1t1gem-openonu-go-adapter-multi-olt-test: openonu-go-adapter-multi-olt-test

# target to invoke test with openonu go adapter applying 1T4GEM tech-profile with multiple OLTs scenarios with ATT workflow
1t4gem-openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -v techprofile:1T4GEM
1t4gem-openonu-go-adapter-multi-olt-test: openonu-go-adapter-multi-olt-test

# target to invoke test with openonu go adapter applying 1T8GEM tech-profile with multiple OLTs scenarios with ATT workflow
1t8gem-openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -v techprofile:1T8GEM
1t8gem-openonu-go-adapter-multi-olt-test: openonu-go-adapter-multi-olt-test

# target to invoke test with openonu go adapter (applying 1T1GEM tech-profile) with multiple OLTs scenarios with ATT workflow
openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -v state2test:omci-flows-pushed -v testmode:SingleStateTime
openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -i sanityOnuGo -i functionalOnuGo
openonu-go-adapter-multi-olt-test: ROBOT_MISC_ARGS += -e notreadyOnuGo $(ROBOT_DEBUG_LOG_OPT)
openonu-go-adapter-multi-olt-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
openonu-go-adapter-multi-olt-test: ROBOT_FILE := Voltha_ONUStateTests.robot
openonu-go-adapter-multi-olt-test: openonu-go-adapter-tests

sanity-single-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-single-kind: bbsim-kind

sanity-bbsim-att: ROBOT_MISC_ARGS += -v workflow:ATT
sanity-bbsim-att: sanity-bbsim

sanity-bbsim-dt: ROBOT_MISC_ARGS += -v workflow:DT
sanity-bbsim-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
sanity-bbsim-dt: ROBOT_FILE := Voltha_BBSimTests.robot
sanity-bbsim-dt: voltha-bbsim-test

sanity-bbsim-tt: ROBOT_MISC_ARGS += -v workflow:TT
sanity-bbsim-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
sanity-bbsim-tt: ROBOT_FILE := Voltha_BBSimTests.robot
sanity-bbsim-tt: voltha-bbsim-test

sanity-bbsim: ROBOT_MISC_ARGS += -i bbsimSanity $(ROBOT_DEBUG_LOG_OPT)
sanity-bbsim: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
sanity-bbsim: ROBOT_FILE := Voltha_BBSimTests.robot
sanity-bbsim: voltha-bbsim-test

voltha-bbsim-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/bbsim ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

rwcore-restart-single-kind: ROBOT_MISC_ARGS += -X -i functionalANDrwcore-restart $(ROBOT_DEBUG_LOG_OPT)
rwcore-restart-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
rwcore-restart-single-kind: ROBOT_FILE := Voltha_FailureScenarios.robot
rwcore-restart-single-kind: voltha-test

single-kind: ROBOT_MISC_ARGS += -X -i $(TEST_TAGS) $(ROBOT_DEBUG_LOG_OPT)
single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
single-kind: ROBOT_FILE := Voltha_PODTests.robot
single-kind: voltha-test

sanity-multi-kind: ROBOT_MISC_ARGS += -i sanity $(ROBOT_DEBUG_LOG_OPT)
sanity-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
sanity-multi-kind: bbsim-kind

functional-multi-kind: ROBOT_MISC_ARGS += -i sanityORfunctional $(ROBOT_DEBUG_LOG_OPT)
functional-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
functional-multi-kind: bbsim-kind

bbsim-kind: ROBOT_MISC_ARGS += -X
bbsim-kind: ROBOT_FILE := Voltha_PODTests.robot
bbsim-kind: voltha-test

scale-single-kind: ROBOT_MISC_ARGS += -i active $(ROBOT_DEBUG_LOG_OPT)
scale-single-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_SINGLE_PON_FILE)
scale-single-kind: bbsim-scale-kind

scale-multi-kind: ROBOT_MISC_ARGS += -i active $(ROBOT_DEBUG_LOG_OPT)
scale-multi-kind: ROBOT_CONFIG_FILE := $(ROBOT_SCALE_MULT_PON_FILE)
scale-multi-kind: bbsim-scale-kind

bbsim-scale-kind: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-scale-kind: ROBOT_FILE := Voltha_ScaleFunctionalTests.robot
bbsim-scale-kind: voltha-test

#Only supported in full mode
system-scale-test: ROBOT_FILE := K8S_SystemTest.robot
system-scale-test: ROBOT_MISC_ARGS += -X -i functional $(ROBOT_DEBUG_LOG_OPT) -v teardown_device:True
system-scale-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULT_PON_FILE)
system-scale-test: voltha-test

failure-test: ROBOT_MISC_ARGS += -X -i FailureTest $(ROBOT_DEBUG_LOG_OPT)
failure-test: ROBOT_FILE := K8S_SystemTest.robot
failure-test: ROBOT_CONFIG_FILE := $(ROBOT_FAIL_SINGLE_PON_FILE)
failure-test: voltha-test

bbsim-alarms-kind: ROBOT_MISC_ARGS += -X -i active
bbsim-alarms-kind: ROBOT_FILE := Voltha_AlarmTests.robot
bbsim-alarms-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-alarms-kind: voltctl-docker-image-build voltctl-docker-image-install-kind voltha-test

bbsim-errorscenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-errorscenarios: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-errorscenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-errorscenarios: voltha-test

bbsim-multiuni-errorscenarios-att: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-multiuni-errorscenarios-att: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-multiuni-errorscenarios-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_SINGLE_PON_FILE)
bbsim-multiuni-errorscenarios-att: voltha-test

bbsim-multiolt-errorscenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-multiolt-errorscenarios: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-multiolt-errorscenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
bbsim-multiolt-errorscenarios: voltha-test

bbsim-multiuni-multiolt-errorscenarios-att: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-multiuni-multiolt-errorscenarios-att: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-multiuni-multiolt-errorscenarios-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_MULTIPLE_OLT_FILE)
bbsim-multiuni-multiolt-errorscenarios-att: voltha-test

bbsim-errorscenarios-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT)
bbsim-errorscenarios-dt: ROBOT_FILE := Voltha_ErrorScenarios.robot
bbsim-errorscenarios-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
bbsim-errorscenarios-dt: voltha-test

bbsim-failurescenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOLTReboot
bbsim-failurescenarios: ROBOT_FILE := Voltha_FailureScenarios.robot
bbsim-failurescenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
bbsim-failurescenarios: voltha-test

bbsim-multiuni-failurescenarios-att: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOLTReboot
bbsim-multiuni-failurescenarios-att: ROBOT_FILE := Voltha_FailureScenarios.robot
bbsim-multiuni-failurescenarios-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_SINGLE_PON_FILE)
bbsim-multiuni-failurescenarios-att: voltha-test

bbsim-multiolt-failurescenarios: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOLTReboot
bbsim-multiolt-failurescenarios: ROBOT_FILE := Voltha_FailureScenarios.robot
bbsim-multiolt-failurescenarios: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
bbsim-multiolt-failurescenarios: voltha-test

bbsim-multiuni-multiolt-failurescenarios-att: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOLTReboot
bbsim-multiuni-multiolt-failurescenarios-att: ROBOT_FILE := Voltha_FailureScenarios.robot
bbsim-multiuni-multiolt-failurescenarios-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTI_UNI_MULTIPLE_OLT_FILE)
bbsim-multiuni-multiolt-failurescenarios-att: voltha-test

bbsim-multiolt-kind: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e MultiOLTPhysicalReboot
bbsim-multiolt-kind: ROBOT_FILE := Voltha_MultiOLT_Tests.robot
bbsim-multiolt-kind: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
bbsim-multiolt-kind: voltha-test

bbsim-multiolt-kind-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e MultiOLTPhysicalRebootDt
bbsim-multiolt-kind-dt: ROBOT_FILE := Voltha_DT_MultiOLT_Tests.robot
bbsim-multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
bbsim-multiolt-kind-dt: voltha-dt-test

multiolt-kind-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -i functionalDt
multiolt-kind-dt: ROBOT_FILE := Voltha_DT_MultiOLT_Tests.robot
multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
multiolt-kind-dt: voltha-dt-test

bbsim-failurescenarios-dt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitchOnuRebootDt -e PhysicalOltRebootDt
bbsim-failurescenarios-dt: ROBOT_FILE := Voltha_DT_FailureScenarios.robot
bbsim-failurescenarios-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
bbsim-failurescenarios-dt: voltha-dt-test

bbsim-failurescenarios-tt: ROBOT_MISC_ARGS += -X $(ROBOT_DEBUG_LOG_OPT) -e PowerSwitch -e PhysicalOltRebootTT -e dataplaneTT
bbsim-failurescenarios-tt: ROBOT_FILE := Voltha_TT_FailureScenarios.robot
bbsim-failurescenarios-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
bbsim-failurescenarios-tt: voltha-tt-test

onos-ha-test: ROBOT_MISC_ARGS +=  -e notready -X $(ROBOT_DEBUG_LOG_OPT)
onos-ha-test: ROBOT_FILE := Voltha_ONOSHATests.robot
onos-ha-test: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
onos-ha-test: voltha-test

voltha-test: ROBOT_MISC_ARGS += -e notready --noncritical non-critical

voltha-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/functional ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

bbsim-dmi-hw-management-test: ROBOT_MISC_ARGS +=  -e notreadyDMI -i functionalDMI -e bbsimUnimplementedDMI
bbsim-dmi-hw-management-test: ROBOT_FILE := dmi-hw-management.robot
bbsim-dmi-hw-management-test: ROBOT_CONFIG_FILE := $(ROBOT_DMI_SINGLE_BBSIM_FILE)
bbsim-dmi-hw-management-test: voltha-dmi-test

voltha-dmi-hw-management-test: ROBOT_MISC_ARGS +=  -e notreadyDMI -i functionalDMI
voltha-dmi-hw-management-test: ROBOT_FILE := dmi-hw-management.robot
voltha-dmi-hw-management-test: ROBOT_CONFIG_FILE := $(ROBOT_DMI_SINGLE_ADTRAN_FILE)
voltha-dmi-hw-management-test: voltha-dmi-test

voltha-dmi-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/dmi-interface ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

# target to invoke single ONU pm data scenarios in ATT workflow
voltha-pm-data-single-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-pm-data-single-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
voltha-pm-data-single-kind-att: voltha-pm-data-tests

# target to invoke single ONU pm data scenarios in DT workflow
voltha-pm-data-single-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT
voltha-pm-data-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
voltha-pm-data-single-kind-dt: voltha-pm-data-tests

# target to invoke single ONU pm data scenarios in TT workflow
voltha-pm-data-single-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT
voltha-pm-data-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
voltha-pm-data-single-kind-tt: voltha-pm-data-tests

# target to invoke multiple OLTs pm data scenarios in ATT workflow
voltha-pm-data-multiolt-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-pm-data-multiolt-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
voltha-pm-data-multiolt-kind-att: voltha-pm-data-tests

# target to invoke multiple OLTs pm data scenarios in DT workflow
voltha-pm-data-multiolt-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT
voltha-pm-data-multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_MULTIPLE_OLT_FILE)
voltha-pm-data-multiolt-kind-dt: voltha-pm-data-tests

# target to invoke multiple OLTs pm data scenarios in TT workflow
voltha-pm-data-multiolt-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT
voltha-pm-data-multiolt-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTIPLE_OLT_FILE)
voltha-pm-data-multiolt-kind-tt: voltha-pm-data-tests

voltha-pm-data-tests: ROBOT_MISC_ARGS += -i functional -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
voltha-pm-data-tests: ROBOT_PM_CONFIG_FILE := $(ROBOT_PM_DATA_FILE)
voltha-pm-data-tests: ROBOT_FILE := Voltha_ONUPMTests.robot
voltha-pm-data-tests: voltha-pm-data-test

voltha-pm-data-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/pm-data ;\
	robot -V $(ROBOT_CONFIG_FILE) -V $(ROBOT_PM_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

# target to invoke single ONU OMCI Get scenarios in ATT workflow
voltha-onu-omci-get-single-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-onu-omci-get-single-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
voltha-onu-omci-get-single-kind-att: voltha-onu-omci-get-tests

# target to invoke single ONU OMCI Get scenarios in DT workflow
voltha-onu-omci-get-single-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT
voltha-onu-omci-get-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
voltha-onu-omci-get-single-kind-dt: voltha-onu-omci-get-tests

# target to invoke single ONU OMCI Get scenarios in TT workflow
voltha-onu-omci-get-single-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT
voltha-onu-omci-get-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
voltha-onu-omci-get-single-kind-tt: voltha-onu-omci-get-tests

# target to invoke multiple OLTs OMCI Get scenarios in ATT workflow
voltha-onu-omci-get-multiolt-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-onu-omci-get-multiolt-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
voltha-onu-omci-get-multiolt-kind-att: voltha-onu-omci-get-tests

# target to invoke multiple OLTs OMCI Get scenarios in DT workflow
voltha-onu-omci-get-multiolt-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT
voltha-onu-omci-get-multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_MULTIPLE_OLT_FILE)
voltha-onu-omci-get-multiolt-kind-dt: voltha-onu-omci-get-tests

# target to invoke multiple OLTs OMCI Get scenarios in TT workflow
voltha-onu-omci-get-multiolt-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT
voltha-onu-omci-get-multiolt-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTIPLE_OLT_FILE)
voltha-onu-omci-get-multiolt-kind-tt: voltha-onu-omci-get-tests

voltha-onu-omci-get-tests: ROBOT_MISC_ARGS += -i functionalOnuGo -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
voltha-onu-omci-get-tests: ROBOT_FILE := Voltha_ONUOmciGetTest.robot
voltha-onu-omci-get-tests: openonu-go-adapter-tests

# target to invoke single ONU Flows Check in ATT workflow
voltha-onu-flows-check-single-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-onu-flows-check-single-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
voltha-onu-flows-check-single-kind-att: voltha-onu-flows-check-tests

# target to invoke single ONU Flows Check scenarios in DT workflow
voltha-onu-flows-check-single-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT -v techprofile:1T8GEM
voltha-onu-flows-check-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
voltha-onu-flows-check-single-kind-dt: voltha-onu-flows-check-tests

# target to invoke single ONU Flows Check scenarios in TT workflow
voltha-onu-flows-check-single-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT -v techprofile:1T4GEM
voltha-onu-flows-check-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
voltha-onu-flows-check-single-kind-tt: voltha-onu-flows-check-tests

# target to invoke multiple OLTs Flows Check scenarios in ATT workflow
voltha-onu-flows-check-multiolt-kind-att: ROBOT_MISC_ARGS += -v workflow:ATT
voltha-onu-flows-check-multiolt-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
voltha-onu-flows-check-multiolt-kind-att: voltha-onu-flows-check-tests

# target to invoke multiple OLTs Flows Check scenarios in DT workflow
voltha-onu-flows-check-multiolt-kind-dt: ROBOT_MISC_ARGS += -v workflow:DT -v techprofile:1T8GEM
voltha-onu-flows-check-multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_MULTIPLE_OLT_FILE)
voltha-onu-flows-check-multiolt-kind-dt: voltha-onu-flows-check-tests

# target to invoke multiple OLTs Flows Check scenarios in TT workflow
voltha-onu-flows-check-multiolt-kind-tt: ROBOT_MISC_ARGS += -v workflow:TT -v techprofile:1T4GEM
voltha-onu-flows-check-multiolt-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTIPLE_OLT_FILE)
voltha-onu-flows-check-multiolt-kind-tt: voltha-onu-flows-check-tests

voltha-onu-flows-check-tests: ROBOT_MISC_ARGS += -i functionalOnuGo -e PowerSwitch $(ROBOT_DEBUG_LOG_OPT)
voltha-onu-flows-check-tests: ROBOT_FILE := Voltha_ONUFlowChecks.robot
voltha-onu-flows-check-tests: openonu-go-adapter-tests

# ONOS Apps to test for Software Upgrade need to be passed in the 'onos_apps_under_test' variable in format:
# <app-name>,<version>,<oar-url>*<app-name>,<version>,<oar-url>*
onos-app-upgrade-test: ROBOT_MISC_ARGS +=  -e notready -i functional
onos-app-upgrade-test: ROBOT_FILE := ONOS_AppsUpgrade.robot
onos-app-upgrade-test: ROBOT_CONFIG_FILE := $(ROBOT_SW_UPGRADE_FILE)
onos-app-upgrade-test: software-upgrade-test

# Voltha Components to test for Software Upgrade need to be passed in the 'voltha_comps_under_test' variable in format:
# <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
voltha-comp-upgrade-test: ROBOT_MISC_ARGS +=  -e notready -i VolthaCompMinorVerUpgrade
voltha-comp-upgrade-test: ROBOT_FILE := Voltha_ComponentsUpgrade.robot
voltha-comp-upgrade-test: ROBOT_CONFIG_FILE := $(ROBOT_SW_UPGRADE_FILE)
voltha-comp-upgrade-test: software-upgrade-test

# Voltha Components to test for Software Upgrade need to be passed in the 'voltha_comps_under_test' variable in format:
# <comp-label>,<comp-container>,<comp-image>*<comp-label>,<comp-container>,<comp-image>*
voltha-comp-rolling-upgrade-test: ROBOT_MISC_ARGS +=  -e notready -i VolthaCompMinorVerRollingUpgrade
voltha-comp-rolling-upgrade-test: ROBOT_FILE := Voltha_ComponentsUpgrade.robot
voltha-comp-rolling-upgrade-test: ROBOT_CONFIG_FILE := $(ROBOT_SW_UPGRADE_FILE)
voltha-comp-rolling-upgrade-test: software-upgrade-test

# Requirement: Pass ONU image details in following parameters
# image_version, image_url, image_vendor, image_activate_on_success, image_commit_on_success, image_crc
onu-upgrade-test: ROBOT_MISC_ARGS +=  -e notready -i functional
onu-upgrade-test: ROBOT_FILE := ONU_Upgrade.robot
onu-upgrade-test: ROBOT_CONFIG_FILE := $(ROBOT_SW_UPGRADE_FILE)
onu-upgrade-test: software-upgrade-test

# Requirement: Pass ONU image details in following parameters
# image_version, image_url, image_vendor, image_activate_on_success, image_commit_on_success, image_crc
onu-upgrade-test-multiolt-kind-att: ROBOT_MISC_ARGS +=  -e notready -i functionalMultipleONUs
onu-upgrade-test-multiolt-kind-att: ROBOT_FILE := ONU_Upgrade.robot
onu-upgrade-test-multiolt-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
onu-upgrade-test-multiolt-kind-att: software-upgrade-test

# Voltha openonu MIB Audit tests att workflow single kind
onu-mib-audit-test-single-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
onu-mib-audit-test-single-kind-att: voltha-onu-mib-audit-tests

# Voltha openonu MIB Audit tests t workflow single kind
onu-mib-audit-test-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
onu-mib-audit-test-single-kind-dt: voltha-onu-mib-audit-tests

# Voltha openonu MIB Audit tests tt workflow single kind
onu-mib-audit-test-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
onu-mib-audit-test-single-kind-tt: voltha-onu-mib-audit-tests

# Voltha openonu MIB Audit tests att workflow multiple OLTs
onu-mib-audit-test-multiolt-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_MULTIPLE_OLT_FILE)
onu-mib-audit-test-multiolt-kind-att: voltha-onu-mib-audit-tests

# Voltha openonu MIB Audit tests tt workflow multiple OLTs
onu-mib-audit-test-multiolt-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_MULTIPLE_OLT_FILE)
onu-mib-audit-test-multiolt-kind-dt: voltha-onu-mib-audit-tests

# Voltha openonu MIB Audit tests tt workflow multiple OLTs
onu-mib-audit-test-multiolt-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTIPLE_OLT_FILE)
onu-mib-audit-test-multiolt-kind-tt: voltha-onu-mib-audit-tests

voltha-onu-mib-audit-tests: ROBOT_MISC_ARGS += -i functional -e notready  --noncritical non-critical
voltha-onu-mib-audit-tests: ROBOT_MISC_ARGS += $(ROBOT_DEBUG_LOG_OPT)
voltha-onu-mib-audit-tests: ROBOT_FILE := Voltha_ONUMibAudit.robot
voltha-onu-mib-audit-tests: openonu-go-adapter-tests

# Voltha Components Memory Leak tests dt workflow 1 OLT 1 PON 2 ONUs
memory-leak-test-single-pon-multi-onu-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_MULTI_ONU_FILE)
memory-leak-test-single-pon-multi-onu-dt: voltha-memory-leak-tests

voltha-memory-leak-tests: ROBOT_MISC_ARGS += -i functionalMemoryLeak -e notready  --noncritical non-critical
voltha-memory-leak-tests: ROBOT_MISC_ARGS += $(ROBOT_DEBUG_LOG_OPT)
voltha-memory-leak-tests: ROBOT_FILE := VOLTHA_Memory_Leak_Tests.robot
voltha-memory-leak-tests: voltha-memory-leak-test

# Voltha openonu robustness tests att workflow
onu-robustness-test-single-kind-att: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_SINGLE_PON_FILE)
onu-robustness-test-single-kind-att: ROBOT_MISC_ARGS += -i functional
onu-robustness-test-single-kind-att: voltha-onu-robustness-tests

# Voltha openonu robustness tests dt workflow
onu-robustness-test-single-kind-dt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_DT_SINGLE_PON_FILE)
onu-robustness-test-single-kind-dt: ROBOT_MISC_ARGS += -i functional
onu-robustness-test-single-kind-dt: voltha-onu-robustness-tests

# Voltha openonu robustness tests tt workflow
onu-robustness-test-single-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_SINGLE_PON_FILE)
onu-robustness-test-single-kind-tt: ROBOT_MISC_ARGS += -i functional
onu-robustness-test-single-kind-tt: voltha-onu-robustness-tests

# Voltha openonu robustness tests multi-uni tt workflow
onu-robustness-test-multi-uni-kind-tt: ROBOT_CONFIG_FILE := $(ROBOT_SANITY_TT_MULTI_UNI_SINGLE_PON_FILE)
onu-robustness-test-multi-uni-kind-tt: ROBOT_MISC_ARGS += -v unitag_sub:True -i functionalMultiUni
onu-robustness-test-multi-uni-kind-tt: voltha-onu-robustness-tests

voltha-onu-robustness-tests: ROBOT_MISC_ARGS += -e notready  --noncritical non-critical
voltha-onu-robustness-tests: ROBOT_MISC_ARGS += $(ROBOT_DEBUG_LOG_OPT)
voltha-onu-robustness-tests: ROBOT_FILE := Voltha_ONUErrorTests.robot
voltha-onu-robustness-tests: openonu-go-adapter-tests

software-upgrade-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/software-upgrades ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-dt-test: ROBOT_MISC_ARGS += -e notready  --noncritical non-critical

voltha-dt-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/dt-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-tt-test: ROBOT_MISC_ARGS += -e notready  --noncritical non-critical

voltha-tt-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/tt-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-tim-test: ROBOT_MISC_ARGS += -e notready  --noncritical non-critical

voltha-tim-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/tim-workflow ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-scale-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/scale ;\
	robot $(ROBOT_MISC_ARGS) Voltha_Scale_Tests.robot

openonu-go-adapter-tests: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/openonu-go-adapter ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-bbf-adapter-test: ROBOT_MISC_ARGS += -e notready  --noncritical non-critical
voltha-bbf-adapter-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/bbf-adapter ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

voltha-memory-leak-test: vst_venv
	source ./$</bin/activate ; set -u ;\
	cd tests/memory-leak ;\
	robot -V $(ROBOT_CONFIG_FILE) $(ROBOT_MISC_ARGS) $(ROBOT_FILE)

# self-test, lint, and setup targets

# -----------------------------------------------------------------------
# virtualenv for the robot tools
# VOL-2724 Invoke pip via python3 to avoid pathname too long on QA jobs
# Verify installation: make lint -or- make test
# vol-4874 - python_310_migration.sh
# -----------------------------------------------------------------------
vst_venv:
	@echo "============================="
	@echo "Installing python virtual env"
	@echo "============================="
	virtualenv -p python3 $@ ;\
	source ./$@/bin/activate ;\
	python -m pip install -r requirements.txt
	@echo
	@echo "========================================"
	@echo "Applying python 3.10.x migration patches"
	@echo "========================================"
	./patches/python_310_migration.sh 'apply'
	@echo

##----------------##
##---]  TEST  [---##
##----------------##
test: lint

# tidy target will be more useful once issue with removing leading comments
# is resolved: https://github.com/robotframework/robotframework/issues/3263
tidy-robot: vst_venv
	source ./$</bin/activate ; set -u ;\
	python -m robot.tidy --inplace $(ROBOT_FILES);

## Variables for gendocs
TEST_SOURCE := $(wildcard tests/*/*.robot)
TEST_BASENAME := $(basename $(TEST_SOURCE))
TEST_DIRS := $(dir $(TEST_SOURCE))

LIB_SOURCE   := $(wildcard libraries/*.robot)
LIB_BASENAME := $(basename $(LIB_SOURCE))
LIB_DIRS     := $(sort $(dir $(LIB_SOURCE)))

.PHONY: gendocs lint test
# In future explore use of --docformat REST - integration w/Sphinx?
gendocs: vst_venv
	$(HIDE)echo " ** $(make) $@: ENTER"
	source ./$</bin/activate \
	&& set -u \
	&& echo \
	&& echo " ** $(make) $@: robot.libdoc" \
	&& mkdir -pv $(addprefix $@/,$(LIB_DIRS)) \
	&& for dir in $(LIB_BASENAME); do\
	    python -m robot.libdoc --format HTML $$dir.robot $@/$$dir.html ;\
	done \
	&& echo \
	&& echo " ** $(make) $@: robot.testdoc" \
	&& mkdir -vp $(addprefix $@/,$(TEST_DIRS)) \
	&& for dir in $(TEST_BASENAME); do\
		python -m robot.testdoc $$dir.robot $@/$$dir.html ;\
	done
	$(HIDE)echo " ** $(make) $@: LEAVE"

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
clean:
	$(RM) -r gendocs
	find . -name output.xml -print # no action performed ?

clean-all sterile: clean
	$(RM) -r vst_venv

## -----------------------------------------------------------------------
## -----------------------------------------------------------------------
voltctl-docker-image-build:
	cd docker && docker build -t opencord/voltctl:local -f Dockerfile.voltctl .

voltctl-docker-image-install-kind:
	@if [ "`kind get clusters | grep kind`" = '' ]; then echo "no kind cluster found" && exit 1; fi
	kind load docker-image --name `kind get clusters | grep kind` opencord/voltctl:local

# [EOF]
