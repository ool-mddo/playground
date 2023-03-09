#!/usr/bin/bash
# set -x # for debug

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
# work in playground directory (parent of the script directory)
cd "${SCRIPT_DIR}/../../" || exit
echo "# working directory: $(pwd)"

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
TIME_FMT="real %e, user %U, sys %S"

NETWORK="pushed_configs"
SNAPSHOT="mddo_network"
REST_HEADER="Content-Type: application/json"
REST_MODEL_CONDUCTOR="http://localhost:15000/model-conductor"
REST_QUERIES="http://localhost:15000/queries"
REST_TOPOLOGIES="http://localhost:15000/topologies"
MODEL_INFO="${SCRIPT_DIR}/model_info_phy.json"

function exec_cmd () {
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" "$@"
}

function exec_reach_test () {
  pattern_file=$1
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" curl -s -X POST -H "$REST_HEADER" -d @"$pattern_file" \
    "${REST_MODEL_CONDUCTOR}/reach_test" > /dev/null
}

##########
# main

# read env vars
# shellcheck disable=SC1091
source .env

TARGET_CONFIGS_BRANCH=$1
# arg check
if [ -z "$TARGET_CONFIGS_BRANCH" ]; then
  echo "target configs $TARGET_CONFIGS_BRANCH is not specified"
  exit 1
fi

echo "# branch $TARGET_CONFIGS_BRANCH"
# check target config branch
pushd .
cd "${SHARED_CONFIGS_DIR}/${NETWORK}" || exit 1
current_configs_branch=$(git branch --show-current)
if [ "$current_configs_branch" != "$TARGET_CONFIGS_BRANCH" ]; then
  pwd
  echo git switch "$TARGET_CONFIGS_BRANCH"
  git switch "$TARGET_CONFIGS_BRANCH"
fi
popd || exit 1

echo "## cmd: topology_generate"
exec_cmd curl -s -X POST -H "$REST_HEADER" -d @"$MODEL_INFO" "${REST_MODEL_CONDUCTOR}/generate-topology" > /dev/null
echo "--- data check"
curl -s "${REST_TOPOLOGIES}/${NETWORK}/${SNAPSHOT}/topology" | \
  jq '."topology_data"' | \
  jq '."ietf-network:networks".network[] | select(."network-id" == "layer3") | .node[] | select(."node-id" | test("^Seg.*\\+$")) | ."node-id"'
echo "---"

echo "## cmd: single_snapshot_queries"
exec_cmd curl -s -X POST -H "$REST_HEADER" -d '{}' "${REST_QUERIES}/${NETWORK}/${SNAPSHOT}" > /dev/null

# traceroute pattern defs dir
PATTERN_DIR="${SCRIPT_DIR}/unit_tracert"

echo "## cmd: tracert_neighbor_region"
exec_reach_test "${PATTERN_DIR}/neighbor_region.yaml"

echo "## cmd: tracert_facing_region"
case "$TARGET_CONFIGS_BRANCH" in
  "5regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_5.yaml"
    ;;
  "10regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_10.yaml"
    ;;
  "20regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_20.yaml"
    ;;
  "40regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_40.yaml"
    ;;
  *)
    exec_reach_test "${PATTERN_DIR}/facing_region_2.yaml"
    ;;
esac
