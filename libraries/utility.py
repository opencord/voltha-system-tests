# Copyright 2020-2024 Open Networking Foundation Contributors
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
import operator
import requests

# global definition of keys (find in given 'inventory_data')
_NAME = 'name'
_CHILDREN = 'children'
_SENSOR_DATA = 'sensor_data'
_ROOT = 'root'
_INVENTORY = 'inventory'
_UUID = 'uuid'


def test(success):
    if success is True:
        return True
    return False


def unique():
    """Returns the current filename and line number in our program."""
    trace = str(os.path.basename(__file__) +
                "[" + str(inspect.currentframe().f_back.f_lineno) + "]:")
    return trace


# check if given paramter exist in inventory data, search recursive
def check_in_inventory_Component_data(inventory_data, name, element, value):
    print(unique(), str(inventory_data), str(name), str(element), str(value))
    if inventory_data.get(_NAME) == name and inventory_data.get(element) == value:
        return True

    for child in inventory_data[_CHILDREN]:
        print(unique(), str(child))
        if child.get(_NAME) == name and child.get(element) == value:
            return True
        if _SENSOR_DATA in child:
            for sensor_data in child[_SENSOR_DATA]:
                print(unique(), str(sensor_data))
                if sensor_data.get(element) == value:
                    return True
        if _CHILDREN in child:
            result = check_in_inventory_Component_data(child, name, element, value)
            if result is True:
                return result
    return False


# get uuid out of inventory data, search recursive
def get_uuid_from_inventory_Component_data(inventory_data, searchFor):
    print(unique(), str(inventory_data), ', ', str(searchFor))
    if inventory_data.get(_NAME) == searchFor:
        return inventory_data.get(_UUID)
    for child in inventory_data[_CHILDREN]:
        print(unique(), str(child))
        result = None
        if child.get(_NAME) == searchFor:
            print(unique(), str(child[_NAME]))
            result = child.get(_UUID)
        print(unique(), child.keys())
        if result is None and _CHILDREN in child:
            result = get_uuid_from_inventory_Component_data(child, searchFor)
        if result is not None:
            return result
    return None


def get_uuid_from_Inventory_Element(inventory, searchFor):
    for children in inventory[_INVENTORY][_ROOT][_CHILDREN]:
        return get_uuid_from_inventory_Component_data(children, searchFor)
    return None


def check_Inventory_Element(inventory, name, element, value):
    for childrens in inventory[_INVENTORY][_ROOT][_CHILDREN]:
        return check_in_inventory_Component_data(childrens, name, element, value)
    return False


def getWord(line, number):
    line_in_list = line.split()
    if len(line_in_list) >= number-1:
        return line_in_list[number-1]
    return ""


def decode(data):
    decoded_data = data
    print(unique(), str(decoded_data))


# Compares two values using a given operator. The values are converted to float first so that
# numbers as strings are also accepted. Returns True or False.
# operator: ==, !=, <, <=, >, >=
# Example:
# | ${result} | Compare | 100 | >  | 5  | # True |
def compare(value1, op, value2):
    ops = {"==": operator.eq,
           "!=": operator.ne,
           "<":  operator.lt,
           "<=": operator.le,
           ">":  operator.gt,
           ">=": operator.ge}
    return ops[op](float(value1), float(value2))


# Validates two values using a given operator.
# The values are converted to float first so that numbers as strings are also accepted.
# Second value has to be a list in case of operator is 'in' or 'range'
# Returns True or False.
# operator: in, range, ==, !=, <, <=, >, >=
# Example:
# | ${result} | validate | 100 | >  | 5  | # True |
# | ${result} | validate | 11  | in | ['11','264','329']  | # True |
# | ${result} | validate | 1   | range | ['0','1']  | # True |
def validate(value1, op, value2):
    if op == "in":
        return (float(value1) in [float(i) for i in value2])
    if op == "range":
        return ((compare(value1, ">=", value2[0])) and (compare(value1, "<=", value2[1])))
    return compare(value1, op, value2)


def get_memory_consumptions(address, container, namespace="default"):
    """
    Query Prometheus and generate instantaneous memory consumptions for given pods under test
    :param address: string The address of the Prometheus instance to query
    :param container: string The pod name
    :param namespace: string The pod namespace
    :return: memory consumtion value
    """
    container_mem_query = ('container_memory_working_set_bytes{namespace="%s",container="%s"}' %
                           (namespace, container))
    mem_params = {
        "query": container_mem_query,
    }
    r = requests.get("http://%s/api/v1/query" % address, mem_params)
    container_cpu = r.json()["data"]["result"]
    if len(container_cpu) > 0:
        return container_cpu[0]["value"][1]
    else:
        return -1

def get_memory_consumptions_range(address, container, namespace="default", start=0, end=0):
    """
    Query Prometheus and generate instantaneous memory consumptions for given pods under test
    :param address: string The address of the Prometheus instance to query
    :param container: string The pod name
    :param namespace: string The pod namespace
    :param start: integer The range start time (epoch)
    :param end: integer The range end time
    :return: memory consumtion value
    """
    container_mem_query = ('sort_desc(container_memory_working_set_bytes{namespace="%s",container="%s"})' %
                           (namespace, container))
    mem_params = {
        "query": container_mem_query,
        "start":start,
        "end":end,
        "step":'1m',
    }
    r = requests.get("http://%s/api/v1/query_range" % address, mem_params)
    container_cpu = r.json()["data"]["result"]
    if len(container_cpu) > 0:
        return container_cpu[0]["values"]
    else:
        return -1
