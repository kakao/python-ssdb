# cython: language_level=3, boundscheck=False, wraparound=False, embedsignature=True

from typing import TypeVar

from ssdb.connection cimport Connection, ConnectionPool
from ssdb.core cimport SSDBInterface, wrap_response

T = TypeVar("T")


cdef class SSDB(SSDBInterface):
    cdef Connection connection
    cdef ConnectionPool connection_pool

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
        if single_connection_client:
            self.connection = self.connection_pool.get_connection()

    def __dealloc__(self) -> None:
        self.close()

    def __repr__(self) -> str:
        return f"{self.__class__.__name__}<{repr(self.connection_pool)}>"

    def __enter__(self) -> "SSDB":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()

    cpdef void close(self):
        cdef Connection conn = self.connection
        if conn is not None:
            self.connection = None
            self.connection_pool.release(conn)
        self.connection_pool.disconnect()

    def execute_command(self, str cmd, *args) -> T:
        cdef ConnectionPool pool = self.connection_pool
        cdef Connection conn = self.connection or pool.get_connection()

        conn.send_command(cmd, args)
        try:
            return wrap_response(cmd, conn.read_response())
        except Exception:
            raise
        finally:
            if self.connection is None:
                pool.release(conn)
