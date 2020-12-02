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
import grpc
from grpc import _channel, ChannelConnectivity
from decorator import decorator

from ..tools.protobuf_to_dict import protobuf_to_dict, dict_to_protobuf
from ..tools.robot_tools import Collections
from google.protobuf import empty_pb2


# decorator to check if connection is open
@decorator
def is_connected(library_function, *args, **kwargs):
    try:
        assert args[0].ctx.grpc_channel is not None
        grpc.channel_ready_future(args[0].ctx.grpc_channel).result(timeout=10)
    except (AssertionError, grpc.FutureTimeoutError):
        raise ConnectionError('not connected to a gRPC channel')

    return library_function(*args, **kwargs)


# unfortunately conversation from snake-case to camel-case does not work for all keyword names, so we define a mapping dict
kw_name_mapping = {
    'GetHwComponentInfo': 'GetHWComponentInfo',
    'SetHwComponentInfo': 'SetHWComponentInfo'
}

one_of_note = """*Note*: Bold dictionary keys are cases of an ONEOF type that is not transmitted in gRPC.\n"""
named_parameters_note = """*Named parameters*:\n
- return_enum_integer: <bool> or <string>; Whether or not to return the enum values as integer values rather than their labels. Default: _${FALSE}_ or _false_.\n
- return_defaults: <bool> or <string>; Whether or not to return the default values. Default: _${FALSE}_ or _false_.\n
- timeout: <int> or <string>; Number of seconds to wait for the response. Default: The timeout value set by keywords _Connection Open_ and _Connection Parameters Set_."""


