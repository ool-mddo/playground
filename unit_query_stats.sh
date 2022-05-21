#!/usr/bin/bash

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
TIME_FMT="real %e, user %U, sys %S"

NETWORK="pushed_configs"
SNAPSHOT="mddo_network"
BATFISH_WRAPPER_HOST="batfish-wrapper:5000"
DOCKER_COMPOSE="docker-compose -f docker-compose.yml"
NETOMOX_EXEC="$DOCKER_COMPOSE exec netomox-exp"
NETOMOX_EXEC_REACHTEST="$NETOMOX_EXEC bundle exec ruby exe/mddo_toolbox.rb test_reachability"

function exec_cmd () {
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" $NETOMOX_EXEC "$@"
}

function exec_reach_test () {
  pattern_file=$1
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  $TIME -f "$TIME_FMT" $NETOMOX_EXEC_REACHTEST $pattern_file -n pushed_configs -s "${SNAPSHOT}$" -r
}

##########
# main

# read env vars
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

echo "## cmd: load_snapshot"
exec_cmd bundle exec rake simulation_pattern

echo "## cmd: check_loaded_snapshot"
exec_cmd curl "http://${BATFISH_WRAPPER_HOST}/api/networks/${NETWORK}/snapshots"

echo "## cmd: single_snapshot_queries"
exec_cmd curl -X POST -H "Content-Type: application/json" -d '{}' "http://${BATFISH_WRAPPER_HOST}/api/networks/${NETWORK}/snapshots/${SNAPSHOT}/queries"

echo "## cmd: tracert_neighbor_region"
exec_reach_test exe/neighbor_region.yaml

echo "## cmd: tracert_facing_region"
case "$TARGET_CONFIGS_BRANCH" in
  "5regiondemo")
    exec_reach_test exe/facing_region_5.yaml
    ;;
  "10regiondemo")
    exec_reach_test exe/facing_region_10.yaml
    ;;
  "20regiondemo")
    exec_reach_test exe/facing_region_20.yaml
    ;;
  "40regiondemo")
    exec_reach_test exe/facing_region_40.yaml
    ;;
  *)
    exec_reach_test exe/facing_region_2.yaml
    ;;
esac
