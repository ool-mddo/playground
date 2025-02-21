#!/bin/bash

# shellcheck disable=SC1091
source ./demo_vars

# read worker address as array
IFS=',' read -r -a remote_nodes <<< "$WORKER_ADDRESS"

# YAMLテンプレート
yaml_template_cadvisor="
scrape_configs:
  - job_name: cadvisor
    scrape_interval: 5s
    static_configs:
      - targets:
"
yaml_template_node_exporter="
  - job_name: node_exporter
    scrape_interval: 10s
    static_configs:
      - targets:
"

# 生成するYAMLファイル名
output_file="../../assets/prometheus/prometheus.yaml"

# YAMLテンプレートを出力
echo -n "$yaml_template_cadvisor" > "$output_file"

# targetsセクションを生成して追記
for remote_ip in "${remote_nodes[@]}"; do
  echo -e "        -  $remote_ip:$CADVISOR_PORT" >> "$output_file"
done

echo -n "$yaml_template_node_exporter" >> "$output_file"

# targetsセクションを生成して追記
for remote_ip in "${remote_nodes[@]}"; do
  echo -e "        - $remote_ip:$NODE_EXPORTER_PORT" >> "$output_file"
done

# YAMLの終端
echo -e "      " >> "$output_file"

# reload prometheus
curl -X POST "http://${PROMETHEUS}/-/reload"
