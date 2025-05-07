#!/bin/bash

#=== 設定 ===#
CONFIG_REPO=~/playground/configs/mddo-mregnw
SCRIPT_DIR=~/playground/demo/copy_to_emulated_env
# BRANCHES=("2region" "5region" "10region" "20region" "40region")
BRANCHES=("2region")
LOG_BASE_DIR="${SCRIPT_DIR}/run_logs"
SCRIPTS=("demo_step1-1.sh" "demo_step1-2.sh" "demo_step2-1.sh" "demo_step2-2.sh" "demo_wait.sh" "demo_task.sh" "demo_remove.sh")

# 実行開始時刻を yyyymmddhhmm 形式で記録
RUN_TIMESTAMP=$(date +%Y%m%d%H%M)
RUN_LOG_ROOT="$LOG_BASE_DIR/$RUN_TIMESTAMP"

#=== 関数 ===#

monitor_resources() {
  local pid=$1
  local log_file=$2

  echo "timestamp,cpu_usage_percent,mem_total,mem_used,mem_free,mem_shared,mem_buff_cache,mem_available" > "$log_file"

  while kill -0 "$pid" 2>/dev/null; do
    timestamp=$(date +%s)
    # mpstatでCPU合計を取得し、idleを引いた使用率を算出（CPU全体）
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

    # free -m の出力から各メモリ値(MB)を取得
    read -r mem_total mem_used mem_free mem_shared mem_buff_cache mem_available < <(free -m | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')

    echo "$timestamp, $cpu, $mem_total, $mem_used, $mem_free, $mem_shared, $mem_buff_cache, $mem_available" >> "$log_file"
    sleep 1
  done
}

run_script_with_monitoring() {
  local script=$1
  local log_file=$2
  local resource_log=$3
  local branch=$4

  echo "Running $script for branch $branch..."
  start_time=$(date +%s)

  if [[ "$script" == "demo_remove.sh" ]]; then
    # backup clab-topo.yaml before destroy
    cp clab/clab-topo.yaml "${RUN_LOG_ROOT}/${branch}"
    # destroy
    sudo bash "$script" "$branch" 2>&1 | tee "$log_file" &
  else
    bash "$script" "$branch" 2>&1 | tee "$log_file" &
  fi
  script_pid=$!

  monitor_resources $script_pid "$resource_log" &
  monitor_pid=$!

  wait $script_pid
  end_time=$(date +%s)
  runtime=$((end_time - start_time))

  echo "Start time   : $start_time" | tee -a "$log_file"
  echo "End   time   : $end_time" | tee -a "$log_file"
  echo "Duration(sec): $runtime" | tee -a "$log_file"

  # リソースモニタリング終了を待機
  wait $monitor_pid
}

#=== メイン処理 ===#

# sudo権限が必要なため、最初に確認しておく
if [ "$EUID" -ne 0 ]; then
  echo "このスクリプトはsudo権限で実行される必要があります。パスワードを入力してください。"
  sudo -v || { echo "sudo権限が必要です。処理を中断します。"; exit 1; }
fi

for branch in "${BRANCHES[@]}"; do
  echo "=== 処理開始: ブランチ $branch ==="

  cd "$CONFIG_REPO" || { echo "Cannot access $CONFIG_REPO"; exit 1; }
  git checkout "$branch" || { echo "Failed to checkout $branch"; continue; }
  cd "$SCRIPT_DIR" || { echo "Cannot access $SCRIPT_DIR"; exit 1; }

  LOG_DIR="$RUN_LOG_ROOT/$branch"
  mkdir -p "$LOG_DIR"

  for script in "${SCRIPTS[@]}"; do
    script_name="${script%.sh}"
    log_file="$LOG_DIR/${script_name}.log"
    resource_log="$LOG_DIR/${script_name}_resources.csv"

    run_script_with_monitoring "$script" "$log_file" "$resource_log" "$branch"
  done

  echo "=== 処理完了: ブランチ $branch ==="
  echo "(wait 10s to next branch)"
  sleep 10s
done

echo "全処理が完了しました。ログは $RUN_LOG_ROOT に保存されています。"
