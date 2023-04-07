### containerlab server login & sudo password Setting
###Example
###$ cat env/passwords 
###---
###"^SSH password:\\s*?$": "login password"
###"^BECOME password.*:\\s*?$": "login password"

source ./demo_vars
cd $PLAYGROUND_DIR
mkdir -p $PLAYGROUND_DIR/netoviz_model/${NETWORK_NAME}/original_tobe
docker-compose run netomox-exp  bundle exec ./exe/mddo_toolbox.rb convert_namespace \
	-f json -t /mddo/netoviz_model/${NETWORK_NAME}/original_asis/ns_table.json \
	/mddo/netoviz_model/${NETWORK_NAME}/emulated_tobe/topology.json \
	> $PLAYGROUND_DIR/netoviz_model/${NETWORK_NAME}/original_tobe/topology.json


cd $MODEL_MERGE_DIR/model_merge
python3.10 config.py \
	$PLAYGROUND_DIR/netoviz_model/$NETWORK_NAME/original_asis/topology.json \
	$PLAYGROUND_DIR/netoviz_model/$NETWORK_NAME/original_tobe/topology.json \
	| jq -r '.[] | [ ."node-id", .config ]' | xargs -ICMD echo -e CMD 

