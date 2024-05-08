#!/usr/bin/bash

function show_usage() {
    command=$(basename "$0")
    echo "Usage: ${command} [options]"
    echo "Options:"
    echo "  -r, --raw     Print csv (raw data)"
    echo "  -h, --help    Show this help message and exit"
}

function target_branch () {
    # $1 is "repos/hoge" format
    repository_name=$(echo "$1" | cut -d/ -f2)
    repository_tag_var=$(echo "${repository_name}_IMAGE_TAG" | tr  '[:lower:]' '[:upper:]' | tr '-' '_')
    eval "echo \$$repository_tag_var"
}

function output_csv () {
    SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
    # shellcheck disable=SC1091
    source .env

    cd "$SCRIPT_DIR" || exit 1

    # header
    echo "repository, current-branch, current-tag, target-branch/tag, up-to-date?"

    for repo in repos/*; do
        cd "$repo" || exit 2

        current_branch=$(git branch --show-current)
        current_tag=$(git describe --tags --exact-match 2>/dev/null)
        target_branch=$(target_branch "$repo")
        is_up_to_date=""
        if [[ -n $current_branch ]]; then
            git fetch -q
            if git status -uno | grep -q behind; then
                is_up_to_date="NO!"
            else
                is_up_to_date="yes"
            fi
        fi
        # record
        echo "$repo, $current_branch, $current_tag, $target_branch, $is_up_to_date"

        cd "$SCRIPT_DIR" || exit 2
    done
}

# argument processing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -r|--raw)
            output_csv
            exit 0
            ;;
        *)
            echo "Error: Invalid option '$1'"
            show_usage
            exit 1
            ;;
    esac
done

output_csv | column -s, -t
