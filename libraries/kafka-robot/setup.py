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
from setuptools import setup, find_packages

NAME = 'kafka_robot'
with open('VERSION') as ff:
    VERSION = ff.read().strip()
with open('VERSION') as ff:
    README = ff.read()
with open('VERSION') as ff:
    LICENSE = ff.read()

setup(
    name=NAME,
    version=VERSION,
    description='Package for recieving messages from Kafka in Robot Framework.',
    long_description=README,
    long_description_content_type="text/markdown",
    license=LICENSE,
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
    ],
    install_requires=[
        'six',
        'robotframework>=3.1.2',
        'kafka-python>=2.0.1'
    ],
    python_requires='>=3.6',
    packages=find_packages(exclude='tests'),
    data_files=[('', ['LICENSE'])]
)
