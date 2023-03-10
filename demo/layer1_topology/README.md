# L1_topo scripts

## usage

* add NetBox devices, interfaces and cables by parsing descriptions in configs
  * requirement: can access batfish via pybatfish

```
(in batfish container)L1_topo# python /mnt/description2netbox.py http://host.docker.internal:8000 0123456789abcdef0123456789abcdef01234567
```

* extract interface connections from NetBox into inet-henge topology data
  * [sample](inet-henge.sample.json)

```
L1_topo# python netbox-topology.py http://localhost:8000 0123456789abcdef0123456789abcdef01234567 1 > ../inet-henge.sample.json
{1: True}
{5: True, 2: True, 3: True, 4: True}
{5: True, 2: True, 3: True, 9: True, 10: True}
{5: True, 2: True, 3: True, 9: True, 12: True}
{5: True, 2: True, 3: True, 9: True}
{5: True, 2: True, 3: True, 11: True}
{5: True, 2: True, 3: True}
{5: True, 2: True}
{5: True, 6: True}
{5: True}
```

* convert inet-henge structure to batfish topology
  * [sample](layer1_topology.sample.json)

```
L1_topo# python inet-henge2batfish.py ../inet-henge.sample.json > ../layer1_topology.sample.json
```
