# Copyright 2021-present Open Networking Foundation
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

# This tool collects instantaneous memory usage for voltha pods


import argparse
import requests
from datetime import datetime

containers_for_mem_collection = ["voltha", "ofagent", "adapter-open-olt", "adapter-open-onu"]


def main(address, out_folder, namespace="default"):
    """
    Query Prometheus and generate instantaneous memory consumptions for all the pods under test
    :param address: string The address of the Prometheus instance to query
    :param out_folder: string The output folder (where to save the .pdf files)
    :param namespace: string The pod namespace
    :return: void
    """
    for container in containers_for_mem_collection:
        container_mem_query = 'container_memory_working_set_bytes{namespace="%s",container="%s"}' % (namespace, container)

        mem_params = {
            "query": container_mem_query,
        }
        print("mem usage query: %s" % mem_params)

        r = requests.get("http://%s/api/v1/query" % address, mem_params)
        print("Downloading mem info from: %s" % r.url)
        container_cpu = r.json()["data"]["result"]
        # print("result for container %s is : " % container, container_cpu)
        if len(container_cpu) > 0:
            print(container_cpu[0]["value"][1])
            fp = open(out_folder+"/"+container+".txt", "a")
            result_in_csv_fmt = "%s,%s\n" % (datetime.now().strftime("%H:%M:%S.%f - %b %d %Y"), container_cpu[0]["value"][1])
            fp.write(result_in_csv_fmt)
        else:
            print("error fetching memory usage for container: %s", container)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="mem_consumption")
    parser.add_argument("-a", "--address", help="The address of the Prometheus instance we're targeting",
                        default="127.0.0.1:31301")
    parser.add_argument("-o", "--output", help="Where to output the generated files",
                        default="voltha-pods-mem-consumption")
    parser.add_argument("-n", "--namespace", help="Kubernetes namespace for collecting metrics",
                        default="voltha")

    args = parser.parse_args()
    main(args.address, args.output, args.namespace)
