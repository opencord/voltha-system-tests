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

# NOTE
# Collecting the info for all containers in the same chart can be confusing,
# we may want to create subcharts for the different groups, eg: infra, ONOS, core, adapters

import argparse
import requests
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
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

            if "_0" not in container_name:
                # this is something with the ONOS chart that is weird (each POD is reported 3 times)
                continue

            res.append(c)
        else:
            continue

    return res


def plot_containers_data(containers, figure=None, title="Title", ylabel="", output=None):
    plt.figure(figure)
    fig, ax = plt.subplots()
    plt.title(title)
    plt.xlabel("Timestamp")
    plt.ylabel(ylabel)
    fmt = mdates.DateFormatter('%H:%M:%S')
    ax.xaxis.set_major_formatter(fmt)

    for c in containers:
        name = c["metric"]["pod_name"]
        data = c["values"]

        dates = [datetime.fromtimestamp(x[0]) for x in data]
        values = [float(x[1]) for x in data]

        plt.plot(dates, values, label=name, lw=2, color=get_line_color(name))

    plt.legend(loc='upper left')

    fig = plt.gcf()
    fig.set_size_inches(20, 11)

    plt.savefig(output)


def get_line_color(container_name):
    colors = {
        "bbsim0": "#884EA0",
        "bbsim1": "#9B59B6",
        "bbsim-sadis-server": "#D2B4DE",
        "onos-atomix-0": "#85C1E9",
        "onos-atomix-1": "#7FB3D5",
        "onos-atomix-2": "#3498DB",
        "onos-onos-classic-0": "#1A5276",
        "onos-onos-classic-1": "#1B4F72",
        "onos-onos-classic-2": "#154360",
        "etcd-0": "#7D6608",
        "etcd-1": "#9A7D0A",
        "etcd-2": "#B7950B",
        "open-olt-voltha-adapter-openolt": "#7E5109",
        "open-onu-voltha-adapter-openonu-0": "#6E2C00",
        "open-onu-voltha-adapter-openonu-1": "#873600",
        "open-onu-voltha-adapter-openonu-2": "#A04000",
        "open-onu-voltha-adapter-openonu-3": "#BA4A00",
        "open-onu-voltha-adapter-openonu-4": "#D35400",
        "open-onu-voltha-adapter-openonu-5": "#D35400",
        "open-onu-voltha-adapter-openonu-6": "#E59866",
        "open-onu-voltha-adapter-openonu-7": "#EDBB99",
        "kafka-0": "#4D5656",
        "kafka-1": "#5F6A6A",
        "kafka-2": "#717D7E",
        "kafka-zookeeper-0": "#839192",
        "kafka-zookeeper-1": "#95A5A6",
        "kafka-zookeeper-2": "#717D7E",
        "radius": "#82E0AA",
        "voltha-voltha-ofagent": "#641E16",
        "voltha-voltha-rw-core": "#7B241C",
    }

    if container_name in colors:
        return colors[container_name]
    elif "openolt" in container_name:
        return colors["open-olt-voltha-adapter-openolt"]
    elif "ofagent" in container_name:
        return colors["voltha-voltha-ofagent"]
    elif "rw-core" in container_name:
        return colors["voltha-voltha-rw-core"]
    elif "bbsim0" in container_name:
        return colors["bbsim0"]
    elif "bbsim1" in container_name:
        return colors["bbsim1"]
    elif "bbsim-sadis-server" in container_name:
        return colors["bbsim-sadis-server"]
    elif "radius" in container_name:
        return colors["radius"]
    else:
        return "black"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="sizing")
    parser.add_argument("-a", "--address", help="The address of the Prometheus instance we're targeting",
                        default="127.0.0.1:31301")
    parser.add_argument("-o", "--output", help="here to output the generated files",
                        default="plots")

    args = parser.parse_args()
    main(args.address, args.output)
