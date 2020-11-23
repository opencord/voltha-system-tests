# Copyright 2020 Open Networking Foundation
# delivered by ADTRAN, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import absolute_import
from __future__ import print_function
import inspect
import os

# global definition of keys (find in given 'inventory_data')
_DESCRIPTION = 'description'
_NAME = 'name'
_CHILDREN = 'children'
_SENSOR_DATA = 'sensor_data'
_ROOT = 'root'
_INVENTORY = 'inventory'
_UUID = 'uuid'

def test(success):
    if success == True:
        return True
    return False

def unique():
    """Returns the current filename and line number in our program."""
    trace=str(os.path.basename(__file__) + "[" + str(inspect.currentframe().f_back.f_lineno) + "]:")
    return trace

# check if given paramter exist in inventory data, search recursive
def check_in_inventory_Component_data(inventory_data, description, name, data_type = None):
    print(unique(), str(inventory_data))
    if inventory_data.get(_DESCRIPTION) == description and inventory_data.get(_NAME) == name:
        if data_type is None:
            return True

    for child in inventory_data[_CHILDREN]:
        print(unique(), str(child))

        if child.get(_DESCRIPTION) == description and child.get(_NAME) == name:
            if data_type is None:
                return True
            if _SENSOR_DATA in child:
                for sensor_data in child[_SENSOR_DATA]:
                    print(unique(), str(sensor_data))
                    if data_type is not None and sensor_data.get('data_type') == data_type:
                        return True
        print(unique(), child.keys())
        if _CHILDREN in child:
            result = check_in_inventory_Component_data(child, description, name, data_type)
            if result == True:
                return result
    return False
# get uuid out of inventory data, search recursive
def get_uuid_from_inventory_Component_data(inventory_data, searchFor):
    print(unique(), str(inventory_data), ', ', str(searchFor))
    if inventory_data.get(_NAME) == searchFor:
        return inventory_data.get(_UUID)
    for child in inventory_data[_CHILDREN]:
        print(unique(), str(child))
        if child.get(_NAME) == searchFor:
            print(unique(), str(child[_NAME]))
            return child.get(_UUID)
        print(unique(), child.keys())
        if _CHILDREN in child:
            return get_uuid_from_inventory_Component_data(child, searchFor)
    return None

def get_uuid_from_Inventory_Element(inventory, searchFor):
    for childrens in inventory[_INVENTORY][_ROOT][_CHILDREN]:
        return get_uuid_from_inventory_Component_data(childrens, searchFor)
    return None

def check_Inventory_Element(inventory, description, name, data_type = None):
    for childrens in inventory[_INVENTORY][_ROOT][_CHILDREN]:
        return check_in_inventory_Component_data(childrens, description, name, data_type)
    return False

def getWord(line, number):
    line_in_list = line.split()
    if len(line_in_list) >= number-1:
        return line_in_list[number-1]
    return ""

def decode(data):
    decoded_data = data
    print(unique(), str(decoded_data))
