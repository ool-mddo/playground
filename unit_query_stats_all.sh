#!/usr/bin/bash

DOCKER_COMPOSE="docker-compose -f docker-compose.yml"
COMPOSE_UP="$DOCKER_COMPOSE up -d"
COMPOSE_DOWN="$DOCKER_COMPOSE down"
STATS_LOG_FILE=unit_query_stats.log
SUMMARY_LOG_FILE=unit_query_summary.log

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

rm -f $STATS_LOG_FILE
for branch in "${branches[@]}"
do
  echo "## compose up"
  $COMPOSE_UP
  wait_sec 3

  # take stats
  ./unit_query_stats.sh "$branch" 2>&1 | tee -a $STATS_LOG_FILE

  echo "## compose down"
  $COMPOSE_DOWN
  wait_sec 3
done

# summary
ruby unit_query_summary.rb < "$STATS_LOG_FILE" | tee $SUMMARY_LOG_FILE
gnuplot unit_query_summary.gp
