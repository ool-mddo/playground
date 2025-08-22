#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars
# shellcheck disable=SC1091
source ./util.sh

function up_emulated_env() {
  original_topology=$1
  emulated_topology=$(reverse_snapshot_name "$original_topology")
  worker_node_address=$2

  echo "Target original snapshot: $original_topology"
  echo "Target emulated snapshot: $emulated_topology"

  ######################
  # configuration part #
  ######################

  # convert namespace from original to emulated
  convert_namespace "$original_topology"

  # generate emulated_candidate configs from emulated_candidate topology
  # generate emulated_candidate environment from emulated_candidate topology/configs
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{
          "message": "controller",
          "crpd_image": "'"$CRPD_IMAGE"'",
          "endpoint_image": "'"$ENDPOINT_IMAGE"'",
          "worker_port": "'"$WORKER_PORT"'",
          "network_name": "'"$NETWORK_NAME"'",
          "usecase_name": "'"$USECASE_NAME"'",
          "worker_node_address": "'"$worker_node_address"'",
          "remote_address": "'"$CONTROLLER_ADDRESS"'",
          "snapshot_name": "'"$emulated_topology"'"
        }' \
    "http://${ANSIBLE_EDA}/endpoint"

  while :; do
    echo "worker_node_address: $worker_node_address"
    msg=$(curl -s "http://${worker_node_address}:${NODE_EXPORTER_PORT}/metrics" | grep job)
    echo "message: $msg"
    break_judge=$(echo "$msg" | grep AllJob_Complete | grep -c '} 1')
    [[ $break_judge -eq 1 ]] && break
    sleep 5
  done

  ###############
  # state part #
  ###############

  if [ "$WITH_CLAB" != true ]; then
    echo "# skip state measurement of the emulated environment, because WITH_CLAB=$WITH_CLAB"
    return 0
  fi

  # NOTE: will be rewrited codes that routers are ready to use
  # wait to boot environment
  echo # newline
  echo "Wait env:${NETWORK_NAME}/${emulated_topology} be ready..."
  sleep 90s

  # begin measurement
  echo "begin measurement"
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{ "action": "begin" }' \
    "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${emulated_topology}/sampling"

  # keep traffic
  echo "keep measurement"
  sleep 90s

  # end measurement
  echo "end measurement"
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{ "action": "end" }' \
    "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${emulated_topology}/sampling"

  # get environment state
  echo "Result state of env:${NETWORK_NAME}/${emulated_topology}"
  state_json="${USECASE_SESSION_DIR}/state_${emulated_topology}.json"
  curl -s -X GET "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${emulated_topology}/state" |
    tee "$state_json"

  ##############
  # post-clean #
  ##############
  echo "destroy $emulated_topology on $worker_node_address"
  bash env_post_clean.sh "$emulated_topology" "$worker_node_address"
  while :; do
    echo "worker_node_address: $worker_node_address"
    msg=$(curl -s "http://${worker_node_address}:${NODE_EXPORTER_PORT}/metrics" | grep job)
    echo "message: $msg"
    break_judge=$(echo "$msg" | grep DestroyJob_Complete | grep -c '} 1')
    [[ $break_judge -eq 1 ]] && break
    sleep 5
  done
}

