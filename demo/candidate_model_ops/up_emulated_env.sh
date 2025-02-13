#!/usr/bin/bash

# shellcheck disable=SC1091
source ./util.sh

function up_emulated_env() {
  original_topology=$1
  emulated_topology=$(reverse_snapshot_name "$original_topology")
  worker_node_address=$2

  echo "Target original snapshot: $original_topology"

  #############
  # pre-clean #
  #############
  sudo bash env_pre_clean.sh

  ######################
  # configuration part #
  ######################

  # convert namespace from original to emulated
  convert_namespace "$original_topology"
  echo "target :; $target_emulated_snapshot "
  # generate emulated_candidate configs from emulated_candidate topology
  # generate emulated_candidate environment from emulated_candidate topology/configs
  curl -H 'Content-Type: application/json' -d "{\"message\": \"step2\" ,\"ansible_runner_dir\":\"${ANSIBLE_RUNNER_DIR}\",\"crpd_image\":\"${CRPD_IMAGE}\",\"network_name\":\"${NETWORK_NAME}\", \"usecase_name\": \"${USECASE_NAME}\", \"worker_node_address\": \"${worker_node_address}\", \"remote_address\": \"${CONTROLLER_ADDRESS}\", \"snapshot_name\":\"${emulated_topology}\"}" localhost:48081/endpoint


  while :; do
    echo ${worker_node_address}
    msg=`curl -s http://${worker_node_address}:9100/metrics | grep job`
    echo $msg
    breakjudge=`echo $msg | grep AllJob_Complete | grep '} 1' | wc -l`
    [[ $breakjudge -eq 1 ]] && break
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
  curl -s -X GET "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${emulated_topology}/state" \
    | tee "$state_json"

  ##############
  # post-clean #
  ##############
  echo "destroy ${emulated_topology} on $2"
  bash env_post_clean.sh ${emulated_topology} $2
}

