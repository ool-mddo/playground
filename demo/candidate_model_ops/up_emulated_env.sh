#!/usr/bin/bash

function up_emulated_env() {
  target_original_snapshot=$1
  echo "Target original snapshot: $target_original_snapshot"

  ######################
  # configuration part #
  ######################

  # convert namespace from original to emulated
  target_emulated_snapshot="${target_original_snapshot/original/emulated}"
  echo "Convert from:$target_original_snapshot to:$target_emulated_snapshot"
  curl -s -X POST -H 'Content-Type: application/json' \
    -d '{ "table_origin": "'"$target_original_snapshot"'" }' \
    "http://${API_PROXY}/conduct/${NETWORK_NAME}/ns_convert/original_asis/${target_emulated_snapshot}"

  # generate emulated_candidate configs from emulated_candidate topology
  echo "Exec ansible to generate $target_emulated_snapshot configs"
  # ansible-runner run . -p /data/project/playbooks/step2-1.yaml \
  #   --container-option="--net=${API_BRIDGE}" \
  #   --container-image="${ANSIBLE_RUNNER_IMAGE}" \
  #   --container-volume-mount="$PWD:/data" \
  #   --process-isolation \
  #   --process-isolation-executable docker \
  #   --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
  #             -e login_user=${LOCALSERVER_USER} \
  #             -e network_name=${NETWORK_NAME} \
  #             -e crpd_image=${CRPD_IMAGE} \
  #             -e with_clab=${WITH_CLAB} \
  #             -k -K"

  # generate emulated_candidate environment from emulated_candidate topology/configs
  echo "# TODO: exec ansible to generate $target_emulated_snapshot clab env"
  # ansible-runner run . -p "/data/project/playbooks/step2-2.yaml" \
  #   --container-option="--net=${API_BRIDGE}" \
  #   --container-image="${ANSIBLE_RUNNER_IMAGE}" \
  #   --container-volume-mount="$PWD:/data" \
  #   --process-isolation \
  #   --process-isolation-executable docker \
  #   --cmdline "-e ansible_runner_dir=${ANSIBLE_RUNNER_DIR} \
  #             -e login_user=${LOCALSERVER_USER} \
  #             -e network_name=${NETWORK_NAME} \
  #             -e usecase_name=${USECASE_NAME} \
  #             -e usecase_common_name=${USECASE_COMMON_NAME} \
  #             -e with_clab=${WITH_CLAB} \
  #             -e clab_restart=${CLAB_RESTART} \
  #             -k -K"

  ###############
  # satate part #
  ###############

  # set network name into namespace-relabeler
  echo "# TODO: push network/snapshot info into namespace-relabeler"
  # curl -s -X POST -H 'Content-Type: application/json' \
  #   -d '{"network_name": "'"$NETWORK_NAME"'"}' \
  #   http://localhost:15000/relabel/network


  ############
  # clean-up #
  ############
  sudo ./demo_remove.sh
}
