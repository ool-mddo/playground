import requests
import json
import re
import sys

if len(sys.argv) < 4:
    print("usage: netbox2inet-henge.py http://url-to-netbox netbox-api-key first-device-id")
    exit(1)

netbox_api_header = {
    "content-type": "application/json",
    "accept": "application/json",
    "Authorization": f"Token {sys.argv[2]}",
}

def api_call(endpoint, params):
    ret = requests.get(
        sys.argv[1] + endpoint,
        headers = netbox_api_header,
        params = params,
    )
    if ret.status_code == requests.codes.ok:
        return ret.json()
    else:
        ret.raise_for_status()

unknown_device = {int(sys.argv[3]):True}
known_device = {}

topology = { "nodes": [], "links": [] }

while unknown_device:
    # debug
    print(unknown_device, file=sys.stderr)

    device_id, no_use = unknown_device.popitem()
    known_device[device_id] = True
    device = api_call('/api/dcim/devices/', {'id': device_id})["results"][0]
# for device in devices["results"]:
    node = {
        "type": "device",
        "id": device["id"],
        "link": "http://localhost:8000/dcim/devices/" + str(device["id"]) + "/",
        "name": device["name"],
    }
    if re.search(r"router", device["device_role"]["name"], flags=re.IGNORECASE):
        node["icon"] = "./images/router.png"
    elif re.search(r"switch", device["device_role"]["name"], flags=re.IGNORECASE):
        node["icon"] = "./images/switch.png"
    elif re.search(r"firewall", device["device_role"]["name"], flags=re.IGNORECASE):
        node["icon"] = "./images/firewall.png"
    # VC
    # vc = re.findall(r"^(.+)-fpc\d+$", device["name"], flags=re.IGNORECASE)
    # if vc:
    #     node["group"] = vc[0]
        
    topology["nodes"].append(node)

    interfaces = api_call(
        '/api/dcim/interfaces/',
        {
            'device_id': device["id"],
            'connection_status': 'True',
        }
    )

    for interface in interfaces["results"]:
        # skip vc member interface
        if interface["device"]["id"] != device["id"]:
            continue

        link = {}
        if interface["connected_endpoint"] is None:
            continue
        # connect directly or via patch panel
        if interface["connected_endpoint_type"] == "dcim.interface":
            link = {
                "source": device["name"],
                "target": interface["connected_endpoint"]["device"]["name"],
                "cable_id": interface["connected_endpoint"]["cable"],
                "meta": {
                    "interface": {
                        "source": interface["name"],
                        "source_lag": interface["lag"]["name"] if interface["lag"] is not None else None,
                        "target": interface["connected_endpoint"]["name"],
                        "target_lag": None,
                    }
                }
            }
            if interface["connected_endpoint"]["device"]["id"] not in known_device.keys():
                unknown_device[interface["connected_endpoint"]["device"]["id"]] = True
        # connect via circuit
        # TODO: cable_id
        elif interface["connected_endpoint_type"] == "circuits.circuittermination":
            link = {
                "source": device["name"],
                "target": interface["connected_endpoint"]["circuit"]["cid"],
                "meta": {
                    "interface": {
                        "source": interface["name"],
                        "source_lag": interface["lag"]["name"] if interface["lag"] is not None else None,
                        "target": "",
                        "target_lag": None,
                    }
                }
            }
            trace = api_call('/api/dcim/interfaces/' + str(interface["id"]) + '/trace/', {'dummy':'dummy'})
            try:
                opposite_side = trace[len(trace)-1][len(trace[len(trace)-1])-1]["device"]["id"]
            except TypeError:
                print("TypeError:\n", file=sys.stderr)
                print("interface:\n", file=sys.stderr)
                print(json.dumps(interface,indent=2), file=sys.stderr)
                print("trace:\n", file=sys.stderr)
                print(json.dumps(trace,indent=2), file=sys.stderr)
            except KeyError:
                print("KeyError:\n", file=sys.stderr)
                print("interface:\n", file=sys.stderr)
                print(json.dumps(interface,indent=2), file=sys.stderr)
                print("trace:\n", file=sys.stderr)
                print(json.dumps(trace,indent=2), file=sys.stderr)
            # if opposite_side not in known_device.keys():
            if "opposite_side" in locals() and opposite_side not in known_device.keys():
                unknown_device[opposite_side] = True

        if re.search(r'100me', interface["type"]["label"], flags=re.IGNORECASE):
            link["meta"]["bandwidth"] = "100M"
            link["class"] = "hun-meg"
        elif re.search(r'1ge', interface["type"]["label"], flags=re.IGNORECASE):
            link["meta"]["bandwidth"] = "1G"
            link["class"] = "one-gig"
        elif re.search(r'10ge', interface["type"]["label"], flags=re.IGNORECASE):
            link["meta"]["bandwidth"] = "10G"
            link["class"] = "ten-gig"
        elif re.search(r'40ge', interface["type"]["label"], flags=re.IGNORECASE):
            link["meta"]["bandwidth"] = "40G"
            link["class"] = "forty-gig"
        elif re.search(r'100ge', interface["type"]["label"], flags=re.IGNORECASE):
            link["meta"]["bandwidth"] = "100G"
            link["class"] = "hun-gig"

        topology["links"].append(link)

circuits = api_call('/api/circuits/circuits/',
                    {
                        # 'status': '1', # 1 := Active
                        "limit": 300
                    }
)

for circuit in circuits["results"]:
    node = {
        "type": "circuit",
        "id": circuit["id"],
        "link": "http://192.168.23.31:8000/circuits/circuits/" + str(circuit["id"]) + "/",
        "name": circuit["cid"],
        "icon": "./images/ix.png",
    }
    topology["nodes"].append(node)

def is_equal_link(l1, l2):
    if l1["source"] != l2["target"]:
        return False
    if l1["target"] != l2["source"]:
        return False
    if l1["meta"]["interface"]["source"] != l2["meta"]["interface"]["target"]:
        return False
    return True

# de-dup link
links = []
for original_link in topology["links"]:
    refcount = 0
    for link in links:
        if is_equal_link(original_link, link):
            refcount = 1
            link["meta"]["interface"]["target_lag"] = original_link["meta"]["interface"]["source_lag"]
    if refcount == 0:
        links.append(original_link)

for link in links:
    if link["meta"]["interface"]["target_lag"] is not None:
        link["meta"]["interface"]["target"] = link["meta"]["interface"]["target"] + " (" + link["meta"]["interface"]["target_lag"] + ")"
    if link["meta"]["interface"]["source_lag"] is not None:
        link["meta"]["interface"]["source"] = link["meta"]["interface"]["source"] + " (" + link["meta"]["interface"]["source_lag"] + ")"

topology["links"] = links

print(json.dumps(topology,indent=2))
