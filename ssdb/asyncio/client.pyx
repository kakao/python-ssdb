# cython: language_level=3, boundscheck=False, wraparound=False, embedsignature=True

import asyncio
from typing import TypeVar

from ssdb.core cimport SSDBInterface, wrap_response

from ssdb.asyncio.connection import Connection, ConnectionPool

T = TypeVar("T")


class SSDB(SSDBInterface):
    def __init__(
        self,
        str host = "localhost",
        int port = 7036,
        str password = None,
        bint socket_keepalive=False,
        dict socket_keepalive_options=None,
        int socket_recv_size = 65536,
        int max_connections = 0,
        bint single_connection_client = False,
    ) -> None:
        connection_kwargs = {
            "host": host,
            "port": port,
            "socket_recv_size": socket_recv_size,
            "socket_keepalive": socket_keepalive,
            "socket_keepalive_options": socket_keepalive_options,
        }
        self.connection_pool = ConnectionPool(max_connections, **connection_kwargs)
        self.connection = None
        self.single_connection_client = single_connection_client

    def __del__(self) -> None:
        try:
            loop = asyncio.get_event_loop()
            coro = self.close()
            if loop.is_running():
                loop.create_task(coro)
            else:
                loop.run_until_complete(coro)
        except:
            pass

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}<{repr(self.connection_pool)}>"

    def __await__(self):
        return self.initialize().__await__()

    async def __aenter__(self) -> "SSDB":
        return self.initialize()

    async def __aexit__(self, exc_type, exc_value, traceback) -> None:
        await self.close()

    async def initialize(self) -> "SSDB":
        if self.single_connection_client and self.connection is None:
            self.connection = await self.connection_pool.get_connection()
        return self

    async def close(self) -> None:
        conn = self.connection
        if conn is not None:
            self.connection = None
            await self.connection_pool.release(conn)
        await self.connection_pool.disconnect()

    async def execute_command(self, str cmd, *args) -> T:
        await self.initialize()
        pool = self.connection_pool
        conn = self.connection or await pool.get_connection()

        await conn.send_command(cmd, args)
        try:
            return wrap_response(cmd, await conn.read_response())
        except Exception:
            raise
        finally:
            if self.connection is None:
                await pool.release(conn)
