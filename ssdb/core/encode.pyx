# cython: language_level=3


cdef inline bytes utf8_encode(object s):
    s = str(s) if isinstance(s, int) else s
    return s.encode("utf-8") if isinstance(s, str) else s


def encode_command(str command, tuple args) -> bytes:
    if command == "delete":
        command = "del"

    cdef bytes byte
    cdef list buf = [utf8_encode(command)] + [utf8_encode(x) for x in args]
    return b"".join(b"%d\n%s\n" % (len(byte), byte) for byte in buf) + b"\n"
