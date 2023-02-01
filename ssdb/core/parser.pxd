# cython: language_level=3

from libc.stdint cimport uint8_t


cdef class Buffer:
    cdef uint8_t* data
    cdef size_t size, cap, unit

    cdef inline void clear(self)
    cdef inline int grow(self, size_t size)
    cdef inline int put(self, uint8_t* data, size_t size)
    cdef inline void remove(self, size_t size)


cdef class Parser:
    cdef Buffer buf

    cdef inline void clear(self)
    cdef inline int feed(self, uint8_t* data, size_t size)
    cdef inline int parse(self, list values)


cdef class Reader:
    cdef Parser parser

    cpdef void clear(self)
    cpdef int feed(self, const uint8_t[::1] value)
    cpdef object get(self)
