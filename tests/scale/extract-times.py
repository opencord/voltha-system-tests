# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import xml.etree.ElementTree as ET
from datetime import datetime

dash = '-' * 75
double_dash = '=' * 75

def cut_string(str):
    return (str[:48] + '..') if len(str) > 50 else str

def read_file(file):
    # create element tree object
    tree = ET.parse(file)

    # get root element
    root = tree.getroot()

    print(double_dash)
    print('{:<50}{:>10}{:>15}'.format("Test Name", "Status", "Duration (s)"))
    print(double_dash)
    for test in root.findall('./suite/test'):
        status = test.find('.status')
        start = status.attrib["starttime"]
        end = status.attrib["endtime"]
        s = datetime.strptime(start[:-4], '%Y%m%d %H:%M:%S')
        e = datetime.strptime(end[:-4], '%Y%m%d %H:%M:%S')
        diff = e - s
        print('{:<50}{:>10}{:>15}'.format(cut_string(test.attrib["name"]), status.attrib["status"], diff.seconds))
        print(dash)



if __name__ == '__main__':
    read_file("output.xml")
