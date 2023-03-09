#!/usr/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
# work in playground directory (parent of the script directory)
cd "${SCRIPT_DIR}/../../" || exit
echo "# working directory: $(pwd)"

DOCKER_COMPOSE="docker compose -f docker-compose.min.yaml"
COMPOSE_UP="$DOCKER_COMPOSE up -d"
COMPOSE_DOWN="$DOCKER_COMPOSE down"
STATS_LOG_FILE="${SCRIPT_DIR}/unit_query_stats.log"
SUMMARY_LOG_FILE="${SCRIPT_DIR}/unit_query_summary.log"

function wait_sec () {
  sec=$1
  echo "## wait $sec sec"
  for sec in $(seq 1 "$sec" | sort -nr)
  do
    printf "waiting... %d\r" "$sec"
    sleep 1
  done
}

##########
# main

branches=("202202demo" "5regiondemo" "10regiondemo" "20regiondemo" "40regiondemo")

rm -f "$STATS_LOG_FILE"
for branch in "${branches[@]}"
do
  echo "## compose up"
  $COMPOSE_UP
  wait_sec 3

  # take stats
  "${SCRIPT_DIR}/unit_query_stats.sh" "$branch" 2>&1 | tee -a "$STATS_LOG_FILE"

  echo "## compose down"
  $COMPOSE_DOWN
  wait_sec 3
done

# summary
ruby "${SCRIPT_DIR}/unit_query_summary.rb" < "$STATS_LOG_FILE" | tee "$SUMMARY_LOG_FILE"
gnuplot -c "${SCRIPT_DIR}/unit_query_summary.gp" "$SCRIPT_DIR"
xdg-open "${SCRIPT_DIR}/unit_query_summary.png"
