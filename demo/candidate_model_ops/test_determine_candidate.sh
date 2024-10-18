#!/usr/bin/bash

source demo_vars
source determine_candidate.sh

original_candidate_list="${USECASE_SESSION_DIR}/original_candidate_list.json"

for target_original_snapshot in $(jq -r ".[] | .snapshot" "$original_candidate_list")
do
  determine_candidate "$target_original_snapshot" # | grep -v "Target" | grep -v "Result"
done
