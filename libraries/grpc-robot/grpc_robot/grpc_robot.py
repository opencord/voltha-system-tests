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
import grpc
import json
import getpass
import inspect
import logging
import logging.config
import tempfile
import textwrap
import importlib
import pkg_resources

from .tools.protop import ProtoBufParser
from distutils.version import StrictVersion
from robot.api.deco import keyword
from robot.libraries.BuiltIn import BuiltIn, RobotNotRunningError


def _package_version_get(package_name, source=None):
    """
    Returns the installed version number for the given pip package with name _package_name_.
    """

    if source:
        head, tail = os.path.split(os.path.dirname(os.path.abspath(source)))

        while tail:
            try:
                with open(os.path.join(head, 'VERSION')) as version_file:
                    return version_file.read().strip()
            except Exception:
                head, tail = os.path.split(head)

    try:
        return pkg_resources.get_distribution(package_name).version
    except pkg_resources.DistributionNotFound:
        raise NameError("Package '%s' is not installed!" % package_name)


class GrpcRobot(object):

    device = None
    package_name = ''
    installed_package = None

    try:
        ROBOT_LIBRARY_VERSION = _package_version_get('grpc_robot')
    except NameError:
        ROBOT_LIBRARY_VERSION = 'unknown'

    ROBOT_LIBRARY_SCOPE = 'TEST_SUITE'
    global_init = 0
    global_timeout = 120
    min_robot_version = 30202

    connection_type = 'grpc'

    def __init__(self, **kwargs):
        super().__init__()

        self._host = None
        self._port = None

        self.grpc_channel = None
        self.timeout = 30
        self.protobuf = None

        self.keywords = {}

        self.enable_logging()
        self.logger = logging.getLogger('grpc')

        self.pb_version = self.get_installed_version() or self.get_latest_pb_version()
        self.load_services(self.pb_version)

    @staticmethod
    def enable_logging():

        try:
            log_dir = BuiltIn().replace_variables('${OUTPUT_DIR}')
        except RobotNotRunningError:
            log_dir = tempfile.gettempdir()

        try:
            logfile_name = os.path.join(log_dir, 'grpc_robot_%s.log' % getpass.getuser())
        except KeyError:
            logfile_name = os.path.join(log_dir, 'grpc_robot.log')

        logging.config.dictConfig({
            'version': 1,
            'disable_existing_loggers': False,

            'formatters': {
                'standard': {
                    'format': '%(asctime)s %(name)s [%(levelname)s] : %(message)s'
                },
            },
            'handlers': {
                'file': {
                    'level': 'DEBUG',
                    'class': 'logging.FileHandler',
                    'mode': 'a',
                    'filename': logfile_name,
                    'formatter': 'standard'
                },
            },
            'loggers': {
                'grpc': {
                    'handlers': ['file'],
                    'level': 'DEBUG',
                    'propagate': True
                },
            }
        })

    @staticmethod
    def get_modules(*modules):
        module_list = []
        for module in modules:
            for name, obj in inspect.getmembers(module, predicate=lambda o: inspect.isclass(o)):
                module_list.append(obj)

        return module_list

    @staticmethod
    def get_keywords_from_modules(*modules):
        keywords = {}

        for module in modules:
            for name, obj in inspect.getmembers(module):
                if hasattr(obj, 'robot_name'):
                    keywords[name] = module

        return keywords

    def get_installed_version(self):
        dists = [str(d).split() for d in pkg_resources.working_set if str(d).split()[0] == self.package_name]

        try:
            pb_version = dists[0][-1]
            self.logger.info('installed package %s==%s' % (self.package_name, pb_version))
        except IndexError:
            self.logger.error('package for %s not installed' % self.package_name)
            return None

        if pb_version not in self.get_supported_versions():
            self.logger.warning('installed package %s==%s not supported by library, using version %s' % (
                self.package_name, pb_version, self.get_latest_pb_version()))
            pb_version = None

        return pb_version

    def get_supported_versions(self):

        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'services', self.device)

        return sorted([
            (name.split(self.device + '_')[1]).replace('_', '.')
            for name in os.listdir(path)
            if os.path.isdir(os.path.join(path, name)) and name.startswith(self.device)
        ], key=StrictVersion)

    def get_latest_pb_version(self):
        return self.get_supported_versions()[-1]

    def load_services(self, pb_version):
        pb_version = pb_version.replace('.', '_')
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'services', self.device, '%s_%s' % (self.device, pb_version))

        modules = importlib.import_module('grpc_robot.services.%s.%s_%s' % (self.device, self.device, pb_version))

        module_list = self.get_modules(modules)

        self.keywords = self.get_keywords_from_modules(*module_list)

        try:
            self.protobuf = json.loads(open(os.path.join(path, '%s.json' % self.device)).read())
            self.logger.debug('loaded services from %s' % os.path.join(path, '%s.json' % self.device))
        except FileNotFoundError:
            pip_dir = os.path.join(os.path.dirname(self.installed_package.__file__), 'protos')
            self.protobuf = ProtoBufParser(self.device, self.pb_version, pip_dir).parse_files()

    @keyword
    def get_keyword_names(self):
        """
        Returns the list of keyword names
        """
        return sorted(list(self.keywords.keys()) + [name for name in dir(self) if hasattr(getattr(self, name), 'robot_name')])

    def run_keyword(self, keyword_name, args, kwargs):
        """
        http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#running-keywords

        :param keyword_name: name of method to run
        :param args: arguments to this method
        :param kwargs: kwargs
        :return: whatever the method returns
        """
        if keyword_name in self.keywords:
            c = self.keywords[keyword_name](self)
        else:
            c = self

        return getattr(c, keyword_name)(*args, **kwargs)

    def get_keyword_arguments(self, keyword_name):
        """
        http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#getting-keyword-arguments

        :param keyword_name: name of method
        :return: list of method arguments like in urls above
        """

        if keyword_name in self.keywords:
            a = inspect.getargspec(getattr(self.keywords[keyword_name], keyword_name))
        else:
            a = inspect.getargspec(getattr(self, keyword_name))

        # skip "self" as first parameter -> [1:]
        args_without_defaults = a.args[1:-len(a.defaults)] if a.defaults is not None else a.args[1:]

        args_with_defaults = []
        if a.defaults is not None:
            args_with_defaults = zip(a.args[-len(a.defaults):], a.defaults)
            args_with_defaults = ['%s=%s' % (x, y) for x, y in args_with_defaults]

        args = args_without_defaults + args_with_defaults

        if a.varargs is not None:
            args.append('*%s' % a.varargs)

        if a.keywords is not None:
            args.append('**%s' % a.keywords)

        return args

    def get_keyword_documentation(self, keyword_name):
        """
        http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#getting-keyword-documentation
        http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#documentation-formatting

        :param keyword_name: name of method to get documentation for
        :return: string formatted according documentation
        """

        if keyword_name == '__intro__':
            return self.__doc__

        doc_string = ''

        if keyword_name in self.keywords:
            c = self.keywords[keyword_name]
            doc_string += textwrap.dedent(getattr(c, keyword_name).__doc__ or '') + '\n'
            doc_string += c(self).get_documentation(keyword_name)  # instanciate class and call "get_documentation"
            return doc_string

        return textwrap.dedent(getattr(self, keyword_name).__doc__ or '')

    @keyword
    def connection_open(self, host, port, **kwargs):
        """
        Opens a connection to the gRPC host.

        *Parameters*:
        - host: <string>|<IP address>; Name or IP address of the gRPC host.
        - port: <number>; TCP port of the gRPC host.

        *Named Parameters*:
        - timeout: <number>; Timeout in seconds for a gRPC response. Default: 30 s
        """
        self._host = host
        self._port = port
        self.timeout = int(kwargs.get('timeout', self.timeout))

        channel_options = [
            ('grpc.keepalive_time_ms', 10000),
            ('grpc.keepalive_timeout_ms', 5000)
        ]

        if kwargs.get('insecure', True):
            self.grpc_channel = grpc.insecure_channel('%s:%s' % (self._host, self._port), options=channel_options)
        else:
            raise NotImplementedError('other than "insecure channel" not implemented')

        user_pb_version = kwargs.get('pb_version') or self.pb_version
        pb_version = user_pb_version  # ToDo: or device_pb_version  # get the pb version from device when available

        self.load_services(pb_version)

    @keyword
    def connection_close(self):
        """
        Closes the connection to the gRPC host.
        """
        del self.grpc_channel
        self.grpc_channel = None

    def _connection_parameters_get(self):
        return {
            'timeout': self.timeout
        }

    @keyword
    def connection_parameters_set(self, **kwargs):
        """
        Sets the gRPC channel connection parameters.

        *Named Parameters*:
        - timeout: <number>; Timeout in seconds for a gRPC response.

        *Return*: Same dictionary as the keyword _Connection Parameter Get_ with the values before they got changed.
        """
        connection_parameters = self._connection_parameters_get()

        self.timeout = int(kwargs.get('timeout', self.timeout))

        return connection_parameters

    @keyword
    def connection_parameters_get(self):
        """
        Retrieves the connection parameters for the gRPC channel.

        *Return*: A dictionary with the keys:
        - timeout
        """
        return self._connection_parameters_get()

    @keyword
    def library_version_get(self):
        """
        Retrieve the version of the currently running library instance.

        *Return*: version string consisting of three dot-separated numbers (x.y.z)
        """
        return self.ROBOT_LIBRARY_VERSION
