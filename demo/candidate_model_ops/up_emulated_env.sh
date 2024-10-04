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
  curl -H 'Content-Type: application/json' -d "{\"message\": \"step2\",\"ansible_runner_dir\":\"${ANSIBLE_RUNNER_DIR}\",\"crpd_image\":\"${CRPD_IMAGE}\",\"network_name\":\"${NETWORK_NAME}\", \"usecase_name\": \"${USECASE_NAME}\"}" localhost:48081/endpoint

  echo "wait deploy"
  sleep 60s
  #            -e login_user=${LOCALSERVER_USER} \
  #            -e network_name=${NETWORK_NAME} \
  #            -e snapshot_name=${target_emulated_snapshot} \
  #            -e usecase_name=${USECASE_NAME} \
  #            -e usecase_common_name=${USECASE_COMMON_NAME} \
  #            -e with_clab=${WITH_CLAB} \
}
