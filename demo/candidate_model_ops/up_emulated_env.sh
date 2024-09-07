#!/usr/bin/bash

function convert_namespace() {
  target_original_snapshot=$1
  target_emulated_snapshot="${target_original_snapshot/original/emulated}"

  echo "Convert namespace from:$target_original_snapshot to:$target_emulated_snapshot"

  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "table_origin": "'"$target_original_snapshot"'" }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/${target_original_snapshot}/${target_emulated_snapshot}"

  echo # newline
}

function up_emulated_env() {
  target_original_snapshot=$1
  target_emulated_snapshot="${target_original_snapshot/original/emulated}"

  echo "Target original snapshot: $target_original_snapshot"

  #############
  # pre-clean #
  #############
  sudo ./pre_clean.sh

  ######################
  # configuration part #
  ######################

  # convert namespace from original to emulated
  convert_namespace "$target_original_snapshot"

  # generate emulated_candidate configs from emulated_candidate topology
  echo "Exec ansible to generate $target_emulated_snapshot configs"
  ansible-runner run . -p /data/project/playbooks/step2-1.yaml \
    --container-option="--net=${API_BRIDGE}" \
    --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --container-volume-mount="$PWD:/data" \
    --process-isolation \
    --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
              -e login_user=${LOCALSERVER_USER} \
              -e network_name=${NETWORK_NAME} \
              -e snapshot_name=${target_emulated_snapshot} \
              -e crpd_image=${CRPD_IMAGE} \
              -e with_clab=${WITH_CLAB} \
              -k -K"

  # generate emulated_candidate environment from emulated_candidate topology/configs
  echo "# Exec ansible to generate $target_emulated_snapshot clab env"
  ansible-runner run . -p "/data/project/playbooks/step2-2.yaml" \
    --container-option="--net=${API_BRIDGE}" \
    --container-image="${ANSIBLE_RUNNER_IMAGE}" \
    --container-volume-mount="$PWD:/data" \
    --process-isolation \
    --process-isolation-executable docker \
    --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
              -e login_user=${LOCALSERVER_USER} \
              -e network_name=${NETWORK_NAME} \
              -e snapshot_name=${target_emulated_snapshot} \
              -e usecase_name=${USECASE_NAME} \
              -e usecase_common_name=${USECASE_COMMON_NAME} \
              -e with_clab=${WITH_CLAB} \
              -e clab_restart=false \
              -k -K"

  ###############
  # state part #
  ###############

  # set network name into namespace-relabeler
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{"network_name": "'"$NETWORK_NAME"'"}' \
    http://localhost:15000/relabel/network

  # NOTE: will be rewrited codes that routers are ready to use
  # wait to boot environment
  echo # newline
  echo "Wait env:${NETWORK_NAME}/${target_emulated_snapshot} be ready..."
  sleep 60

  # begin measurement
  echo "begin measurement"
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{ "action": "begin" }' \
    "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${target_emulated_snapshot}/sampling"

  # keep traffic
  echo "keep measurement"
  sleep 60s

  # end measurement
  echo "end measurement"
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{ "action": "end" }' \
    "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${target_emulated_snapshot}/sampling"

  # get environment state
  echo "Result state of env:${NETWORK_NAME}/${target_emulated_snapshot}"
  state_json="${USECASE_SESSION_DIR}/state_${target_emulated_snapshot}.json"
  curl -s -X GET "http://${API_PROXY}/state-conductor/environment/${NETWORK_NAME}/${target_emulated_snapshot}/state" \
    | tee "$state_json"

  ##############
  # post-clean #
  ##############
  sudo ./post_clean.sh
}
