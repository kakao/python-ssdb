# cython: language_level=3, boundscheck=False, wraparound=False

import os
import socket
import threading
from itertools import chain

from libc.stdint cimport INT32_MAX

from ssdb.core cimport Reader
from ssdb.core import encode_command


cdef class Connection:
    def __cinit__(
        self,
        str host="localhost",
        int port=7036,
        str password=None,
        bint socket_keepalive=False,
        dict socket_keepalive_options=None,
        int socket_recv_size=65536,
    ):
        self.pid = os.getpid()
        self.host = host
        self.port = port
        self.password = password
        self.socket_keepalive = socket_keepalive
        self.socket_keepalive_options = socket_keepalive_options or {}
        self.socket_recv_size = socket_recv_size
        self.parser = Reader()
        self.sock = None
        self.next_response = None

    def __dealloc__(self):
        try:
            self.disconnect()
        except Exception:
            pass

    def __repr__(self) -> str:
        args = [("host", self.host), ("port", self.port)]
        args = ",".join(f"{k}={v}" for k, v in args)
        return f"{self.__class__.__name__}({args})"

    cdef inline bint is_connected(self):
        return self.sock is not None

    cdef inline bint read_from_socket(self, bint wait) except *:
        cdef bytes data
        if not wait:
            self.sock.settimeout(0)
        try:
            data = self.sock.recv(self.socket_recv_size)
            if not data:
                raise ConnectionError("Server closed")
            self.parser.feed(data)
            return True
        except BlockingIOError:
            # timeout catched here
            return False
        except Exception:
            raise
        finally:
            if not wait:
                self.sock.settimeout(None)

    cdef inline void connect(self) except *:
        if self.is_connected():
            return
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            if self.socket_keepalive:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                for k, v in self.socket_keepalive_options.items():
                    sock.setsockopt(socket.IPPROTO_TCP, k, v)
            sock.connect((self.host, self.port))
            self.sock = sock
            if self.password is not None:
                self.send_command("auth", self.password)
                try:
                    _ = self.read_response()
                except Exception:
                    raise RuntimeError("Invalid password")
        except socket.error:
            raise

    cdef inline void disconnect(self):
        if not self.is_connected():
            return

        if os.getpid() == self.pid:
            try:
                self.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

        try:
            self.sock.close()
        except OSError:
            pass
        self.sock = None

    cdef inline bint in_use(self) except *:
        if self.next_response is None:
            self.next_response = self.parser.get()
        if self.next_response is None:
            try:
                return self.read_from_socket(False)
            except Exception:
                self.disconnect()
                raise
        return True

    cdef inline list read_response(self):
        if self.next_response is not None:
            resp, self.next_response = self.next_response, None
            return resp

        resp = self.parser.get()
        while resp is None:
            self.read_from_socket(True)
            resp = self.parser.get()
        return resp

    cdef inline void send_command(self, str cmd, tuple args):
        body = encode_command(cmd, args)
        self.sock.sendall(body)


cdef class ConnectionPool:
    def __init__(self, int max_connections=0, **connection_kwargs):
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

    cdef inline void reset(self):
        self.created_connections = 0
        self.available_connections = []
        self.in_use_connections = set()
        self.lock = threading.Lock()

    cdef inline void checkpid(self) except *:
        if self.pid != os.getpid():
            acquired = self.fork_lock.acquire(timeout=5)
            if not acquired:
                raise Exception("ChildDeadLockError")
            try:
                if self.pid != os.getpid():
                    self.reset()
            finally:
                self.fork_lock.release()

    cdef inline bint owns_connection(self, Connection connection):
        return connection.pid == self.pid

    cdef inline Connection make_connection(self):
        if self.created_connections >= self.max_connections:
            raise ConnectionError("Too many connections")
        self.created_connections += 1
        return Connection(**self.connection_kwargs)

    cdef inline void release(self, Connection connection):
        self.checkpid()
        with self.lock:
            if connection in self.in_use_connections:
                self.in_use_connections.remove(connection)

            if self.owns_connection(connection):
                self.available_connections.append(connection)
            else:
                self.created_connections -= 1
                connection.disconnect()

    cdef inline Connection get_connection(self):
        cdef Connection connection
        self.checkpid()
        with self.lock:
            if len(self.available_connections) > 0:
                connection = self.available_connections.pop()
            else:
                connection = self.make_connection()
            self.in_use_connections.add(connection)

        try:
            connection.connect()

            try:
                if connection.in_use():
                    raise ConnectionError("Connection in use")
            except ConnectionError:
                connection.disconnect()
                connection.connect()
                if connection.in_use():
                    raise ConnectionError("Connection not ready")
        except Exception:
            self.release(connection)
            raise
        return connection

    cdef inline void disconnect(self) except *:
        cdef Connection connection
        exc = None
        self.checkpid()
        with self.lock:
            connections = chain(self.available_connections, self.in_use_connections)
            for connection in connections:
                try:
                    connection.disconnect()
                except Exception as e:
                    exc = e
            if exc is not None:
                raise exc
