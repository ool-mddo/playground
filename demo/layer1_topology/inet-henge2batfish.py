import json
import sys
import itertools
import re

remove_lag_suffix = lambda x:re.sub(r" \(.+\)$", "", x)

with open(sys.argv[1], 'r') as f:
    input_json = json.load(f)

output = {"edges": None}
output["edges"] = list(itertools.chain.from_iterable(map(
    lambda y:
    [
        {"node1":y["node1"],"node2":y["node2"],},
        {"node1":y["node2"],"node2":y["node1"],},
    ], map(
    lambda x:
    {
        "node1":
        {
            "hostname": x["source"],
            "interfaceName": remove_lag_suffix(x["meta"]["interface"]["source"]),
        },
        "node2":
        {
            "hostname": x["target"],
            "interfaceName": remove_lag_suffix(x["meta"]["interface"]["target"]),
        },
    }, input_json["links"]))))

print(json.dumps(output, indent=2))
