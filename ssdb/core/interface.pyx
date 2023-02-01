# cython: language_level=3, boundscheck=False, wraparound=False, embedsignature=True

from collections.abc import Mapping
from typing import Awaitable, Dict, List, Optional, TypeVar, Union

T = TypeVar("T")
NameT = Union[bytes, str]
KeyT = Union[bytes, str]
ValueT = Union[bytes, str, int, float]


cdef class SSDBInterface:
    def execute_command(self, str cmd, *args) -> Union[T, Awaitable[T]]:
        raise NotImplementedError

    def ping(self) -> Union[None, Awaitable[None]]:
        return self.execute_command("ping")

    def dbsize(self) -> Union[int, Awaitable[int]]:
        return self.execute_command("dbsize")

    def version(self) -> Union[bytes, Awaitable[bytes]]:
        return self.execute_command("version")

    def info(self, opt: Optional[str] = None) -> Union[List[bytes], Awaitable[List[bytes]]]:
        if opt is None:
            return self.execute_command("info")
        else:
            assert opt in ("cmd", "leveldb"), f"`opt` should be None or either `cmd` or `leveldb`"
            return self.execute_command("info", opt)

    def set(self, key: KeyT, value: ValueT) -> Union[int, Awaitable[int]]:
        """Set the value of the key."""
        return self.execute_command("set", key, value)

    def setx(self, key: KeyT, value: ValueT, int ttl) -> Union[int, Awaitable[int]]:
        """Set the value of the key, with a time to live."""
        return self.execute_command("setx", key, value, ttl)

    def setnx(self, key: KeyT, value: ValueT) -> Union[int, Awaitable[int]]:
        """Set the string value in argument as value of the key if and only if the key doesn't exist."""
        return self.execute_command("setnx", key, value)

    def expire(self, key: KeyT, int ttl) -> Union[int, Awaitable[int]]:
        """Set the time left to live in seconds, only for keys of KV type."""
        return self.execute_command("expire", key, ttl)

    def ttl(self, key: KeyT) -> Union[int, Awaitable[int]]:
        """Returns the time left to live in seconds, only for keys of KV type."""
        return self.execute_command("ttl", key)

    def get(self, key: KeyT) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Get the value related to the specified key."""
        return self.execute_command("get", key)

    def getset(self, key: KeyT, value: ValueT) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Sets a value and returns the previous entry at that key."""
        return self.execute_command("getset", key, value)

    def delete(self, key: KeyT) -> Union[int, Awaitable[int]]:
        """Delete specified key."""
        return self.execute_command("del", key)

    def incr(self, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Increment the number stored at key by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before increment, assuming it was stored as literal integer."""
        return self.execute_command("incr", key, num)

    def decr(self, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Decrement the number stored at key by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before decrement, assuming it was stored as literal integer."""
        return self.execute_command("decr", key, num)

    def exists(self, key: KeyT) -> Union[int, Awaitable[int]]:
        """Verify if the specified key exists."""
        return self.execute_command("exists", key)

    def mexists(self, keys: List[KeyT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Verify if the specified keys exist."""
        return self.execute_command("multi_exists", *keys)

    def getbit(self, key: KeyT, int offset) -> Union[int, Awaitable[int]]:
        """Return a single bit out of a string."""
        return self.execute_command("getbit", key, offset)

    def setbit(self, key: KeyT, int offset, int val) -> Union[int, Awaitable[int]]:
        """Changes a single bit of a string. The string is auto expanded."""
        return self.execute_command("setbit", key, offset, val)

    def bitcount(self, key: KeyT, int start, int end) -> Union[int, Awaitable[int]]:
        """Count the number of set bits (population counting) in a string."""
        return self.execute_command("bitcount", key, start, end)

    def countbit(self, key: KeyT, int start, int size) -> Union[int, Awaitable[int]]:
        """Count the number of set bits (population counting) in part of a string."""
        return self.execute_command("countbit", key, start, size)

    def substr(self, key: KeyT, int start, int size) -> Union[bytes, Awaitable[bytes]]:
        """Return part of a string."""
        return self.execute_command("substr", key, start, size)

    def strlen(self, key: KeyT) -> Union[int, Awaitable[int]]:
        """Return the number of bytes of a string."""
        return self.execute_command("strlen", key)

    def keys(self, key_start: KeyT, key_end: KeyT, int limit = -1) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List keys in range (key_start, key_end]."""
        return self.execute_command("keys", key_start, key_end, limit)

    def rkeys(self, key_start: KeyT, key_end: KeyT, int limit = -1) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List keys in range (key_start, key_end], in reverse order."""
        return self.execute_command("rkeys", key_start, key_end, limit)

    def scan(
        self,
        key_start: KeyT,
        key_end: KeyT,
        int limit = -1,
    ) -> Union[tuple[Optional[bytes], Dict[bytes, bytes]], Awaitable[tuple[Optional[bytes], Dict[bytes, bytes]]]]:
        """List key-value pairs with keys in range (key_start, key_end]."""
        return self.execute_command("scan", key_start, key_end, limit)

    def rscan(
        self,
        key_start: KeyT,
        key_end: KeyT,
        int limit = -1,
    ) -> Union[tuple[Optional[bytes], Dict[bytes, bytes]], Awaitable[tuple[Optional[bytes], Dict[bytes, bytes]]]]:
        """List key-value pairs with keys in range (key_start, key_end], in reverse order."""
        return self.execute_command("rscan", key_start, key_end, limit)

    def mset(self, kvs: Mapping[KeyT, ValueT]) -> Union[int, Awaitable[int]]:
        """Set multiple key-value pairs(kvs) in one method call."""
        cdef tuple pair
        cdef list items = []
        for pair in kvs.items():
            items.extend(pair)
        return self.execute_command("multi_set", *items)

    def mget(self, keys: List[KeyT]) -> Union[Dict[bytes, bytes], Awaitable[Dict[bytes, bytes]]]:
        """Get the values related to the specified multiple keys."""
        return self.execute_command("multi_get", *keys)

    def mdelete(self, keys: List[KeyT]) -> Union[int, Awaitable[int]]:
        """Delete specified multiple keys."""
        return self.execute_command("multi_del", *keys)

    def hset(self, name: NameT, key: KeyT, value: ValueT) -> Union[int, Awaitable[int]]:
        """Set the string value in argument as value of the key of a hashmap."""
        return self.execute_command("hset", name, key, value)

    def hget(self, name: NameT, key: KeyT) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Get the value related to the specified key of a hashmap."""
        return self.execute_command("hget", name, key)

    def hdelete(self,  name: NameT, key: KeyT) -> Union[int, Awaitable[int]]:
        """Delete specified key of a hashmap."""
        return self.execute_command("hdel", name, key)

    def hincr(self, name: NameT, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Increment the number stored at key in a hashmap by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before increment, assuming it was stored as literal integer."""
        return self.execute_command("hincr", name, key, num)

    def hdecr(self, name: NameT, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Decrement the number stored at key in a hashmap by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before decrement, assuming it was stored as literal integer."""
        return self.execute_command("hdecr", name, key, num)

    def hexists(self, name: NameT, key: KeyT) -> Union[int, Awaitable[int]]:
        """Verify if the specified key exists in a hashmap."""
        return self.execute_command("hexists", name, key)

    def mhexists(self, name: NameT, keys: List[KeyT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Verify if the specified keys exist in a hashmap."""
        return self.execute_command("multi_hexists", name, *keys)

    def hsize(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Return the number of pairs of a hashmap."""
        return self.execute_command("hsize", name)

    def mhsize(self, names: List[NameT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Return the number of pairs of a hashmaps."""
        return self.execute_command("multi_hsize", *names)

    def hlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List hashmap names in range (name_start, name_end]."""
        return self.execute_command("hlist", name_start, name_end, limit)

    def hrlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List hashmap names in range (name_start, name_end], in reverse order."""
        return self.execute_command("hrlist", name_start, name_end, limit)

    def hkeys(
        self,
        name: NameT,
        key_start: KeyT,
        key_end: KeyT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List keys of a hashmap in range (key_start, key_end]."""
        return self.execute_command("hkeys", name, key_start, key_end, limit)

    def hgetall(self, name: List[NameT]) -> Union[Dict[bytes, bytes], Awaitable[Dict[bytes, bytes]]]:
        """Returns the whole hash, as an array of strings indexed by strings."""
        return self.execute_command("hgetall", name)

    def hscan(
        self,
        name: NameT,
        key_start: KeyT,
        key_end: KeyT,
        int limit = -1,
    ) -> Union[tuple[Optional[bytes], Dict[bytes, bytes]], Awaitable[tuple[Optional[bytes], Dict[bytes, bytes]]]]:
        """List key-value pairs of a hashmap with keys in range (key_start, key_end]."""
        return self.execute_command("hscan", name, key_start, key_end, limit)

    def hrscan(
        self,
        name: NameT,
        key_start: KeyT,
        key_end: KeyT,
        int limit = -1,
    ) -> Union[tuple[Optional[bytes], Dict[bytes, bytes]], Awaitable[tuple[Optional[bytes], Dict[bytes, bytes]]]]:
        """List key-value pairs of a hashmap with keys in range (key_start, key_end], in reverse order."""
        return self.execute_command("hrscan", name, key_start, key_end, limit)

    def hclear(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Delete all keys in a hashmap."""
        return self.execute_command("hclear", name)

    def mhset(self, name: NameT, kvs: Mapping[KeyT, ValueT]) -> Union[int, Awaitable[int]]:
        """Set multiple key-value pairs(kvs) of a hashmap in one method call."""
        cdef tuple pair
        cdef list items = []
        for pair in kvs.items():
            items.extend(pair)
        return self.execute_command("multi_hset", name, *items)

    def mhget(self, name: NameT, keys: List[KeyT]) -> Union[Dict[bytes, bytes], Awaitable[Dict[bytes, bytes]]]:
        """Get the values related to the specified multiple keys of a hashmap."""
        return self.execute_command("multi_hget", name, *keys)

    def mhdelete(self, name: NameT, keys: List[KeyT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Delete specified multiple keys in a hashmap."""
        return self.execute_command("multi_hdel", name, *keys)

    def zset(self, name: NameT, key: KeyT, long score) -> Union[int, Awaitable[int]]:
        """Set the score of the key of a zset."""
        return self.execute_command("zset", name, key, score)

    def zget(self, name: NameT, key: KeyT) -> Union[Optional[int], Awaitable[Optional[int]]]:
        """Get the score related to the specified key of a zset."""
        return self.execute_command("zget", name, key)

    def zdelete(self, name: NameT, key: KeyT) -> Union[int, Awaitable[int]]:
        """Delete specified key of a zset."""
        return self.execute_command("zdel", name, key)

    def zincr(self, name: NameT, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Increment the number stored at key in a zset by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before increment, assuming it was stored as literal integer."""
        return self.execute_command("zincr", name, key, num)

    def zdecr(self, name: NameT, key: KeyT, long num = 1) -> Union[int, Awaitable[int]]:
        """Decrement the number stored at key in a zset by num.
        The num argument could be a negative integer.
        The old number is first converted to an integer before decrement, assuming it was stored as literal integer."""
        return self.execute_command("zdecr", name, key, num)

    def zexists(self, name: NameT, key: KeyT) -> Union[int, Awaitable[int]]:
        """Verify if the specified key exists in a zset."""
        return self.execute_command("zexists", name, key)

    def mzexists(self, name: NameT, keys: List[KeyT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Verify if the specified keys exist in a zset."""
        return self.execute_command("multi_zexists", name, *keys)

    def zsize(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Return the number of pairs of a zset."""
        return self.execute_command("zsize", name)

    def mzsize(self, names: List[NameT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Return the number of pairs of a zsets."""
        return self.execute_command("multi_zsize", *names)

    def zlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List zset names in range (name_start, name_end]."""
        return self.execute_command("zlist", name_start, name_end, limit)

    def zrlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List zset names in range (name_start, name_end], in reverse order."""
        return self.execute_command("zrlist", name_start, name_end, limit)

    def zkeys(
        self,
        name: NameT,
        key_start: NameT,
        long score_start,
        long score_end,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List keys in a zset."""
        return self.execute_command("zkeys", name, key_start, score_start, score_end, limit)

    def zscan(
        self,
        name: NameT,
        key_start: KeyT,
        long score_start,
        long score_end,
        int limit = -1,
    ) -> Union[tuple[Optional[int], Dict[bytes, int]], Awaitable[tuple[Optional[int], Dict[bytes, int]]]]:
        """List key-score pairs in a zset, where key-score in range (key_start+score_start, score_end].
        If key_start is empty, keys with a score greater than or equal to score_start will be returned.
        If key_start is not empty, keys with score larger than score_start, and keys larger than key_start also with score equal to score_start will be returned."""
        return self.execute_command("zscan", name, key_start, score_start, score_end, limit)

    def zrscan(
        self,
        name: NameT,
        key_start: KeyT,
        long score_start,
        long score_end,
        int limit = -1,
    ) -> Union[tuple[Optional[int], Dict[bytes, int]], Awaitable[tuple[Optional[int], Dict[bytes, int]]]]:
        """List key-score pairs of a zset, in reverse order."""
        return self.execute_command("zrscan", name, key_start, score_start, score_end, limit)

    def zrank(self, name: NameT, key: KeyT,) -> Union[int, Awaitable[int]]:
        """NOTE: This method may be extremly SLOW! May not be used in an online service.
        Returns the rank(index) of a given key in the specified sorted set.
        Starting at 0 for the item with the smallest score."""
        return self.execute_command("zrank", name, key)

    def zrrank(self, name: NameT, key: KeyT,) -> Union[int, Awaitable[int]]:
        """NOTE: This method may be extremly SLOW! May not be used in an online service.
        Returns the rank(index) of a given key in the specified sorted set.
        Starting at 0 for the item with the largest score."""
        return self.execute_command("zrrank", name, key)

    def zrange(self, name: NameT, int offset = 0, int limit = -1) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """NOTE: This method is SLOW for large offset!
        Returns a range of key-score pairs by index range [offset, offset + limit)."""
        return self.execute_command("zrange", name, offset, limit)

    def zrrange(self, name: NameT, int offset = 0, int limit = -1) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """NOTE: This method is SLOW for large offset!
        Returns a range of key-score pairs by index range [offset, offset + limit), in reverse order."""
        return self.execute_command("zrrange", name, offset, limit)

    def zclear(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Delete all keys in a zset."""
        return self.execute_command("zclear", name)

    def zcount(self, name: NameT, long start, long end) -> Union[int, Awaitable[int]]:
        """Returns the number of elements of the sorted set stored at the specified key which have scores in the range [start,end]."""
        return self.execute_command("zcount", name, start, end)

    def zsum(self, name: NameT, long start, long end) -> Union[int, Awaitable[int]]:
        """Returns the sum of elements of the sorted set stored at the specified key which have scores in the range [start,end]."""
        return self.execute_command("zsum", name, start, end)

    def zavg(self, name: NameT, long start, long end) -> Union[float, Awaitable[float]]:
        """Returns the average of elements of the sorted set stored at the specified key which have scores in the range [start,end]."""
        return self.execute_command("zavg", name, start, end)

    def zremrangebyrank(self, name: NameT, int start, int end) -> Union[int, Awaitable[int]]:
        """Delete the elements of the zset which have rank in the range [start,end]."""
        return self.execute_command("zremrangebyrank", name, start, end)

    def zremrangebyscore(self, name: NameT, long start, long end) -> Union[int, Awaitable[int]]:
        """Delete the elements of the zset which have score in the range [start,end]."""
        return self.execute_command("zremrangebyscore", name, start, end)

    def zpop_front(self, name: NameT, int limit) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Delete and return `limit` element(s) from front of the zset."""
        return self.execute_command("zpop_front", name, limit)

    def zpop_back(self, name: NameT, int limit) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Delete and return `limit` element(s) from back of the zset."""
        return self.execute_command("zpop_back", name, limit)

    def mzset(self, name: NameT, kvs: Mapping[KeyT, int]) -> Union[int, Awaitable[int]]:
        """Set multiple key-score pairs(kvs) of a zset in one method call."""
        cdef tuple pair
        cdef list items = []
        for pair in kvs.items():
            items.extend(pair)
        return self.execute_command("multi_zset", name, *items)

    def mzget(self, name: NameT, keys: List[KeyT]) -> Union[Dict[bytes, int], Awaitable[Dict[bytes, int]]]:
        """Get the values related to the specified multiple keys of a zset."""
        return self.execute_command("multi_zget", name, *keys)

    def mzdelete(self, name: NameT, keys: List[KeyT]) -> Union[int, Awaitable[int]]:
        """Delete specified multiple keys of a zset."""
        return self.execute_command("multi_zdel", name, *keys)

    def qsize(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Returns the number of items in the queue."""
        return self.execute_command("qsize", name)

    def qlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """List list/queue names in range (name_start, name_end]."""
        return self.execute_command("qlist", name_start, name_end, limit)

    def qrlist(
        self,
        name_start: NameT,
        name_end: NameT,
        int limit = -1,
    ) -> Union[list[bytes], Awaitable[list[bytes]]]:
        """List list/queue names in range (name_start, name_end], in reverse order."""
        return self.execute_command("qrlist", name_start, name_end, limit)

    def qclear(self, name: NameT) -> Union[int, Awaitable[int]]:
        """Clear the queue."""
        return self.execute_command("qclear", name)

    def qfront(self, name: NameT) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Returns the first element of a queue."""
        return self.execute_command("qfront", name)

    def qback(self, name: NameT) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Returns the last element of a queue."""
        return self.execute_command("qback", name)

    def qget(self, name: NameT, int index) -> Union[Optional[bytes], Awaitable[Optional[bytes]]]:
        """Returns the element a the specified index(position).
        0 the first element, 1 the second ... -1 the last element."""
        return self.execute_command("qget", name, index)

    def qset(self, name: NameT, int index, val: ValueT) -> Union[int, Awaitable[int]]:
        """Sets the list element at index to value.
        An error is returned for out of range indexes."""
        return self.execute_command("qset", name, index, val)

    def qrange(self, name: NameT, int offset = 0, int limit = -1) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """Returns a portion of elements from the queue at the specified range [offset, offset + limit]."""
        return self.execute_command("qrange", name, offset, limit)

    def qslice(self, name: NameT, int begin, int end) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """Returns a portion of elements from the queue at the specified range [begin, end].
        begin and end could be negative."""
        return self.execute_command("qslice", name, begin, end)

    def qpush(self, name: NameT, *item: ValueT) -> Union[int, Awaitable[int]]:
        """This function is an alias of `qpush_back`"""
        return self.execute_command("qpush", name, *item)

    def qpush_front(self, name: NameT, *item: ValueT) -> Union[int, Awaitable[int]]:
        """Adds one or more than one element to the head of the queue."""
        return self.execute_command("qpush_front", name, *item)

    def qpush_back(self, name: NameT, *item: ValueT) -> Union[int, Awaitable[int]]:
        """Adds an or more than one element to the end of the queue."""
        return self.execute_command("qpush_back", name, *item)

    def qpop(self, name: NameT, int size) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """This function is an alias of `qpop_front`"""
        return self.execute_command("qpop", name, size)

    def qpop_front(self, name: NameT, int size) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """Pop out one or more elements from the head of a queue."""
        return self.execute_command("qpop_front", name, size)

    def qpop_back(self, name: NameT, int size) -> Union[List[bytes], Awaitable[List[bytes]]]:
        """Pop out one or more elements from the tail of a queue."""
        return self.execute_command("qpop_back", name, size)

    def qtrim_front(self, name: NameT, int size) -> Union[int, Awaitable[int]]:
        """Remove multi elements from the head of a queue."""
        return self.execute_command("qtrim_front", name, size)

    def qtrim_back(self, name: NameT, int size) -> Union[int, Awaitable[int]]:
        """Remove multi elements from the tail of a queue."""
        return self.execute_command("qtrim_back", name, size)
