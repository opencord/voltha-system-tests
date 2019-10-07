# Copyright 2019 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
from robot.libraries.BuiltIn import BuiltIn

class DependencyLibrary(object):
    ROBOT_LISTENER_API_VERSION = 2
    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    def __init__(self):
        self.ROBOT_LIBRARY_LISTENER = self
        self.test_status = {}

    def require_test_case(self, name):
        key = name.lower()
        if (key not in self.test_status):
            BuiltIn().fail("required test case can't be found: '%s'" % name)

        if (self.test_status[key] != "PASS"):
            BuiltIn().fail("required test case failed: '%s'" % name)

        return True

    def _end_test(self, name, attrs):
        self.test_status[name.lower()] = attrs["status"]
