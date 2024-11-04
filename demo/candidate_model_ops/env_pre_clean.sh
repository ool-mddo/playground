#!/usr/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# cache sudo credential
echo "Please enter your sudo password:"
sudo -v

# delete files (several file was generated in container (root))
sudo rm -f "${USECASE_CONFIGS_DIR}"/*.conf
sudo rm -f "${USECASE_CONFIGS_DIR}"/*.json
sudo rm -f "${USECASE_CONFIGS_DIR}"/*.yaml
sudo rm -f "${ANSIBLE_RUNNER_DIR}/clab"/*.conf
sudo rm -f "${ANSIBLE_RUNNER_DIR}/clab/clab-topo.yaml"
