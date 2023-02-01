# cython: boundscheck=False, wraparound=False

cimport cython
from libc.stdint cimport uint8_t
from libc.stdlib cimport atoi, free, malloc, realloc
from libc.string cimport memchr, memcpy, memmove, memset

DEF INITIAL_BUF_SIZE = 8192  # 8KiB
DEF BUF_MAX_SIZE = 16 * 1024 * 1024  # 16MiB


@cython.internal
cdef class ParserException(Exception):
    pass


@cython.internal
cdef class NoMemoryError(ParserException):
    pass


@cython.internal
cdef class BadFormatError(ParserException):
    pass


ctypedef enum Status:
    OK = 0
    ENOMEM = 1
    EBADFMT = 2
    EUNFINISH = 3


cdef class Buffer:
    def __cinit__(self):
        self.data = <uint8_t*>malloc(INITIAL_BUF_SIZE)
        self.size = 0
        self.cap = INITIAL_BUF_SIZE

    def __dealloc__(self):
        if self.data != NULL:
            free(self.data)

    cdef inline void clear(self):
        if self.data != NULL:
            free(self.data)
        self.data = NULL
        self.size = 0
        self.cap = 0

    cdef inline int grow(self, size_t size):
        if size > BUF_MAX_SIZE:
            return Status.ENOMEM

        if size <= self.cap:
            return Status.OK

        cdef size_t cap = self.cap

        while cap < size:
            cap *= 2

        cdef uint8_t* data = <uint8_t*>realloc(self.data, cap)

        if data == NULL:
            return Status.ENOMEM

        self.data = data
        self.cap = cap
        return Status.OK

    cdef inline int put(self, uint8_t* data, size_t size):
        cdef int res = self.grow(self.size + size)

        if res == Status.OK:
            memcpy(self.data + self.size, data, size)
            self.size += size

        return res

    cdef inline void remove(self, size_t size):
        if size > self.size:
            self.size = 0
            return

        self.size -= size
        memmove(self.data, self.data + size, self.size)


cdef class Parser:
    def __cinit__(self):
        self.buf = Buffer()

    cdef inline void clear(self):
        self.buf.clear()

    cdef inline int feed(self, uint8_t* data, size_t size):
        return self.buf.put(data, size)

    cdef inline int parse(self, list values):
        cdef:
            int dis, sz
            uint8_t* start = self.buf.data
            uint8_t* end = self.buf.data + self.buf.size
            uint8_t* ptr = start
            uint8_t* ch
            long length = self.buf.size
            uint8_t size_str[20]
            bytes value

        while length > 0:
            ch = <uint8_t*>memchr(ptr, b'\n', length)

            if ch == NULL:
                break

            ch += 1
            dis = ch - ptr

            if dis == 1 or (dis == 2 and ptr[0] == b'\r'):
                self.buf.remove(ch - start)
                return Status.OK

            if ptr[0] < b'0' or ptr[0] > b'9':
                return Status.EBADFMT

            memset(size_str, 0, 20)

            if dis > <int>sizeof(size_str) - 1:
                return Status.EBADFMT

            memcpy(size_str, ptr, dis - 1)
            sz = atoi(<const char*>size_str)

            if sz < 0:
                return Status.EBADFMT

            length -= dis + sz
            ptr += dis + sz

            if length < 0 or ptr > end:
                break

            if length >= 1 and ptr[0] == b'\n':
                length -= 1
                ptr += 1
            elif length >= 2 and ptr[0] == b'\r' and ptr[1] == b'\n':
                length -= 2
                ptr += 2
            else:
                break
            value = ch[:sz]
            values.append(value)
        return Status.EUNFINISH


cdef class Reader:
    def __cinit__(self):
        self.parser = Parser()

    def __dealloc__(self):
        self.parser.clear()

    cpdef void clear(self):
        self.parser.clear()

    cpdef int feed(self, const uint8_t[::1] value):
        cdef int res = self.parser.feed(<uint8_t*>&value[0], value.shape[0])

        if res == Status.OK:
            return self.parser.buf.size
        raise NoMemoryError

    cpdef object get(self):
        cdef list values = []
        cdef int res = self.parser.parse(values)

        if res == Status.OK:
            return values
        elif res == Status.EBADFMT:
            raise BadFormatError
        return None
