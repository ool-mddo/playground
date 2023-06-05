#!/usr/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
echo "# working directory: $(pwd)"

STATS_LOG_FILE="${SCRIPT_DIR}/unit_query_stats.log"
SUMMARY_LOG_FILE="${SCRIPT_DIR}/unit_query_summary.log"

function exec_docker_compose () {
  # exec at playground dir
  pushd "$SCRIPT_DIR/../../../" || exit 1
  docker compose -f docker-compose.min.yaml "$@"
  popd || exit 1
}

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

# initialize
rm -f "$STATS_LOG_FILE"

for branch in "${branches[@]}"
do
  echo "## compose up"
  exec_docker_compose up -d
  wait_sec 3

  # take stats
  ./unit_query_stats.sh "$branch" 2>&1 | tee -a "$STATS_LOG_FILE"

  echo "## compose down"
  exec_docker_compose down
  wait_sec 3
done

# summary
ruby unit_query_summary.rb < "$STATS_LOG_FILE" | tee "$SUMMARY_LOG_FILE"
gnuplot -c unit_query_summary.gp "$SCRIPT_DIR"
xdg-open unit_query_summary.png
