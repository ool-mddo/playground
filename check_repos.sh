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

function is_branch_up_to_date () {
    current_branch=$1
    if [[ -n $current_branch ]]; then
        git fetch -q
        if git status -uno | grep -q behind; then
            echo "NO!"
        else
            echo "yes"
        fi
    fi
}

function output_playground_csv () {
    repository_name="playground"
    target_branch="NONE"
    current_branch=$(git branch --show-current)
    current_tag=$(git describe --tags --exact-match 2>/dev/null)
    current_commit=$(git rev-parse --short HEAD)
    is_up_to_date=$(is_branch_up_to_date "$current_branch")
    echo "$repository_name, $target_branch, $current_branch, $current_tag, $current_commit, $is_up_to_date"
}

function output_repos_csv () {
    for repo in repos/*; do
        pushd "$repo" > /dev/null || exit 2

        target_branch=$(target_branch "$repo")
        current_branch=$(git branch --show-current)
        current_tag=$(git describe --tags --exact-match 2>/dev/null)
        current_commit=$(git rev-parse --short HEAD)
        is_up_to_date=$(is_branch_up_to_date "$current_branch")
        # record
        echo "$repo, $target_branch, $current_branch, $current_tag, $current_commit, $is_up_to_date"

        popd > /dev/null || exit 2
    done
}

function output_all_csv () {
    SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
    # shellcheck disable=SC1091
    source .env

    cd "$SCRIPT_DIR" || exit 1

    # header
    echo "repository, target-branch/tag, current-branch, current-tag, current-commit, up-to-date?"

    # playground dir
    output_playground_csv "$SCRIPT_DIR"
    # repos
    output_repos_csv
}

# argument processing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -r|--raw)
            output_all_csv
            exit 0
            ;;
        *)
            echo "Error: Invalid option '$1'"
            show_usage
            exit 1
            ;;
    esac
done

output_all_csv | column -s, -t