class Service(object):

    prefix = ''

    def __init__(self, ctx, stub=None):
        super().__init__()
        self.ctx = ctx

        try:
            self.stub = stub(channel=ctx.grpc_channel)
        except AttributeError:
            self.stub = None

    def get_next_type_def(self, type_name, module):

        next_type_defs = [d for d in self.ctx.protobuf['data_types'] if d['name'] == type_name]

        if not next_type_defs:
            return None

        if len(next_type_defs) > 1:
            next_type_def = [d for d in next_type_defs if d['module'] == module]

            if next_type_def:
                return next_type_def[0]

            else:
                return next_type_defs[0]

        else:
            return next_type_defs[0]

    def lookup_type_def(self, _type_def, _indent='', _lookup_table=None, enum_indent=''):

        _lookup_table = _lookup_table or []

        if _type_def['name'] in _lookup_table:
            return '< recursive type: ' + _type_def['name'] + ' >'
        else:
            _lookup_table.append(_type_def['name'])

        if _type_def['type'] == 'message':

            doc_string = '{    # type: %s\n' % _type_def['name']
            _indent += '  '

            for field in _type_def['fields']:
                if field.get('is_choice', False):
                    doc_string += self.get_field_doc(field, _indent, _lookup_table[:], _type_def['module'], field['name'])
                else:
                    doc_string += "%s'%s': %s\n" % (_indent, field['name'], self.get_field_doc(field, _indent, _lookup_table[:], _type_def['module']))

            return doc_string + _indent[:-2] + '}'

        if _type_def['type'] == 'enum':

            try:
                k_len = 0
                for k, v in _type_def['values'].items():
                    k_len = max(len(k), k_len)
                enum = (' |\n %s%s' % (_indent, enum_indent)).join(['%s%s - %s' % ((k_len - len(k)) * ' ', k, v) for k, v in _type_def['values'].items()])

            except AttributeError:
                enum = ' | '.join(_type_def['values'])

            return '< %s >' % enum

        return ''

    def get_field_doc(self, _type_def, _indent, _lookup_table, module, choice_name=''):

        doc_string = ''

        _indent = (_indent + '  ') if _type_def.get('repeated', False) else _indent

        if _type_def.get('is_choice', False):
            for case in _type_def['cases']:
                # doc_string += "%s'*%s*' (ONEOF _%s_): %s\n" % (_indent, case['name'], choice_name, self.get_field_doc(case, _indent, _lookup_table[:], module))
                doc_string += "%s'_ONEOF %s_: *%s*': %s\n" % (_indent, choice_name, case['name'], self.get_field_doc(case, _indent, _lookup_table[:], module))

        elif _type_def.get('lookup', False):
            try:
                next_type_def = self.get_next_type_def(_type_def['type'], module=module)
                if next_type_def is not None:
                    doc_string += self.lookup_type_def(next_type_def, _indent, _lookup_table, (len(_type_def['name']) + 5) * ' ')
                else:
                    doc_string += "<%s>," % _type_def['type']

            except KeyError:
                doc_string += _type_def['type']
        else:
            doc_string += "<%s>," % _type_def['type']

        if _type_def.get('repeated', False):
            doc_string = '[    # list of:\n' + _indent + doc_string + '\n' + _indent[:-2] + ']'

        return doc_string

    def get_rpc_documentation(self, type_def, module):

        indent = '  ' if type_def['is_stream'] else ''

        if type_def['lookup']:
            next_type_def = self.get_next_type_def(type_def['type'], module)
            if next_type_def is not None:
                doc_string = self.lookup_type_def(next_type_def, indent)
            else:
                doc_string = type_def['type'] + '\n'
        else:
            doc_string = type_def['type'] + '\n'

        if type_def['is_stream']:
            return '[    # list of:\n' + indent + doc_string + '\n]'
        else:
            return doc_string

    def get_documentation(self, keyword_name):

        keyword_name = Collections.to_camel_case(keyword_name.replace(self.prefix, ''), True)
        keyword_name = kw_name_mapping.get(keyword_name, keyword_name)

        try:
            service = Collections.list_get_dict_by_value(self.ctx.protobuf.get('services', []), 'name', self.__class__.__name__)
        except KeyError:
            return 'no documentation available'

        rpc = Collections.list_get_dict_by_value(service.get('rpcs', []), 'name', keyword_name)

        doc_string = 'RPC _%s_ from _%s_.\n' % (rpc['name'], service['name'])
        doc_string += '\n\n*Parameters*:\n'

        for attr, attr_str in [('request', '- param_dict'), ('named_params', None), ('response', '*Return*')]:

            if rpc.get(attr) is not None:
                rpc_doc = '\n'.join(['| %s' % line for line in self.get_rpc_documentation(rpc.get(attr), service['module']).splitlines()])

                if rpc_doc == '| google.protobuf.Empty':
                    doc_string += '_none_\n\n'
                    continue

                doc_string += '\n%s:\n' % attr_str if '_ONEOF' not in rpc_doc else '\n%s: %s\n' % (attr_str, one_of_note)
                doc_string += rpc_doc + '\n'

            elif attr == 'named_params':
                doc_string += named_parameters_note

        return doc_string

    @staticmethod
    def to_protobuf(type_def, param_dict):
        try:
            return dict_to_protobuf(type_def or empty_pb2.Empty, param_dict or {})
        except Exception as e:
            raise ValueError('parameter dictionary does not match the ProtoBuf type definition: %s' % e)

    def _process_response(self, response, index=None, **kwargs):

        debug_text = 'RESPONSE' if index is None else 'RESPONSE-NEXT  ' if index else 'RESPONSE-STREAM'

        return_enum_integer = bool(str(kwargs.get('return_enum_integer', False)).lower() == 'true')
        return_defaults = bool(str(kwargs.get('return_defaults', False)).lower() == 'true')

        self.ctx.logger.debug('%s : data=%s' % (debug_text, response))
        _response = protobuf_to_dict(response, use_enum_labels=not return_enum_integer, including_default_value_fields=return_defaults)

        return _response

    def _grpc_helper(self, func, arg_type=None, param_dict=None, **kwargs):

        def generate_stream(arg, data_list):

            for idx, data in enumerate(data_list):
                _protobuf = self.to_protobuf(arg, data)
                debug_text = 'REQUEST-NEXT  :' if idx else 'REQUEST-STREAM : method=%s;' % func._method.decode()
                self.ctx.logger.debug('%s data=%s' % (debug_text, _protobuf))
                yield _protobuf

        if isinstance(param_dict, list):
            response = func(generate_stream(arg_type, param_dict), timeout=int(kwargs.get('timeout') or self.ctx.timeout))
        else:
            protobuf = self.to_protobuf(arg_type, param_dict)
            self.ctx.logger.debug('REQUEST : method=%s; data=%s' % (func._method.decode(), protobuf))
            response = func(protobuf, timeout=int(kwargs.get('timeout') or self.ctx.timeout))

        try:

            # streamed response is of type <grpc._channel._MultiThreadedRendezvous> and must be handle as list
            if isinstance(response, _channel._MultiThreadedRendezvous):

                return_list = []
                for idx, list_item in enumerate(response):
                    return_list.append(self._process_response(list_item, index=idx, **kwargs))

                return return_list

            else:

                return self._process_response(response, **kwargs)

        except grpc.RpcError as e:
            if e.code().name == 'DEADLINE_EXCEEDED':
                self.ctx.logger.error('TimeoutError (%ss): %s' % (kwargs.get('timeout') or self.ctx.timeout, e))
                raise TimeoutError('no response within %s seconds' % (kwargs.get('timeout') or self.ctx.timeout))
            else:
                self.ctx.logger.error(e)
                raise e

