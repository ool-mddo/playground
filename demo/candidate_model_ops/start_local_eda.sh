#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

echo ${ANSIBLE_EDA_CLAB}
# stop ansible-eda if running
eda_pid=$(ps -ef | grep /eda/rulebook.yaml | grep -v grep | awk '{print $2}')
if [ -n "$eda_pid" ]; then
  curl -H "Content-Type: application/json" \
    -d '{
          "message": "shutdown"
        }' \
    "http://${ANSIBLE_EDA_CLAB}/endpoint"
fi



echo 'job_status{jobname="",network_name="",snapshot_name=""} 0' > ./node_exporter/prom/textfile.prom
docker compose -f node_exporter/docker-compose.yaml up -d
ansible-rulebook -i ../../ansible-eda/hosts --rulebook ../../ansible-eda/containerlab_rulebook.yaml -vvvv
