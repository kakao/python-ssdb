# cython: language_level=3

from ssdb.core cimport Reader


cdef class Connection:
    cdef bint socket_keepalive
    cdef int pid, port, socket_recv_size
    cdef Reader parser
    cdef str host, password
    cdef dict socket_keepalive_options
    cdef object sock, next_response

    cdef inline bint is_connected(self)
    cdef inline bint read_from_socket(self, bint wait) except *
    cdef inline void connect(self) except *
    cdef inline void disconnect(self)
    cdef inline bint in_use(self) except *
    cdef inline list read_response(self)
    cdef inline void send_command(self, str cmd, tuple args)


cdef class ConnectionPool:
    cdef int pid, max_connections, created_connections
    cdef list available_connections
    cdef set in_use_connections
    cdef dict connection_kwargs
    cdef object lock, fork_lock

    cdef inline void reset(self)
    cdef inline void checkpid(self) except *
    cdef inline bint owns_connection(self, Connection connection)
    cdef inline Connection make_connection(self)
    cdef inline void release(self, Connection connection)
    cdef inline Connection get_connection(self)
    cdef inline void disconnect(self) except *
