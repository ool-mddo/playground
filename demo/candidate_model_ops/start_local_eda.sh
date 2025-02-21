#!/bin/bash

# stop ansible-eda if running
# shellcheck disable=SC2009
eda_pid=$(ps -ef | grep /eda/rulebook.yaml | grep -v grep | awk '{print $2}')
if [ -n "$eda_pid" ]; then
  sudo kill -9 "$eda_pid"
fi

echo 'job_status{jobname="",network_name="",snapshot_name=""} 0' > ./node_exporter/prom/textfile.prom
sudo docker compose -f node_exporter/docker-compose.yaml up -d
sudo ansible-rulebook -i ../../ansible-eda/hosts --rulebook ../../ansible-eda/containerlab_rulebook.yaml -vvvv
