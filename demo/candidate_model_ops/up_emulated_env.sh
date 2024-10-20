#!/usr/bin/bash

# shellcheck disable=SC1091
source ./util.sh

function up_emulated_env() {
  original_topology=$1
  emulated_topology=$(reverse_snapshot_name "$original_topology")

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

  # generate emulated_candidate configs from emulated_candidate topology
  echo "Exec ansible to generate $emulated_topology configs"
  ansible-runner run . -p /data/project/playbooks/step2-1.yaml \
    --container-option="--net=${API_BRIDGE}" \
    --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --container-volume-mount="$PWD:/data" \
    --process-isolation \
    --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
              -e login_user=${LOCALSERVER_USER} \
              -e network_name=${NETWORK_NAME} \
              -e snapshot_name=${emulated_topology} \
              -e crpd_image=${CRPD_IMAGE} \
              -e with_clab=${WITH_CLAB} \
              -k -K"

  # generate emulated_candidate environment from emulated_candidate topology/configs
  echo "# Exec ansible to generate $emulated_topology clab env"
  ansible-runner run . -p "/data/project/playbooks/step2-2.yaml" \
    --container-option="--net=${API_BRIDGE}" \
    --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --container-volume-mount="$PWD:/data" \
    --process-isolation \
    --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
              -e login_user=${LOCALSERVER_USER} \
              -e network_name=${NETWORK_NAME} \
              -e snapshot_name=${emulated_topology} \
              -e usecase_name=${USECASE_NAME} \
              -e with_clab=${WITH_CLAB} \
              -e clab_restart=false \
              -k -K"

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
  sudo bash env_post_clean.sh
}
