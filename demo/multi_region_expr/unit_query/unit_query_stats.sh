#!/usr/bin/bash
# set -x # for debug

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
# work in playground directory (parent of the script directory)
cd "${SCRIPT_DIR}/../../../" || exit
echo "# working directory: $(pwd)"

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
TIME_FMT="real %e, user %U, sys %S"

NETWORK="pushed_configs"
SNAPSHOT="mddo_network"
REST_HEADER="Content-Type: application/json"
API_PROXY_URL="http://localhost:15000"
CONDUCT_TOPO_URL="${API_PROXY_URL}/conduct/${NETWORK}/${SNAPSHOT}/topology"
CONDUCT_REACH_URL="${API_PROXY_URL}/conduct/${NETWORK}/reachability"
QUERIES_URL="${API_PROXY_URL}/queries/${NETWORK}/${SNAPSHOT}"
TOPOLOGIES_URL="${API_PROXY_URL}/topologies/${NETWORK}/${SNAPSHOT}/topology"
POST_OPTS="${SCRIPT_DIR}/post_opts.json"

function exec_cmd () {
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" "$@"
}

function exec_reach_test () {
  pattern_file=$1
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" curl -s -X POST -H "$REST_HEADER" -d @"$pattern_file" "$CONDUCT_REACH_URL" > /dev/null
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
exec_cmd curl -s -X POST -H "$REST_HEADER" -d @"$POST_OPTS" "$CONDUCT_TOPO_URL" > /dev/null
echo "--- data check"
curl -s "$TOPOLOGIES_URL" | \
  jq '."topology_data"' | \
  jq '."ietf-network:networks".network[] | select(."network-id" == "layer3") | .node[] | select(."node-id" | test("^Seg.*\\+$")) | ."node-id"'
echo "---"

echo "## cmd: single_snapshot_queries"
exec_cmd curl -s -X POST -H "$REST_HEADER" -d '{}' "$QUERIES_URL" > /dev/null

# traceroute pattern defs dir
PATTERN_DIR="${SCRIPT_DIR}/unit_tracert"

echo "## cmd: tracert_neighbor_region"
exec_reach_test "${PATTERN_DIR}/neighbor_region.json"

echo "## cmd: tracert_facing_region"
case "$TARGET_CONFIGS_BRANCH" in
  "5regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_5.json"
    ;;
  "10regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_10.json"
    ;;
  "20regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_20.json"
    ;;
  "40regiondemo")
    exec_reach_test "${PATTERN_DIR}/facing_region_40.json"
    ;;
  *)
    exec_reach_test "${PATTERN_DIR}/facing_region_2.json"
    ;;
esac
