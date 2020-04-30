import xml.etree.ElementTree as ET
from datetime import datetime

dash = '-' * 70
double_dash = '=' * 70

def cut_string(str):
    return (str[:48] + '..') if len(str) > 50 else str

def read_file(file):
    # create element tree object
    tree = ET.parse(file)

    # get root element
    root = tree.getroot()

    print(double_dash)
    print('{:<50}{:>10}{:>10}'.format("Test Name", "Status", "Duration"))
    print(double_dash)
    for test in root.findall('./suite/test'):
        status = test.find('.status')
        start = status.attrib["starttime"]
        end = status.attrib["endtime"]
        s = datetime.strptime(start[:-4], '%Y%m%d %H:%M:%S')
        e = datetime.strptime(end[:-4], '%Y%m%d %H:%M:%S')
        diff = e - s
        print('{:<50}{:>10}{:>10}'.format(cut_string(test.attrib["name"]), status.attrib["status"], diff.seconds))
        print(dash)



if __name__ == '__main__':
    read_file("output.xml")
