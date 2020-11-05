import argparse
import csv
import glob
import re

STATS_TO_AGGREGATE = [
    'memory',
    'etcd_stats',
    'kafka_msg_per_topic',
    'cpu',
]


def data_to_csv(data, output=None):
    """
    Get a dictionary of lists saves a csv
    :param data: the input dictionary
    :type data: {metric: []values}
    :param output: the destination file
    :type output: str
    """

    csv_file = open(output, "w+")
    csv_writer = csv.writer(csv_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

    for k, v in data.items():
        csv_writer.writerow([k] + v)


def aggergateCpu(files):
    """
    Aggregates memory consuption from multiple runs of the pipeline
    :param files: The list of files to aggregate
    :type files: []str
    :return: a dictionary of aggregate stats
    :rtype: {podName: []values}
    """
    cpu_values = {}

    for file in files:
        csv_file = open(file)
        csv_reader = csv.reader(csv_file, delimiter=',')

        for row in csv_reader:
            # for each row remove the random chars from the pod name
            # and concat the values to the existing one
            regex = "(.*)-[a-z0-9]{9,10}-[a-z0-9]{5}$"
            x = re.search(regex, row[0])

            if x is not None:
                podName = x.groups(1)[0]
                if not podName in cpu_values:
                    cpu_values[podName] = []

                cpu_values[podName] = cpu_values[podName] + row[1:]

    return cpu_values


def aggregateMemory(files):
    """
    Aggregates memory consuption from multiple runs of the pipeline
    :param files: The list of files to aggregate
    :type files: []str
    :return: a dictionary of aggregate stats 
    :rtype: {podName: []values}
    """
    # this function assumes that the files are ordered by time

    mem_values = {}

    for file in files:
        csv_file = open(file)
        csv_reader = csv.reader(csv_file, delimiter=',')

        for row in csv_reader:
            # for each row remove the random chars from the pod name
            # and concat the values to the existing one
            regex = "(.*)-[a-z0-9]{9,10}-[a-z0-9]{5}$"
            x = re.search(regex, row[0])

            if x is not None:
                podName = x.groups(1)[0]
                if not podName in mem_values:
                    mem_values[podName] = []

                mem_values[podName] = mem_values[podName] + row[1:]

    return mem_values


def aggregateEtcd(files):
    etcd_size = {}
    etcd_keys = {}

    for file in files:
        csv_file = open(file)
        csv_reader = csv.reader(csv_file, delimiter=',')

        regex = ".*\/([0-9-]{5})\/.*"
        topology = re.search(regex, file).groups(1)[0]

        for row in csv_reader:
            if row[0] == "keys":
                if topology not in etcd_keys:
                    etcd_keys[topology] = []
                etcd_keys[topology].append(row[1])
            if row[0] == "size":
                if topology not in etcd_size:
                    etcd_size[topology] = []
                etcd_size[topology].append(row[1])
    return [etcd_keys, etcd_size]

def aggregateKafka(files):
    kafka = {}

    for file in files:
        csv_file = open(file)
        csv_reader = csv.reader(csv_file, delimiter=',')

        for row in csv_reader:
            topic = row[0]
            count = row[1]

            if topic not in kafka:
                kafka[topic] = []
            kafka[topic].append(count)
    return kafka

def aggregateStats(stat, files, out_dir):
    # sort file in alphabetical order
    # we assume that we always run the topologies in incremental order
    files.sort()
    if stat == "memory":
        agg = aggregateMemory(files)
        data_to_csv(agg, output="%s/aggregated-memory.csv" % out_dir)
    if stat == "cpu":
        agg = aggregateMemory(files)
        data_to_csv(agg, output="%s/aggregated-cpu.csv" % out_dir)
    if stat == "etcd_stats":
        [keys, size] = aggregateEtcd(files)
        data_to_csv(keys, output="%s/aggregated-etcd-keys.csv" % out_dir)
        data_to_csv(size, output="%s/aggregated-etcd-size.csv" % out_dir)
    if stat == "kafka_msg_per_topic":
        agg = aggregateKafka(files)
        data_to_csv(agg, output="%s/aggregated-kafka-msg-count.csv" % out_dir)


def main(source, out_dir):
    for stat in STATS_TO_AGGREGATE:
        files = [f for f in glob.iglob('%s/**/%s.csv' % (source, stat), recursive=True)]
        aggregateStats(stat, files, out_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="stats-aggregation")
    parser.add_argument("-o", "--output", help="Where to output the generated files", default="plots")
    parser.add_argument("-s", "--source", help="Directory in which to look for stats", required=True)

    args = parser.parse_args()
    main(args.source, args.output)
