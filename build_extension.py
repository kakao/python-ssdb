import os
import shutil

from Cython.Build import cythonize
from setuptools import Distribution, Extension
from setuptools.command.build_ext import build_ext


def build():
    extra_compile_args = ["-O3"]

    extensions = [
        Extension(
            name="ssdb.core.parser",
            sources=["./ssdb/core/parser.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.core.encode",
            sources=["./ssdb/core/encode.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.core.response",
            sources=["./ssdb/core/response.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.core.interface",
            sources=["./ssdb/core/interface.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.client",
            sources=["./ssdb/client.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.connection",
            sources=["./ssdb/connection.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.asyncio.client",
            sources=["./ssdb/asyncio/client.pyx"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            name="ssdb.asyncio.connection",
            sources=["./ssdb/asyncio/connection.pyx"],
            extra_compile_args=extra_compile_args,
        ),
    ]

    ext_modules = cythonize(extensions)

    dist = Distribution({"name": "extended", "ext_modules": ext_modules})

    cmd = build_ext(dist)
    cmd.ensure_finalized()
    cmd.run()

    for output in cmd.get_outputs():
        relative_extension = os.path.relpath(output, cmd.build_lib)
        shutil.copyfile(output, relative_extension)
        mode = os.stat(relative_extension).st_mode
        mode |= (mode & 0o444) >> 2
        os.chmod(relative_extension, mode)


if __name__ == "__main__":
    build()
