import xml.etree.ElementTree as ET
from datetime import datetime

def read_file(file):
    # create element tree object
    tree = ET.parse(file)

    # get root element
    root = tree.getroot()

    for test in root.findall('./suite/test'):
        status = test.find('.status')
        start = status.attrib["starttime"]
        end = status.attrib["endtime"]
        s = datetime.strptime(start[:-4], '%Y%m%d %H:%M:%S')
        e = datetime.strptime(end[:-4], '%Y%m%d %H:%M:%S')
        diff = e - s
        print("------------------")
        print("%s \t %d seconds" % (test.attrib["name"], diff.seconds))

    print("------------------")


if __name__ == '__main__':
    read_file("output.xml")
