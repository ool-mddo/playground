from pybatfish.client.commands import *
from pybatfish.question.question import load_questions, list_questions
from pybatfish.question import bfq
from typing import Dict, List
from collections import defaultdict
import re
import pynetbox
import sys


class Cable:
    id: int
    a: "Interface"
    b: "Interface"

    def __init__(self, a: "Interface", b: "Interface"):
        self.a = a
        self.b = b

    def save(self, nb) -> "Cable":
        if hasattr(self, "id"):
            return self
        searched_cable = nb.dcim.cables.filter(termination_a_type="dcim.interface", termination_a_id=self.a.id, termination_b_type="dcim.interface", termination_b_id=self.b.id)
        if len(searched_cable) == 0:
            searched_cable = nb.dcim.cables.filter(termination_a_type="dcim.interface", termination_a_id=self.b.id, termination_b_type="dcim.interface", termination_b_id=self.a.id)
            if len(searched_cable) == 0:
                if (self.a.id != self.b.id):
                  cable = nb.dcim.cables.create( 
                    a_terminations=[{
                        "object_type" : "dcim.interface",
                        "object_id" : self.a.id
                        }],
                    b_terminations=[{
                        "object_type" : "dcim.interface",
                        "object_id" : self.b.id
                        }]
                  )
                  self.id = cable.id
            elif len(searched_cable) == 1:
                self.id = list(searched_cable)[0].id
            elif len(searched_cable) > 1:
                # ERROR
                pass
        elif len(searched_cable) == 1:
            self.id = list(searched_cable)[0].id
        elif len(searched_cable) > 1:
            # ERROR
            pass
        return self

class Interface:
    id: int
    name: str
    device: "Device"

    def __init__(self, device, name: str):
        self.device = device
        self.name = name

    def save(self, nb) -> "Interface":
        if hasattr(self, "id"):
            return self
        searched_interface = nb.dcim.interfaces.filter(self.name, device_id = self.device.id)
        
        if len(searched_interface) == 0:
            print(f"creating interface named ``{self.name}'' in ``{self.device.name}''")
            res  = nb.dcim.interfaces.create(name=self.name, device=self.device.id, type="1000base-t")
            self.id = res.id
        elif len(nb.dcim.interfaces.filter(self.name, device_id = self.device.id)) >= 1:
            searched_interface = nb.dcim.interfaces.filter(self.name, device_id = self.device.id)
            print (list(searched_interface))
            findflag = 0;
            searched_interface = nb.dcim.interfaces.filter(self.name, device_id = self.device.id)
            for intf in list(searched_interface):
                if intf.name == self.name:
                    self.id = intf.id
                    findflag = 1;
                    break
            if findflag == 0:
              print(f"creating interface named ``{self.name}'' in ``{self.device.name}''")
              res  = nb.dcim.interfaces.create(name=self.name, device=self.device.id, type="1000base-t")
              self.id = res.id
            elif not hasattr(self, "id"):
                #print (f"cannot determine interface named ``{self.name}'' in ``{self.device.name}''({self.device.id})")
                raise KeyError(f"cannot determine interface named ``{self.name}'' in ``{self.device.name}''({self.device.id})")
        else:
            self.id = list(searched_interface)[0].id
        return self

