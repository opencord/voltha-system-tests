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
