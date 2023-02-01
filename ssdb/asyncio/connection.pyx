# cython: language_level=3, boundscheck=False, wraparound=False

import asyncio
import os
import socket
import threading
from itertools import chain
from typing import List

from libc.stdint cimport INT32_MAX

from ssdb.core cimport Reader

from ssdb.core import encode_command


class Connection:
    def __init__(
        self,
        str host="localhost",
        int port=7036,
        str password=None,
        bint socket_keepalive=False,
        dict socket_keepalive_options=None,
        int socket_recv_size=65536,
    ) -> None:
        self.pid = os.getpid()
        self.host = host
        self.port = port
        self.password = password
        self.socket_keepalive = socket_keepalive
        self.socket_keepalive_options = socket_keepalive_options or {}
        self.socket_recv_size = socket_recv_size
        self.parser = Reader()
        self.reader = None
        self.writer = None
        self.next_response = None

    def __del__(self) -> None:
        try:
            if self.is_connected():
                loop = asyncio.get_event_loop()
                coro = self.disconnect()
                if loop.is_running():
                    loop.create_task(coro)
                else:
                    loop.run_until_complete(coro)
        except Exception:
            pass

    def __repr__(self) -> str:
        args = [("host", self.host), ("port", self.port)]
        args = ",".join(f"{k}={v}" for k, v in args)
        return f"{self.__class__.__name__}({args})"

    def is_connected(self) -> bool:
        return self.reader is not None and self.writer is not None

    async def read_from_socket(self, bint wait) -> bool:
        try:
            coro = self.reader.read(self.socket_recv_size)
            data = await coro if wait else await asyncio.wait_for(coro, 0)
            if not data:
                raise ConnectionError("Server closed")
            self.parser.feed(data)
            return True
        except asyncio.CancelledError:
            raise
        except asyncio.TimeoutError:
            return False

    async def connect(self) -> None:
        if self.is_connected():
            return
        self.reader, self.writer = await asyncio.open_connection(host=self.host, port=self.port)
        sock = self.writer.transport.get_extra_info("socket")
        if sock is not None:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            if self.socket_keepalive:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                for k, v in self.socket_keepalive_options.items():
                    sock.setsockopt(socket.IPPROTO_TCP, k, v)

        if self.password is not None:
            await self.send_command("auth", self.password)
            try:
                _ = await self.read_response()
            except Exception:
                raise RuntimeError("Invalid password")

    async def disconnect(self) -> None:
        if not self.is_connected():
            return

        if os.getpid() == self.pid:
            try:
                self.writer.close()
                await self.writer.wait_closed()
            except OSError:
                pass

        self.reader = None
        self.writer = None

    async def in_use(self) -> bool:
        if self.next_response is None:
            self.next_response = self.parser.get()
        if self.next_response is None:
            try:
                return await self.read_from_socket(False)
            except Exception:
                await self.disconnect()
                raise
        return True

    async def read_response(self) -> List[bytes]:
        if self.next_response is not None:
            resp, self.next_response = self.next_response, None
            return resp

        resp = self.parser.get()
        while resp is None:
            await self.read_from_socket(True)
            resp = self.parser.get()
        return resp

    async def send_command(self, str cmd, tuple args) -> None:
        body = encode_command(cmd, args)
        self.writer.write(body)
        await self.writer.drain()


class ConnectionPool:
    def __init__(self, int max_connections=0, **connection_kwargs) -> None:
        self.pid = os.getpid()
        self.max_connections = max_connections if max_connections > 0 else INT32_MAX
        self.connection_kwargs = connection_kwargs
        self.fork_lock = threading.Lock()
        self.reset()

    def __repr__(self) -> str:
        return (
            f"{self.__class__.__name__}"
            f"<{repr(Connection(**self.connection_kwargs))}>"
        )

    def reset(self) -> None:
        self.created_connections = 0
        self.available_connections = []
        self.in_use_connections = set()
        self.lock = asyncio.Lock()

    def checkpid(self) -> None:
        if self.pid != os.getpid():
            acquired = self.fork_lock.acquire(timeout=5)
            if not acquired:
                raise Exception("ChildDeadLockError")
            try:
                if self.pid != os.getpid():
                    self.reset()
            finally:
                self.fork_lock.release()

    def owns_connection(self, connection: Connection) -> bool:
        return connection.pid == self.pid

    def make_connection(self) -> Connection:
        if self.created_connections >= self.max_connections:
            raise ConnectionError("Too many connections")
        self.created_connections += 1
        return Connection(**self.connection_kwargs)

    async def release(self, connection: Connection) -> None:
        self.checkpid()
        async with self.lock:
            if connection in self.in_use_connections:
                self.in_use_connections.remove(connection)

            if self.owns_connection(connection):
                self.available_connections.append(connection)
            else:
                self.created_connections -= 1
                await connection.disconnect()

    async def get_connection(self) -> Connection:
        self.checkpid()
        async with self.lock:
            if len(self.available_connections) > 0:
                connection = self.available_connections.pop()
            else:
                connection = self.make_connection()
            self.in_use_connections.add(connection)

        try:
            await connection.connect()

            try:
                if await connection.in_use():
                    raise ConnectionError("Connection in use")
            except ConnectionError:
                await connection.disconnect()
                await connection.connect()
                if await connection.in_use():
                    raise ConnectionError("Connection not ready")
        except Exception:
            await self.release(connection)
            raise
        return connection

    async def disconnect(self) -> None:
        self.checkpid()
        async with self.lock:
            connections = chain(self.available_connections, self.in_use_connections)
            resp = await asyncio.gather(
                *(connection.disconnect() for connection in connections),
                return_exceptions=True,
            )
            exc = next((r for r in resp if isinstance(r, Exception)), None)
            if exc:
                raise exc
