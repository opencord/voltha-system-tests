# Copyright 2020 ADTRAN, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
from grpc_robot.grpc_robot import _package_version_get


class Collections(object):
    """
    Tools for collections (list, dict) related functionality.
    """

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('grpc_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    @staticmethod
    def dict_get_key_by_value(input_dict, search_value):
        """
        Gets the first key from _input_dict_ which has the value of _search_value_.

        If _search_value_ is not found in _input_dict_, an empty string is returned.

        *Parameters*:
        - _input_dict_: <dictionary> to be browsed.
        - _search_value_: <string>, value to be searched for.

        *Return*: key of dictionary if search value is in input_dict else empty string
        """
        return_key = ''
        for key, val in input_dict.items():
            if val == search_value:
                return_key = key
                break

        return return_key

    @staticmethod
    def dict_get_value(values_dict, key, strict=False):
        """
        Returns the value for given _key_ in _values_dict_.

        If _strict_ is set to False (default) it will return given _key_ if its is not in the dictionary.
        If set to True, an AssertionError is raised.

        *Parameters*:
        - _key_: <string>, key to be searched in dictionary.
        - _values_dict_: <dictionary> in which the key is searched.
        - _strict_: Optional: <boolean> switch to indicate if an exception shall be raised if key is not in values_dict.
                Default: False

        *Return*:
        - if key is in values_dict: Value from _values_dict_ for _key_.
        - else: _key_.
        - raises AssertionError in case _key_ is not in _values_dict_ and _strict_ is True.
        """
        try:
            return_value = values_dict[key]
        except KeyError:
            if strict:
                raise AssertionError('Error: Value not found for key: %s' % key)
            else:
                return_value = key

        return return_value

    @staticmethod
    def list_get_dict_by_value(input_list, key_name, value, match='first'):
        """
        Retrieves a dictionary from a list of dictionaries where _key_name_ has the _value, if _match_ is
        "first". Else it returns all matching dictionaries.

        *Parameters*:
        - _input_list_: <list> ; List of dictionaries.
        - _key_name_: <dictionary> or <list> ; Name of the key to be searched for.
        - _value_: <string> or <number> ; Any value of key _key_name_ to be searched for.

        *Example*:
        | ${dict1}    | Create Dictionary      | key_key=master1 | key1=value11 | key2=value12 |          |
        | ${dict2}    | Create Dictionary      | key_key=master2 | key1=value21 | key2=value22 |          |
        | ${dict3}    | Create Dictionary      | key_key=master3 | key1=value31 | key2=value32 |          |
        | ${dict4}    | Create Dictionary      | key_key=master4 | key5=value41 | key6=value42 |          |
        | ${the_list} | Create List            | ${dict1}        | ${dict2}     | ${dict3}     | ${dict4} |
        | ${result}   | List Get Dict By Value | ${the_list}     | key_key      | master4      |          |

        Variable ${result} has following structure:
        | ${result} = {
        |   'key_key': 'master4',
        |   'key5': 'value41',
        |   'key6': 'value42'
        | }
        """
        try:
            if match == 'first':
                return input_list[next(index for (index, d) in enumerate(input_list) if d[key_name] == value)]
            else:
                return [d for d in input_list if d[key_name] == value]
        except (KeyError, TypeError, StopIteration):
            raise KeyError('list does not contain a dictionary with key:value "%s:%s"' % (key_name, value))

    @staticmethod
    def to_camel_case(snake_str, first_uppercase=False):
        components = snake_str.split('_')
        # We capitalize the first letter of each component except the first one
        # with the 'title' method and join them together.
        return (components[0] if not first_uppercase else components[0].title()) + ''.join(x.title() for x in components[1:])
