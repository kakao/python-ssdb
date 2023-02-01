# cython: cdivision=True, boundscheck=False, wraparound=False

REQUEST_FOR_NO_RESPONSE = {
    "ping",
    "qset",
}

REQUEST_FOR_INT_RESPONSE = {
    "auth", "dbsize",
    "set", "setx", "setnx", "expire", "ttl",
    "del", "incr", "decr", "exists", "getbit", "setbit",
    "bitcount", "countbit", "strlen", "multi_set", "multi_del",
    "hset", "hdel", "hincr", "hdecr", "hexists", "hsize", "hclear", "multi_hset", "multi_hdel",
    "zset", "zget", "zdel", "zincr", "zdecr", "zexists", "zsize", "zrank", "zrrank", "zclear",
    "zcount", "zsum", "zremrangebyrank", "zremrangebyscore", "multi_zset", "multi_zdel",
    "qsize", "qclear", "qpush", "qpush_front", "qpush_back", "qtrim_front", "qtrim_back",
}

REQUEST_FOR_FLOAT_RESPONSE = {
    "zavg",
}

REQUEST_FOR_BYTE_RESPONSE = {
    "version",
    "get", "getset", "substr",
    "hget",
    "qfront", "qback", "qget",
}

REQUEST_FOR_LIST_RESPONSE = {
    "info",
    "keys", "rkeys",
    "hlist", "hrlist", "hkeys",
    "zlist", "zrlist", "zkeys",
    "qlist", "qrlist", "qrange", "qslice",
    "qpop", "qpop_front", "qpop_back",
}

REQUEST_FOR_STR_MAP_RESPONSE = {
    "multi_get",
    "hgetall", "multi_hget",
}

REQUEST_FOR_INT_MAP_RESPONSE = {
    "multi_exists",
    "multi_hexists", "multi_hsize",
    "zrange", "zrrange", "zpop_front", "zpop_back", "multi_zget", "multi_zexists", "multi_zsize",
}

REQUEST_FOR_STR_MAP_SCAN_RESPONSE = {
    "scan", "rscan", "hscan", "hrscan",
}

REQUEST_FOR_INT_MAP_SCAN_RESPONSE = {
    "zscan", "zrscan",
}


cdef inline dict to_str_map(list resp):
    cdef int i, N = len(resp)
    if not N % 2 == 0:
        raise RuntimeError("Invalid response")
    return {resp[i]: resp[i + 1] for i in range(0, N, 2)}


cdef inline dict to_int_map(list resp):
    cdef int i, N = len(resp)
    if not N % 2 == 0:
        raise RuntimeError("Invalid response")
    cdef bytes v
    cdef dict result = {}

    for i in range(0, N, 2):
        v = resp[i + 1]
        result[resp[i]] = int(v) if v.isdigit() else -1

    return result


cdef inline tuple to_str_map_for_scan(list resp):
    cdef int i, N = len(resp)
    if not N % 2 == 0:
        raise RuntimeError("Invalid response")

    cdef bytes next_start
    cdef dict result
    if N == 0:
        next_start, result = None, {}
    else:
        next_start = resp[N - 2]
        result = {resp[i]: resp[i + 1] for i in range(0, N, 2)}

    return next_start, result


cdef inline tuple to_int_map_for_scan(list resp):
    cdef int i, N = len(resp)
    if not N % 2 == 0:
        raise RuntimeError("Invalid response")
    cdef bytes v, next_start
    cdef dict result = {}

    if N == 0:
        next_start, result = None, {}
    else:
        next_start = resp[N - 2]
        for i in range(0, N, 2):
            v = resp[i + 1]
            result[resp[i]] = int(v) if v.isdigit() else -1

    return next_start, result


cdef object wrap_response(str cmd, list resp):
    cdef int N = len(resp)
    if N == 0:
        raise ConnectionError("Connection closed")

    cdef bytes status = resp[0]
    resp = resp[1:]

    if status == b"not_found":
        return None
    elif status == b"ok":
        if cmd in REQUEST_FOR_NO_RESPONSE:
            return None
        elif cmd in REQUEST_FOR_INT_RESPONSE:
            return int(resp[0])
        elif cmd in REQUEST_FOR_FLOAT_RESPONSE:
            return float(resp[0])
        elif cmd in REQUEST_FOR_BYTE_RESPONSE:
            return resp[0]
        elif cmd in REQUEST_FOR_LIST_RESPONSE:
            return resp
        elif cmd in REQUEST_FOR_STR_MAP_RESPONSE:
            return to_str_map(resp)
        elif cmd in REQUEST_FOR_INT_MAP_RESPONSE:
            return to_int_map(resp)
        elif cmd in REQUEST_FOR_STR_MAP_SCAN_RESPONSE:
            return to_str_map_for_scan(resp)
        elif cmd in REQUEST_FOR_INT_MAP_SCAN_RESPONSE:
            return to_int_map_for_scan(resp)
        else:
            raise RuntimeError(f"{cmd} is unknown command")
    else:
        raise RuntimeError(status.decode("utf-8"))
