from setuptools import Extension

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


def build(kwargs):
    kwargs.update({"ext_modules": ext_modules, "zip_safe": False})
