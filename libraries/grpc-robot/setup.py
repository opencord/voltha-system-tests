import os
from setuptools import setup, find_packages

NAME = 'grpc_robot'
with open('VERSION') as ff:
    VERSION = ff.read().strip()
with open('VERSION') as ff:
    README = ff.read()
with open('VERSION') as ff:
    LICENSE = ff.read()


def package_data():
    paths = []
    for (path, directories, filenames) in os.walk(NAME):
        for filename in filenames:
            if os.path.splitext(filename)[-1] == '.json':
                paths.append(os.path.join('..', path, filename))
    return paths


setup(
    name=NAME,
    version=VERSION,
    description='Package for sending/recieving messages to/from a gRPC server.',
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
        'grpcio',
        'decorator',
        'protobuf3-to-dict',
        'attrs',
        'parsy'
    ],
    python_requires='>=3.6',
    packages=find_packages(exclude='tests'),
    package_data={
        NAME: package_data(),
    },
    data_files=[("", ["LICENSE"])],
    entry_points={
        'console_scripts': ['grpc_robot.protop = grpc_robot.tools.protop:main'],
    }
)
