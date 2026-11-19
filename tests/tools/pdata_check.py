"""Check the function table (.pdata) of a Windows x64 executable.

Temporary diagnostic. Arguments: the output of "objdump -s -j .pdata", the
image base in hex, and the output of "nm" for the executable. Windows finds
the unwind data of a function by a binary search of this table, which must
be sorted and free of overlaps; it prints what breaks that, and the entries
that cover the functions an Ada exception was unwound through.
"""

import re
import struct
import sys

WATCHED = ("gnat__expect__expect", "gnatcoll__utils__get_command_output")


def table(path):
    data = bytearray()
    started = False
    with open(path, errors="replace") as text:
        for line in text:
            if line.startswith("Contents of section .pdata"):
                started = True
                continue
            if not started or not line.startswith(" "):
                continue
            words = line[1:].split("  ")[0].split()
            for word in words[1:]:
                data += bytes.fromhex(word)
    count = len(data) // 12
    return [struct.unpack_from("<III", data, i * 12) for i in range(count)]


def symbols(path, base):
    found = []
    with open(path, errors="replace") as text:
        for line in text:
            parts = line.split()
            if len(parts) == 3 and parts[2].startswith(WATCHED):
                found.append((parts[2], int(parts[0], 16) - base))
    return found


def lookup(entries, rva):
    low, high = 0, len(entries) - 1
    while low <= high:
        middle = (low + high) // 2
        begin, end, _ = entries[middle]
        if rva < begin:
            high = middle - 1
        elif rva >= end:
            low = middle + 1
        else:
            return middle
    return None


def main():
    entries = table(sys.argv[1])
    base = int(sys.argv[2], 16)
    empty = [i for i, (b, e, _) in enumerate(entries) if e <= b]
    unsorted = [i for i in range(1, len(entries))
                if entries[i][0] < entries[i - 1][0]]
    overlaps = [i for i in range(1, len(entries))
                if entries[i][0] < entries[i - 1][1]]
    print(f"{len(entries)} entries, {len(empty)} empty, "
          f"{len(unsorted)} out of order, {len(overlaps)} overlapping")
    for i in (empty + unsorted + overlaps)[:15]:
        print(f"  #{i - 1}: {entries[i - 1][0]:#x}..{entries[i - 1][1]:#x}"
              f"  #{i}: {entries[i][0]:#x}..{entries[i][1]:#x}")
    for name, rva in symbols(sys.argv[3], base)[:12]:
        covering = [i for i, (b, e, _) in enumerate(entries) if b <= rva < e]
        found = lookup(entries, rva)
        print(f"{name} at {rva:#x}: covered by {covering}, "
              f"binary search finds {found}")


main()
