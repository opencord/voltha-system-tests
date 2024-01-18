# Copyright 2017-2024 Open Networking Foundation (ONF) and the ONF Contributors
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

import argparse
import os
import xml.etree.ElementTree as ET
from datetime import datetime

dash = "-" * 75
double_dash = "=" * 75


def cut_string(str):
    return (str[:48] + "..") if len(str) > 50 else str


def format_key(str):
    return str.replace("plot-", "").replace("-", " ")


def read_file(file, plot_folder):
    # create element tree object
    tree = ET.parse(file)

    # get root element
    root = tree.getroot()

    results = {}

    start_timer = 0
    print(double_dash)
    print("{:<50}{:>10}{:>15}".format("Test Name", "Status", "Duration (s)"))
    print(double_dash)
    for test in root.findall("./suite/test"):
        status = test.find(".status")
        name = test.attrib["name"]
        start = status.attrib["starttime"]
        end = status.attrib["endtime"]
        s = datetime.strptime(start[:-4], "%Y%m%d %H:%M:%S")
        e = datetime.strptime(end[:-4], "%Y%m%d %H:%M:%S")
        diff = e - s
        time = start_timer + diff.seconds
        print("{:<50}{:>10}{:>15}".format(cut_string(name), status.attrib["status"], time))
        print(dash)

        # check if the test has a tag that starts with "plot-",
        # if so store the result to create plot files for Jenkins
        for tag in test.findall("./tags/tag"):
            if "plot-" in tag.text:
                results[tag.text] = time
        start_timer = time

    if not os.path.isdir(plot_folder):
        os.mkdir(plot_folder)

    for k, v in results.items():
        f = open("%s/%s.txt" % (plot_folder, k), "a")
        f.write("%s\n" % format_key(k))
        f.write(str(v))
        f.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="collect-result")
    parser.add_argument("-r", "--robot-output", help="he robot output.xml file to process", default="output.xml"),
    parser.add_argument("-p", "--plot-folder", help="here to output the files needed for the Jenkins plots", default="plots")

    args = parser.parse_args()

    read_file(args.robot_output, args.plot_folder)
