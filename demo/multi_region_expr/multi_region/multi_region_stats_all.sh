#!/usr/bin/bash
# set -x # for debug

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
echo "# working directory: $(pwd)"

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

branch_length="${#branches[@]}"
index=1

for branch in "${branches[@]}"
do
  echo "# branch $branch ($index/$branch_length branches)"
  echo "## compose up"
  exec_docker_compose up -d
  wait_sec 5

  echo "## exec and collect for $branch"
  ./multi_region_stats.sh "$branch"
  wait_sec 5

  echo "## compose down"
  exec_docker_compose down
  wait_sec 5

  index=$(("$index" + 1))
done

# `ls` for time-stamp based sorting
# shellcheck disable=SC2010
ls -1tr "$SCRIPT_DIR" | grep docker_stats_ | tail -n "$branch_length" |\
  xargs ruby multi_region_summary.rb > multi_region_summary.dat
gnuplot -c multi_region_summary.gp "$SCRIPT_DIR"
xdg-open multi_region_summary.png
