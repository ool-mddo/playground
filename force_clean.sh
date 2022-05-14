#!/bin/sh

cd "$(dirname $0)" || exit
. ./.env

echo rm -rf ${SHARED_CONFIGS_DIR}/*_drawoff
echo rm -rf ${SHARED_CONFIGS_DIR}/*_linkdown
echo "find ${SHARED_CONFIGS_DIR} -name "snapshot_patterns.json" -exec rm {} \;"
echo rm -rf ${SHARED_MODELS_DIR}/*
echo rm -f ${SHARED_NETOVIZ_MODEL_DIR}/*drawoff.json
echo rm -f ${SHARED_NETOVIZ_MODEL_DIR}/*linkdown*.json
