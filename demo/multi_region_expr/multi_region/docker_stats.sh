#!/usr/bin/bash

# ts (timestamp input in moreutils) like function
# it adds "same" timestamp to beginning of each line which comes at one time
function timestamp_input () {
  timestamp=$1
  while read -r line
  do
    echo "$timestamp $line"
  done
}

while true
do
  { docker stats --no-stream | timestamp_input "[$(date +%s.%3N)]"; } &
  sleep 1
done