class Device:
    id: int
    name: str
    lower_name: str
    device_type_id: int
    device_role_id: int
    site_id: int
    interfaces: Dict[str, "Interface"]

    def __init__(self, name: str, device_type_id, device_role_id, site_id):
        self.nb = nb
        (self.device_type_id, self.device_role_id, self.site_id) = (device_type_id, device_role_id, site_id)
        self.lower_name = name.lower()
        if self.lower_name != name.lower():
            self.name = name
        self.interfaces = {}

    def set_name(self, name):
        self.name = name

    def save(self, nb) -> "Device":
        if hasattr(self, "id"):
            return self

        searched_devices = nb.dcim.devices.filter(self.lower_name)
        if len(searched_devices) == 0:
            print(f"creating device named ``{self.lower_name}''")
            if not hasattr(self, "name"):
                self.name = self.lower_name
            res = nb.dcim.devices.create(name=self.name, device_type=self.device_type_id, device_role=self.device_role_id, site=self.site_id)
            self.id = res.id
        elif len(searched_devices) > 1:
            for dev in list(searched_devices):
                if dev.name.lower() == self.lower_name:
                    self.id = dev.id
                    self.name = dev.name
                    break
            if not hasattr(self, "id"):
                raise KeyError(f"cannot determine device named ``{device_name_lower}''")
        else:
            dev = list(searched_devices)[0]
            self.id = dev.id
            self.name = dev.name
        return self

    def save_interfaces(self, nb):
        for intf in self.interfaces.values():
            intf.save(nb)

    def get_interface(self, interface_name) -> "Interface":
        if interface_name in self.interfaces:
            return self.interfaces[interface_name]
        intf = Interface(self, interface_name)
        self.interfaces[interface_name] = intf
        return self.interfaces[interface_name]

