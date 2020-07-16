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

# This tool collects CPU and Memory informations for each container in the VOLTHA stack

import argparse
import requests
import matplotlib.pyplot as plt
from datetime import datetime

EXCLUDED_POD_NAMES = [
    "kube", "coredns", "kind", "grafana",
    "prometheus", "tiller", "control-plane",
    "calico", "nginx", "registry"
]
CONTAINER_CPU_QUERY = "container_cpu_user_seconds_total{image!=''}[10m]"
CONTAINER_MEM_QUERY = "container_memory_usage_bytes{image!=''}[10m]"


def main(address, out_folder):
    """

    :param address string:
    :return:
    """
    r = requests.get("http://%s/api/v1/query" % address, {"query": CONTAINER_CPU_QUERY})
    print("Downloading CPU info from: %s" % r.url)
    container_cpu = r.json()["data"]["result"]
    plot_containers_data(remove_unwanted_containers(container_cpu),
                         figure="cpu", title="CPU User Seconds Total", ylabel="Seconds", output="./%s/cpu.pdf" % out_folder)

    r = requests.get("http://%s/api/v1/query" % address, {"query": CONTAINER_MEM_QUERY})
    print("Downloading Memory info from: %s" % r.url)
    container_mem = r.json()["data"]["result"]
    plot_containers_data(remove_unwanted_containers(container_mem),
                         figure="memory", title="Memory Usage", ylabel="Bytes", output="./%s/memory.pdf" % out_folder)


def remove_unwanted_containers(cpus):
    res = []
    for c in cpus:
        if "pod_name" in c["metric"]:

            pod_name = c["metric"]["pod_name"]
            container_name = c["metric"]["name"]

            if any(x in pod_name for x in EXCLUDED_POD_NAMES):
                continue

            if "k8s_POD" in container_name:
                # this is the kubernetes POD controller, we don't care about it
                continue


            res.append(c)
        else:
            continue

    return res


def plot_containers_data(containers, figure=None, title="Title", ylabel="", output=None):
    plt.figure(figure)
    plt.title(title)
    plt.xlabel("Timestamp")
    plt.ylabel(ylabel)

    for c in containers:
        name = c["metric"]["pod_name"]
        data = c["values"]

        dates = [datetime.fromtimestamp(x[0]) for x in data]
        values = [float(x[1]) for x in data]

        plt.plot(dates, values, label=name)

    plt.legend(loc='upper left')

    fig = plt.gcf()
    fig.set_size_inches(20, 11)

    plt.savefig(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="sizing")
    parser.add_argument("-a", "--address", help="The address of the Prometheus instance we're targeting",
                        default="127.0.0.1:31301")
    parser.add_argument("-o", "--output", help="here to output the generated files",
                        default="plots")

    args = parser.parse_args()
    main(args.address, args.output)
