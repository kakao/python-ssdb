import os

from setuptools import Extension, find_packages, setup

ext_modules = [
    Extension(
        name="ssdb.core.parser",
        sources=["./ssdb/core/parser.pyx"],
    ),
    Extension(
        name="ssdb.core.encode",
        sources=["./ssdb/core/encode.pyx"],
    ),
    Extension(
        name="ssdb.core.response",
        sources=["./ssdb/core/response.pyx"],
    ),
    Extension(
        name="ssdb.core.interface",
        sources=["./ssdb/core/interface.pyx"],
    ),
    Extension(
        name="ssdb.client",
        sources=["./ssdb/client.pyx"],
    ),
    Extension(
        name="ssdb.connection",
        sources=["./ssdb/connection.pyx"],
    ),
    Extension(
        name="ssdb.asyncio.client",
        sources=["./ssdb/asyncio/client.pyx"],
    ),
    Extension(
        name="ssdb.asyncio.connection",
        sources=["./ssdb/asyncio/connection.pyx"],
    ),
]


def read(file_name):
    """Read a text file and return the content as a string."""
    file_path = os.path.join(os.path.dirname(__file__), file_name)
    with open(file_path, encoding="utf-8") as f:
        return f.read()


setup(
    name="python-ssdb",
    version="1.0.4rc1",
    description="SSDB Python Client",
    long_description=read("README.md"),
    python_requires=">3.9",
    author="recoteam",
    author_email="recoteam@kakaocorp.com",
    url="https://github.com/kakao/python-ssdb",
    license="Apache2",
    keywords="SSDB",
    classifiers=[
        "License :: Apache Software License",
        "Operating System :: Linux",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Cython",
    ],
    packages=find_packages(include=["ssdb", "ssdb.core", "ssdb.asyncio"]),
    ext_modules=ext_modules,
)