def found_bidiractional_cable(cable_matrix: Dict[str, Dict[str, int]], cable: Cable) -> bool:
    return     (cable_matrix[f"{cable.a.device.lower_name}.{cable.a.name}"][f"{cable.b.device.lower_name}.{cable.b.name}"] > 0
            and cable_matrix[f"{cable.b.device.lower_name}.{cable.b.name}"][f"{cable.a.device.lower_name}.{cable.a.name}"] > 0)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: description2netbox.py http://url-to-netbox netbox-api-key")
        exit(1)
    else:
        nb = pynetbox.api(sys.argv[1], token=sys.argv[2], threading=True)

    load_questions()
    bf_init_snapshot("/mnt/snapshot")
    # exclude junos sub interface and other... TODO
    #is_exclude_interface = lambda x:bool(
    #    re.search(r'\.\d+$', x.interface)  # e.g. ge-0/0/0.0
    #)
    # judge LAG interface to exclude
    is_lag_interface = lambda x:bool(len(x)>0)
    interfaces = bfq \
        .interfaceProperties(properties="Description, Channel_Group, Channel_Group_Members") \
        .answer() \
        .frame() \
        .query("Description == Description") \
        .query('~(Channel_Group_Members.apply(@is_lag_interface))', engine='python')

    # check and greate meta entries
    res = nb.dcim.sites.filter("dummy-site")
    if len(res) == 0:
        res = nb.dcim.sites.create(name="dummy-site", slug="dummy-site")
        site_id = res.id
    elif len(res) > 1:
        print("abiguous site")
    else:
        site_id = list(res)[0].id

    res = nb.dcim.manufacturers.filter("dummy-manufacturer")
    if len(res) == 0:
        res = nb.dcim.manufacturers.create(name="dummy-manufacturer", slug="dummy-manufacturer")
        manufacturer_id = res.id
    elif len(res) > 1:
        print("abiguous manufacturer")
    else:
        manufacturer_id = list(res)[0].id

    res = nb.dcim.device_types.filter("dummy-device_type")
    if len(res) == 0:
        res = nb.dcim.device_types.create(manufacturer=manufacturer_id, model="dummy-device_type", slug="dummy-device_type")
        device_type_id = res.id
    elif len(res) > 1:
        print("abiguous device_type")
    else:
        device_type_id = list(res)[0].id

    res = nb.dcim.device_roles.filter("dummy-device_role")
    if len(res) == 0:
        res = nb.dcim.device_roles.create(name="dummy-device_role", slug="dummy-device_role")
        device_role_id = res.id
    elif len(res) > 1:
        print("abiguous device_role")
    else:
        device_role_id = list(res)[0].id


    hosts = bfq.nodeProperties(properties="Configuration_Format, Interfaces")\
            .answer().frame()\
            .query("Configuration_Format == 'HOST'")

    devices: Dict[str, Device] = {}
    cables: List[Cable] = []
    cable_matrix: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))

    for index, row in interfaces.iterrows():
        # search src device
        device_name_lower = row["Interface"].hostname
        if device_name_lower not in devices:
            dev = Device(device_name_lower, device_type_id, device_role_id, site_id)
            devices[device_name_lower] = dev

        # search src intf
        interface_name = row["Interface"].interface  # batfish returns correct name such as "Ethernet1"
        # convert ge-0/0/0.0 -> ge-0/0/0
        if re.search(r'\.\d+$', interface_name):
            converted_if = interface_name.split('.')
            interface_name = converted_if[0]

        intf = devices[device_name_lower].get_interface(interface_name)
        src_intf = intf

        # parse description
        description_patterns = [
            r"(.+) (.+) via .+",  # Switch-01 ge-0/0/1 via pp-01
            r"(.+)_(.+) S-in:.+", # Switch-01 ge-0/0/1 S-in:1970-01-01
            r"^to_(.+)_(.+)",     # to_Switch-01_ge-0/0/1
            r"^to (.+) (.+)",     # to Switch-01 ge-0/0/1
            r"^to (.+)_(.+)",     # to Switch-01_ge-0/0/1
            r"(.+)_(.+) via .+",  # Switch-01_ge-0/0/1 via pp-01
            r"(.+)_(.+)",         # Switch-01_ge-0/0/1
            r"(.+) (.+)",         # Switch-01 ge-0/0/1
        ]

        for pattern in description_patterns:
            m = re.fullmatch(pattern, row["Description"].replace("\"", ""))
            if m is not None:
                break
        print (str(row))
        print ("SrcDevice:" + str(device_name_lower))
        print ("SrcInterface:" + str(interface_name))
        print (str(m))
        #print (str(device_name))

        if m:
          device_name, interface_name = m.groups()
          device_name_lower = device_name.lower()

        # Convert Et(h)~ to Ethernet~
        if m := re.fullmatch(r"Eth?([\d/]+)", interface_name):
            interface_name = f"Ethernet{m.groups()[0]}"

        # Convert Hu~ to HundredGigE~
        if m := re.fullmatch(r"Hu([\d/]+)", interface_name):
            interface_name = f"HundredGigE{m.groups()[0]}"

        # Convert Ten~ to TenGigE~
        if m := re.fullmatch(r"Ten([\d/]+)", interface_name):
            interface_name = f"TenGigE{m.groups()[0]}"
        # Convert Te~ to TenGigaEthernet~
        elif m := re.fullmatch(r"Te([\d/]+)", interface_name):
            interface_name = f"TenGigaEthernet{m.groups()[0]}"

        # Convert Gi~ to GigaEthernet~
        if m := re.fullmatch(r"Gi([\d/]+)", interface_name):
            interface_name = f"GigaEthernet{m.groups()[0]}"
        
        # search dst device
        if device_name_lower not in devices:
            dev = Device(device_name_lower, device_type_id, device_role_id, site_id)
            devices[device_name_lower] = dev
        else:
            devices[device_name_lower].set_name(device_name_lower)

        print ("DestDevice:" + str(device_name_lower))
        print ("DestInterface:" + str(interface_name))
        # search dst intf
        intf = devices[device_name_lower].get_interface(interface_name)
        dst_intf = intf
        print (str(src_intf.name))
        print (str(dst_intf.name))
        cables.append(Cable(src_intf, dst_intf))
        print (str(len(cables)))

        src_key = f"{src_intf.device.lower_name}.{src_intf.name}"
        dst_key = f"{dst_intf.device.lower_name}.{dst_intf.name}"
        cable_matrix[src_key][dst_key] += 1

        # batfish上でConfiguration_FormatがHOSTとなっている宛先については、
        # その宛先デバイスをsrcとしたリンクも存在することにする
        for _, host in hosts.iterrows():
            if (host["Node"].lower() == dst_intf.device.lower_name and dst_intf.name in host["Interfaces"]):
                cable_matrix[dst_key][src_key] += 1
                break
    print (str(cable_matrix))
    for dev in devices.values():
        dev.save(nb)
        dev.save_interfaces(nb)

    for cable in cables:
        if not found_bidiractional_cable(cable_matrix, cable):
            continue
        cable.save(nb)
