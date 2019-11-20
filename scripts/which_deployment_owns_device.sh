#!/bin/bash
# Copyright 2019 Ciena Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DEVICE_ID=$1

BEST_DATE=
BEST_DEPLOY=
for DEPLOY in $(kubectl -n voltha get deploy -o 'jsonpath={.items[*].metadata.name}'); do
    if [[ "$DEPLOY" =~ voltha-rw-core-.* ]]; then
        FOUND=$(kubectl -n voltha logs "deploy/$DEPLOY" 2>/dev/null | grep "$DEVICE_ID" | grep -i ownedbyme | tail -1)
        if [ ! -z "$FOUND" ]; then
            OWNED=$(echo "$FOUND" | grep '"owned":true')
            if [ ! -z "$OWNED" ]; then
                CUR_DATE=$(echo "$OWNED" | jq -r .ts)
                CUR_DEPLOY=$DEPLOY
                if [ -z "$BEST_DEPLOY" ]; then
                    BEST_DATE=$CUR_DATE
                    BEST_DEPLOY=$CUR_DEPLOY
                elif [[ "$CUR_DATE" > "$BEST_DATE" ]]; then
                    BEST_DATE=$CUR_DATE
                    BEST_DEPLOY=$CUR_DEPLOY
                fi
            fi
        fi
    fi
done
if [ -z "$BEST_DEPLOY" ]; then
    exit 1
fi
echo "$BEST_DEPLOY"
