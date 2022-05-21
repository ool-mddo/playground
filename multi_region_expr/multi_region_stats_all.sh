#!/usr/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
echo "# script directory: $SCRIPT_DIR}"
# work in playground directory (parent of the script directory)
cd "${SCRIPT_DIR}/.." || exit
echo "# working directory: $(pwd)"

DOCKER_COMPOSE="docker-compose -f docker-compose.yml"
COMPOSE_UP="$DOCKER_COMPOSE up -d"
COMPOSE_DOWN="$DOCKER_COMPOSE down"

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
branch_length="${#branches[@]}"
index=1

for branch in "${branches[@]}"
do
  echo "# branch $branch ($index/$branch_length branches)"
  echo "## compose up"
  $COMPOSE_UP
  wait_sec 5

  echo "## exec and collect for $branch"
  "${SCRIPT_DIR}/multi_region_stats.sh" "$branch"
  wait_sec 5

  echo "## compose down"
  $COMPOSE_DOWN
  wait_sec 5

  index=$(("$index" + 1))
done

# `ls` for time-stamp based sorting
# shellcheck disable=SC2010
ls -1tr "$SCRIPT_DIR" | grep docker_stats_ | tail -n "$branch_length" |\
  xargs ruby "${SCRIPT_DIR}/multi_region_summary.rb" > "${SCRIPT_DIR}/multi_region_summary.dat"
gnuplot -c "${SCRIPT_DIR}/multi_region_summary.gp" "$SCRIPT_DIR"
xdg-open "${SCRIPT_DIR}/multi_region_summary.png"
