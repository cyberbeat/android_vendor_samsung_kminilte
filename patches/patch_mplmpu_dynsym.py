#!/usr/bin/env python3
# Fix libmplmpu.so dynsym for ld.lld: 9 symbols with STB_LOCAL binding sit
# inside the global part of .dynsym (past index sh_info). lld refuses to
# link such objects ("local symbol in global part of symbol table").
# Patch: st_info bind LOCAL(0) -> GLOBAL(1) for those symbols.
# Content and type are untouched; purely a binding fix.
#
# Usage: patch_mplmpu_dynsym.py <target.so>   (patches in place, idempotent)
#
# Original blob md5: bdd886f7bd82734673416c6a804d1814
# Patched blob md5:  3039ca893ac5c1957efdb231dcf6fba6
#
# Expected symbols (dynsym idx 3..11):
#   _bss_end__ __bss_start__ __bss_end__ __bss_start __end__
#   _edata _end _stack __data_start

import struct
import sys

SHT_DYNSYM = 11
STB_LOCAL = 0
STB_GLOBAL = 1

EXPECTED_LOCALS = {
    "_bss_end__", "__bss_start__", "__bss_end__", "__bss_start",
    "__end__", "_edata", "_end", "_stack", "__data_start",
}


def fail(msg):
    print("patch_mplmpu_dynsym: %s" % msg, file=sys.stderr)
    sys.exit(1)


def main(path):
    data = bytearray(open(path, "rb").read())

    # --- ELF32 header, little endian, ET_DYN ---
    if data[:4] != b"\x7fELF" or data[4] != 1 or data[5] != 1:
        fail("not a 32-bit little-endian ELF")
    (e_shoff,) = struct.unpack_from("<I", data, 0x20)
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<HHH", data, 0x2E)

    # --- locate .dynsym and .dynstr via section header string table ---
    def sh(i):
        off = e_shoff + i * e_shentsize
        return struct.unpack_from("<10I", data, off)

    shstr = sh(e_shstrndx)
    shstr_off = shstr[4]

    def name_at(strtab_off, idx):
        end = data.index(b"\x00", strtab_off + idx)
        return bytes(data[strtab_off + idx:end]).decode()

    dynsym = dynstr = None
    for i in range(e_shnum):
        s = sh(i)
        if s[1] == SHT_DYNSYM:
            dynsym = s
            dynstr = sh(s[6])  # sh_link -> string table section
            break
    if dynsym is None:
        fail("no .dynsym section")

    sym_off, sym_size, sym_link, sym_info, sym_entsize = (
        dynsym[4], dynsym[5], dynsym[6], dynsym[7], dynsym[9])
    str_off = dynstr[4]
    count = sym_size // sym_entsize

    # --- patch bind of misplaced locals ---
    patched = []
    for idx in range(count):
        e = sym_off + idx * sym_entsize
        st_name, st_info = struct.unpack_from("<I", data, e)[0], data[e + 12]
        bind = st_info >> 4
        if idx >= sym_info and bind == STB_LOCAL:
            name = name_at(str_off, st_name)
            data[e + 12] = (STB_GLOBAL << 4) | (st_info & 0xF)
            patched.append(name)

    print(".dynsym: %d syms, sh_info(local count)=%d" % (count, sym_info))
    if not patched:
        print("nothing to patch (already GLOBAL)")
        return
    for n in patched:
        print("  %s -> GLOBAL" % n)
    if set(patched) != EXPECTED_LOCALS:
        fail("unexpected symbol set %s -- blob changed?" % sorted(patched))
    open(path, "wb").write(data)
    print("patched %d symbols" % len(patched))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        fail("usage: %s <libmplmpu.so>" % sys.argv[0])
    main(sys.argv[1])
