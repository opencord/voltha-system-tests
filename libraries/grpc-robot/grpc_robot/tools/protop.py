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
import os
import re
import glob
import json
import argparse

try:
    from . import protobuf_parse as parser
except ImportError:
    import protobuf_parse as parser

__version__ = '1.0'

USAGE = """ProtoBuf -- Parser of Protocol Buffer to create the input JSON file for the library

Usage:  grpc_robot.protop [options] target_version

ProtoBuf parser can be used to parse ProtoBuf files (*.proto) into a json formatted input file 
for the grpc_robot library to be used for keyword documentation.

"""

EPILOG = """
Example
=======
# Executing `grpc_robot.protop` module using Python.
$ grpc_robot.protop -i /home/user/Workspace/grpc/proto/dmi 0.9.1
"""


class ProtoBufParser(object):

    def __init__(self, target, target_version, input_dir, output_dir=None):

        super().__init__()

        self.target = target
        self.target_version = target_version.replace('.', '_')
        self.input_dir = input_dir
        self.output_dir = output_dir

    @staticmethod
    def read_enum(enum, protobuf_dict, module):
        enum_dict = {'name': enum.name, 'type': 'enum', 'module': module, 'values': {ef.value: ef.name for ef in enum.body}}
        protobuf_dict['data_types'].append(enum_dict)

    def read_message(self, message, protobuf_dict, module):
        message_dict = {'name': message.name, 'type': 'message', 'module': module, 'fields': []}

        for f in message.body:

            if f is None:
                continue

            if isinstance(f, parser.Enum):
                self.read_enum(f, protobuf_dict, module)
                continue

            elif isinstance(f, parser.Message):
                self.read_message(f, protobuf_dict, module)
                continue

            field_dict = {'name': f.name, 'is_choice': isinstance(f, parser.OneOf)}

            if isinstance(f, parser.Field):
                field_dict['repeated'] = f.repeated

                try:
                    field_dict['type'] = f.type._value_
                    field_dict['lookup'] = False
                except AttributeError:
                    field_dict['type'] = f.type
                    field_dict['lookup'] = True

            elif isinstance(f, parser.OneOf):
                field_dict['cases'] = []
                for c in f.fields:
                    case_dict = {'name': c.name}
                    try:
                        case_dict['type'] = c.type._value_
                        case_dict['lookup'] = False
                    except AttributeError:
                        case_dict['type'] = c.type
                        case_dict['lookup'] = True
                    field_dict['cases'].append(case_dict)

            message_dict['fields'].append(field_dict)

        protobuf_dict['data_types'].append(message_dict)

    def parse_files(self):

        protobuf_dict = {
            'modules': [],
            'data_types': [],
            'services': []
        }

        for file_name in glob.glob(os.path.join(self.input_dir, '*.proto')):
            print(file_name)

            module = os.path.splitext(os.path.basename(file_name))[0]
            module_dict = {'name': module, 'imports': []}

            # the protobuf parser can not handle comments "// ...", so remove them first from the file
            file_content = re.sub(r'\/\/.*', '', open(file_name).read())
            parsed = parser.proto.parse(file_content)

            # print(parsed.statements)

            for p in parsed.statements:
                # print(p)

                if isinstance(p, parser.Import):
                    module_dict['imports'].append(os.path.splitext(os.path.basename(p.identifier))[0])

                elif isinstance(p, parser.Enum):
                    self.read_enum(p, protobuf_dict, module)

                elif isinstance(p, parser.Message):
                    self.read_message(p, protobuf_dict, module)

                elif isinstance(p, parser.Service):
                    service_dict = {'name': p.name, 'module': module, 'rpcs': []}

                    for field in p.body:

                        if isinstance(field, parser.Enum):
                            self.read_enum(field, protobuf_dict, module)

                        elif isinstance(field, parser.Message):
                            self.read_message(field, protobuf_dict, module)

                        elif isinstance(field, parser.Rpc):
                            rpc_dict = {'name': field.name, 'request': {}, 'response': {}}

                            for attr in ['request', 'response']:
                                try:
                                    rpc_dict[attr]['is_stream'] = field.__getattribute__('%s_stream' % attr)

                                    try:
                                        rpc_dict[attr]['type'] = field.__getattribute__('%s_message_type' % attr)._value_
                                        rpc_dict[attr]['lookup'] = False
                                    except AttributeError:
                                        rpc_dict[attr]['type'] = field.__getattribute__('%s_message_type' % attr)
                                        rpc_dict[attr]['lookup'] = not rpc_dict[attr]['type'].lower().startswith('google.protobuf.')

                                except AttributeError:
                                    rpc_dict[attr] = None

                            service_dict['rpcs'].append(rpc_dict)

                    protobuf_dict['services'].append(service_dict)

            protobuf_dict['modules'].append(module_dict)

        if self.output_dir is not None:
            json_file_name = os.path.join(self.output_dir, self.target, '%s_%s' % (self.target, self.target_version), '%s.json' % self.target)
            json.dump(protobuf_dict, open(json_file_name, 'w'))

        return protobuf_dict


base_dir = os.path.dirname(os.path.realpath(__file__))
output_base_dir = os.path.join(os.path.split(base_dir)[:-1][0], 'services')


def main():
    # create commandline parser
    arg_parse = argparse.ArgumentParser(description=USAGE, epilog=EPILOG, formatter_class=argparse.RawTextHelpFormatter)

    # add parser options
    arg_parse.add_argument('target', choices=['dmi', 'voltha'],
                           help="Target type of which the ProtocolBuffer files shall be converted to the JSON file.")
    arg_parse.add_argument('target_version', help="Version number of the ProtocolBuffer files.")

    arg_parse.add_argument('-i', '--inputdir', default=os.getcwd(), help="Path to the location of the ProtocolBuffer files.")
    arg_parse.add_argument('-o', '--outputdir', default=os.getcwd(), help="Path to the location JSON file to be stored.")

    arg_parse.add_argument('-v', '--version', action='version', version=__version__)
    arg_parse.set_defaults(feature=False)

    # parse commandline
    args = arg_parse.parse_args()

    ProtoBufParser(args.target, args.target_version, args.inputdir or os.getcwd(), args.outputdir or output_base_dir).parse_files()


if __name__ == '__main__':
    main()
