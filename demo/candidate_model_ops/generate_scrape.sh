#!/bin/bash

source ./demo_vars
# shellcheck disable=SC1091
IFS=',' read -r -a remotenode <<< $WORKER_ADDRESS
cadvisor_port=20080
nodeexporter_port=9100
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
for remoteip in "${remotenode[@]}"; do
  echo -e "        -  $remoteip:$cadvisor_port" >> "$output_file"
done

echo -n "$yaml_template_node_exporter" >> "$output_file"

# targetsセクションを生成して追記
for remoteip in "${remotenode[@]}"; do
  echo -e "        - $remoteip:$nodeexporter_port" >> "$output_file"
done



# YAMLの終端
echo -e "      " >> "$output_file"
curl -X POST http://localhost:9090/-/reload

