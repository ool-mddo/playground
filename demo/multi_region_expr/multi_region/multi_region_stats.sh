#!/usr/bin/bash
# set -x # for debug

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
PLAYGROUND_DIR="$SCRIPT_DIR/../../../"
echo "# working directory: $(pwd)"

TARGET_CONFIGS_BRANCH=$1
STATS_LOG="docker_stats"
STATS_LOG_DIR_NAME="${STATS_LOG}_${TARGET_CONFIGS_BRANCH}_$(date +%s)"
STATS_LOG_DIR="${SCRIPT_DIR}/${STATS_LOG_DIR_NAME}"
STATS_LOG_FILE="${STATS_LOG_DIR}/stats.log"
EXEC_LOG_FILE="${STATS_LOG_DIR}/exec.log"

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
NETWORK="pushed_configs"
SNAPSHOT="mddo_network"
TIME_FMT="real %e, user %U, sys %S"
LOGGING_DELAY=5 # sec

function epoch () {
  date +"%s.%3N" # milliseconds
}

function exec_log () {
  message=$1
  echo "$message" | tee -a "$EXEC_LOG_FILE"
}

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
  task="generate_topology"

  exec_log "BEGIN TASK: $task, $(epoch)"
  task_time=$( exec_toolbox_silent generate_topology -n "$NETWORK" -s "$SNAPSHOT" )
  exec_log "END TASK: $task, $(epoch), $task_time"
}

function backup_data () {
  pushd "$PLAYGROUND_DIR" || exit 1
  # import SHARED_{QUERIES|TOPOLOGIES}_DIR to backup generated data
  source .env

  tar czf queries.tar.gz "$SHARED_QUERIES_DIR"
  mv queries.tar.gz "$STATS_LOG_DIR"
  tar czf topologies.tar.gz "$SHARED_TOPOLOGIES_DIR"
  mv topologies.tar.gz "$STATS_LOG_DIR"
  popd || exit 1
}

function exec_docker_compose () {
  pushd "$PLAYGROUND_DIR" || exit 1
  docker compose -f docker-compose.min.yaml "$@"
  popd || exit 1
}

##########
## main

# arg check
if [ -z "$TARGET_CONFIGS_BRANCH" ]; then
  echo "target configs branch is not specified"
  exit 1
fi

# check target config branch
toolbox_change_branch "$TARGET_CONFIGS_BRANCH"

# prepare log directory
mkdir -p "$STATS_LOG_DIR"

# start docker stats log (in background)
./docker_stats.sh > "$STATS_LOG_FILE" &
pid=$!
exec_log "BEGIN LOGGING: $STATS_LOG_FILE, $(epoch)"
sleep $LOGGING_DELAY

# start tasks
exec_log "BEGIN CONFIGS: $TARGET_CONFIGS_BRANCH, $(epoch) "
toolbox_generate_topology
exec_log "END CONFIGS: $TARGET_CONFIGS_BRANCH, $(epoch)"

# stop docker stats log
sleep $LOGGING_DELAY
kill $pid
exec_log "END LOGGING: $STATS_LOG_FILE, $(epoch)"

# backup generated topology files
backup_data

# parse stats log
ruby docker_stats.rb --dir "$STATS_LOG_DIR" --datafile

# docker logs
exec_docker_compose logs > "${STATS_LOG_DIR}/docker.log"

# check stats graph
gnuplot -c docker_stats.gp "$STATS_LOG_DIR"
xdg-open "${STATS_LOG_DIR}/graph.png"
