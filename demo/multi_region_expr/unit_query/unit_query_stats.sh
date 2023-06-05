#!/usr/bin/bash
# set -x # for debug

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
echo "# working directory: $(pwd)"

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
TIME_FMT="real %e, user %U, sys %S"

NETWORK="pushed_configs"
SNAPSHOT="mddo_network"

function exec_toolbox () {
  bundle exec mddo-toolbox "$@" 2> /dev/null
}

function exec_toolbox_silent () {
  { $TIME -f "$TIME_FMT" bundle exec mddo-toolbox "$@" > /dev/null; } 2>&1 | tail -n1
}

function toolbox_change_branch () {
  branch=$1
  exec_toolbox change_branch -n "$NETWORK" -b "$branch"
}

function toolbox_generate_topology () {
  exec_toolbox_silent generate_topology -p -n "$NETWORK" -s "$SNAPSHOT"
}

function toolbox_single_snapshot_queries () {
  exec_toolbox_silent query_snapshot -n "$NETWORK" -s "$SNAPSHOT"
}

function toolbox_fetch_topology () {
  exec_toolbox fetch_topology -n "$NETWORK" -s "$SNAPSHOT"
}

function toolbox_reach_test () {
  pattern_file=$1

  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  exec_toolbox_silent test_reachability -s "$SNAPSHOT" -t "$pattern_file"
}

##########
# main

TARGET_CONFIGS_BRANCH=$1
# arg check
if [ -z "$TARGET_CONFIGS_BRANCH" ]; then
  echo "target configs $TARGET_CONFIGS_BRANCH is not specified"
  exit 1
fi

echo "# branch $TARGET_CONFIGS_BRANCH"
toolbox_change_branch "$TARGET_CONFIGS_BRANCH"

echo "## cmd: topology_generate"
toolbox_generate_topology
echo "--- data check"
toolbox_fetch_topology | \
  jq '."ietf-network:networks".network[] | select(."network-id" == "layer3") | .node[] | select(."node-id" | test("^Seg.*\\+$")) | ."node-id"'
echo "---"

echo "## cmd: single_snapshot_queries"
toolbox_single_snapshot_queries

# traceroute pattern defs dir
PATTERN_DIR="${SCRIPT_DIR}/unit_tracert"

echo "## cmd: tracert_neighbor_region"
toolbox_reach_test "${PATTERN_DIR}/neighbor_region.yaml"

echo "## cmd: tracert_facing_region"
case "$TARGET_CONFIGS_BRANCH" in
  "5regiondemo")
    toolbox_reach_test "${PATTERN_DIR}/facing_region_5.yaml"
    ;;
  "10regiondemo")
    toolbox_reach_test "${PATTERN_DIR}/facing_region_10.yaml"
    ;;
  "20regiondemo")
    toolbox_reach_test "${PATTERN_DIR}/facing_region_20.yaml"
    ;;
  "40regiondemo")
    toolbox_reach_test "${PATTERN_DIR}/facing_region_40.yaml"
    ;;
  *)
    toolbox_reach_test "${PATTERN_DIR}/facing_region_2.yaml"
    ;;
esac
