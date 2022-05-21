#!/usr/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
echo "# script directory: $SCRIPT_DIR}"
# work in playground directory (parent of the script directory)
cd "${SCRIPT_DIR}/.." || exit
echo "# working directory: $(pwd)"

TARGET_CONFIGS_BRANCH=$1
STATS_LOG="docker_stats"
STATS_LOG_DIR_NAME="${STATS_LOG}_${TARGET_CONFIGS_BRANCH}_$(date +%s)"
STATS_LOG_DIR="${SCRIPT_DIR}/${STATS_LOG_DIR_NAME}"
STATS_LOG_FILE="${STATS_LOG_DIR}/stats.log"
EXEC_LOG_FILE="${STATS_LOG_DIR}/exec.log"

TIME=/usr/bin/time # use GNU-time instead of bash-built-in-time
NETWORK="pushed_configs"
EXEC_NETOMOX="docker-compose -f docker-compose.yml exec netomox-exp"
TIME_FMT="real %e, user %U, sys %S"
BE_RAKE="bundle exec rake"
RAKE_TASKS="model_dirs simulation_pattern snapshot_to_model netoviz_index netoviz_model netoviz_layout netomox_diff"
# RAKE_TASKS="model_dirs"
LOGGING_DELAY=5 # sec

function epoch () {
  date +"%s.%3N" # milliseconds
}

function exec_log () {
  message=$1
  echo "$message" | tee -a "$EXEC_LOG_FILE"
}

function exec_rake_task () {
  task=$1
  exec_log "BEGIN TASK: $task, $(epoch)"
  # for time command arguments expansion: without variable quoting
  # shellcheck disable=SC2086
  task_time=$( { $TIME -f "$TIME_FMT" $EXEC_NETOMOX $BE_RAKE $task NETWORK=$NETWORK > /dev/null; } 2>&1 )
  exec_log "END TASK: $task, $(epoch), $task_time"
}

##########
## main

# arg check
if [ -z "$TARGET_CONFIGS_BRANCH" ]; then
  echo "target configs branch is not specified"
  exit 1
fi

# read env vars
source .env

# check target config branch
pushd .
cd "${SHARED_CONFIGS_DIR}/${NETWORK}" || exit 1
current_configs_branch=$(git branch --show-current)
if [ "$current_configs_branch" != "$TARGET_CONFIGS_BRANCH" ]; then
  git switch "$TARGET_CONFIGS_BRANCH"
fi
popd || exit 1

# prepare log directory
mkdir -p "$STATS_LOG_DIR"

# start docker stats log (in background)
"${SCRIPT_DIR}/docker_stats.sh" > "$STATS_LOG_FILE" &
pid=$!
exec_log "BEGIN LOGGING: $STATS_LOG_FILE, $(epoch)"
sleep $LOGGING_DELAY

# start tasks
exec_log "BEGIN CONFIGS: $TARGET_CONFIGS_BRANCH, $(epoch) "
for rake_task in $RAKE_TASKS; do
  exec_rake_task "$rake_task"
done
exec_log "END CONFIGS: $TARGET_CONFIGS_BRANCH, $(epoch)"

# stop docker stats log
sleep $LOGGING_DELAY
kill $pid
exec_log "END LOGGING: $STATS_LOG_FILE, $(epoch)"

# backup generated topology files
tar czf models.tar.gz "$SHARED_MODELS_DIR"
mv models.tar.gz "$STATS_LOG_DIR"
tar czf topologies.tar.gz "$SHARED_NETOVIZ_MODEL_DIR"
mv topologies.tar.gz "$STATS_LOG_DIR"

# parse stats log
ruby "${SCRIPT_DIR}/docker_stats.rb" --dir "$STATS_LOG_DIR" --datafile

# check stats graph
gnuplot -c "${SCRIPT_DIR}/docker_stats.gp" "$STATS_LOG_DIR"
xdg-open "${STATS_LOG_DIR}/graph.png"
