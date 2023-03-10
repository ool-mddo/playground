from pybatfish.client.commands import *
from pybatfish.question.question import load_questions, list_questions
from pybatfish.question import bfq
from typing import Dict
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
                cable = nb.dcim.cables.create(termination_a_type="dcim.interface", termination_a_id=self.a.id, termination_b_type="dcim.interface", termination_b_id=self.b.id)
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
        elif len(searched_interface) > 1:
            for intf in list(searched_interface):
                if intf.name == self.name:
                    self.id = intf.id
                    break
            if not hasattr(self, "id"):
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


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: description2netbox.py http://url-to-netbox netbox-api-key")
        exit(1)
    else:
        nb = pynetbox.api(sys.argv[1], token=sys.argv[2], threading=True)

    load_questions()
    bf_init_snapshot("/mnt/snapshot")
    # exclude junos sub interface and other... TODO
    is_exclude_interface = lambda x:bool(
        re.search(r'\.\d+$', x.interface)  # e.g. ge-0/0/0.0
    )
    # judge LAG interface to exclude
    is_lag_interface = lambda x:bool(len(x)>0)
    interfaces = bfq \
        .interfaceProperties(properties="Description, Channel_Group, Channel_Group_Members") \
        .answer() \
        .frame() \
        .query("Description == Description") \
        .query('~(Channel_Group_Members.apply(@is_lag_interface))', engine='python') \
        .query('~(Interface.apply(@is_exclude_interface))', engine='python')

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




    devices = {}
    cables = []
    for index, row in interfaces.iterrows():
        # search src device
        device_name_lower = row["Interface"].hostname
        if device_name_lower not in devices:
            dev = Device(device_name_lower, device_type_id, device_role_id, site_id)
            devices[device_name_lower] = dev

        # search src intf
        interface_name = row["Interface"].interface  # batfish returns correct name such as "Ethernet1"
        intf = devices[device_name_lower].get_interface(interface_name)
        src_intf = intf

        # parse description
        m = re.fullmatch(r"to_(.+)_(.+)", row["Description"])
        device_name, interface_name = m.groups()

        # search dst device
        if device_name.lower() not in devices:
            dev = Device(device_name, device_type_id, device_role_id, site_id)
            devices[device_name.lower()] = dev
        else:
            devices[device_name.lower()].set_name(device_name)

        # search dst intf
        intf = devices[device_name.lower()].get_interface(interface_name)
        dst_intf = intf

        cables.append(Cable(src_intf, dst_intf))

    for dev in devices.values():
        dev.save(nb)
        dev.save_interfaces(nb)
    for cable in cables:
        cable.save(nb)
