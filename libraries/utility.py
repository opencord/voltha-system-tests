
from __future__ import print_function
import logging

def test(success):
    if success == True:
        return True
    return False

# check if given paramter exist in inventory data, search recursive 
def check_in_inventory_Component_data(inventory_data, description, name, data_type = None):
    print('otti[1]:', str(inventory_data))
    if inventory_data.get('description') == description and inventory_data.get('name') == name:
        if data_type is None:
            return True

    for child in inventory_data['children']:
        print('otti[3]:', str(child))

        if child.get('description') == description and child.get('name') == name:
            if data_type is None:
                return True
            if 'sensor_data' in child: 
                for sensor_data in child['sensor_data']:
                    print('otti[4]:', str(sensor_data))
                    if data_type is not None and sensor_data.get('data_type') == data_type:
                        return True
        print('otti[5]:', child.keys())
        if 'children' in child:
            print('otti[6]:')
            result = check_in_inventory_Component_data(child, description, name, data_type)
            if result == True:
                return result
    return False
# get uuid out of inventory data, search recursive   
def get_uuid_from_inventory_Component_data(inventory_data, searchFor):
    print('otti[1]:', str(inventory_data), searchFor)
    for child in inventory_data['children']:
        print('otti[2]:', str(child))
        if child.get('name') == searchFor:
            print('otti[4]:', str(child['name']))
            return child.get('uuid')
        print('otti[3]:', child.keys())
        if 'children' in child:
            return get_uuid_from_inventory_Component_data(child, searchFor)
    return None

def get_uuid_from_Inventory_Element(inventory, searchFor):
    for childrens in inventory['inventory']['root']['children']:
        return get_uuid_from_inventory_Component_data(childrens, searchFor)
    return None

def check_Inventory_Element(inventory, description, name, data_type = None):
    for childrens in inventory['inventory']['root']['children']:
        return check_in_inventory_Component_data(childrens, description, name, data_type)
    return False

def getWord(line, number):
    line_in_list = line.split()
    #print(line, number)
    #print(line_in_list)
    if len(line_in_list) >= number-1:
        return line_in_list[number-1]
    return ""

def decode(data):
    decoded_data = marshal.dumps(data)
    print('decoded_data=', str(decoded_data))
