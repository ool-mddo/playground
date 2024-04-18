from flask import Flask, request, Response
from logging import getLogger, Formatter, StreamHandler, DEBUG
from prometheus_client import parser, Metric
import sys
import requests
import json


logger = getLogger('root')
logger.setLevel(DEBUG)
formatter = Formatter("[{asctime}: {message} ({funcName}:{lineno}]) ", style="{")

sh = StreamHandler(sys.stdout)
sh.setFormatter(formatter)
sh.setLevel(DEBUG)
logger.addHandler(sh)

app = Flask(__name__)

CADVISOR_URL = 'http://cadvisor:8080/metrics'
CONVERT_FILE = './ns_convert_table.json'

TARGET_METRICS = ['container_network_receive_bytes', 'container_network_receive_bytes']

@app.get('/metrics')
def metrics():
    response = requests.get(CADVISOR_URL)

    relabeled_metrics = relabel(response.text)

    return Response(relabeled_metrics, content_type='text/plain', status=200)

def relabel(metrics_text: str) -> str:
    with open(CONVERT_FILE, 'r') as f:
        mappings = json.load(f)['tp_name_table']

    metrics = list(parser.text_string_to_metric_families(metrics_text))
    for m in metrics:
        if m.name not in TARGET_METRICS:
            logger.info(f'skipped {m.name}')
            continue

        logger.info(f'relabeling {m.name}')
        for sample in m.samples:
            node_name = sample.labels['name'].replace('clab-emulated-', '')
            logger.info(node_name)
            if node_name in mappings.keys():
                if_maps = mappings[node_name]
                if_name_emu = f"{sample.labels['interface']}.0"
                if if_name_emu not in if_maps.keys():
                    continue
                sample.labels['interface'] = if_maps[if_name_emu]['l3_model']
                logger.info(f'converted {node_name}.{if_name_emu} to {sample.labels["interface"]}')

    return build_metrics_string(metrics)

def build_metrics_string(metrics: list[Metric]) -> str:

    metric_lines = []
    for m in metrics:
        metric_lines.append(f'# {m.name} {m.documentation}')
        metric_lines.append(f'# {m.name} {m.type}')
        for s in m.samples:
            label = ','.join([f'{key}="{value}"' for key, value in s.labels.items()])
            if s.timestamp != None:
                metric_lines.append(f'{s.name}{{{label}}} {s.value} {str(s.timestamp).replace(".", "")}')
            else:
                metric_lines.append(f'{s.name}{{{label}}} {s.value}')

    return '\n'.join(metric_lines)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

