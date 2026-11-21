#!/bin/bash

set -e

branch="$1"

if [ -z "$branch" ]; then
  echo "エラー: ブランチ名が指定されていません。"
  echo "使い方: $0 <branch-name>"
  exit 1
fi

# ブランチ名に応じたIPアドレスのマッピング
case "$branch" in
  2region)
    target_ip="2.2.2.2"
    ;;
  5region)
    target_ip="3.3.3.4"
    ;;
  10region)
    target_ip="5.5.5.6"
    ;;
  20region)
    target_ip="10.10.10.11"
    ;;
  40region)
    target_ip="20.20.20.21"
    ;;
  *)
    echo "エラー: 未対応のブランチ名 '$branch' が指定されました。"
    exit 1
    ;;
esac

echo "[$branch] clab-emulated-regiona-pe01 から $target_ip に traceroute を実行します..."

docker exec -i clab-emulated-regiona-pe01 traceroute "$target_ip"

