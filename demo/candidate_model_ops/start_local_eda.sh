PID=`ps -ef | grep /eda/rulebook.yaml | grep -v grep | awk '{print $2}'`
if [ -n "$PID" ]; then
  sudo kill -9 $PID
fi
echo 'job_status{jobname="",network_name="",snapshot_name=""} 0' > ./node_exporter/prom/textfile.prom
sudo docker compose -f node_exporter/docker-compose.yaml up -d
sudo ansible-rulebook -i ../../ansible-eda/hosts --rulebook ../../ansible-eda/containerlab_rulebook.yaml -vvvv
