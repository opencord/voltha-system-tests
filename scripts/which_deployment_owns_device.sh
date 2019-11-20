#!/bin/bash
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
