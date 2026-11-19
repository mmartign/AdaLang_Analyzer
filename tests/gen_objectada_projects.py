#!/usr/bin/env python3
#  AdaLang Analyzer
#
#  Copyright (C) 2026, Spazio IT
#
#  SPDX-License-Identifier: GPL-3.0-or-later

"""Writes the ObjectAda project files of tests/objectada_project.

ObjectAda's IDE saves a project as an MFC CArchive. These files follow the
layout of project files saved by Aonix ObjectAda 7.2 (CTarget schema 15)
and by PTC ObjectAda64 10 (CTarget schema 19), byte for byte where the
analyzer reads them; the compiler, build and unit option blocks it skips
are copied from such a file. The absolute paths are those of the machine
where the projects were last saved, as in a real project that has since
been copied elsewhere: only the relative paths lead to the sources.

Run from anywhere:  python3 tests/gen_objectada_projects.py [directory]
The files are written under tests/objectada_project, or under directory
(in its app and common subdirectories, which must exist).
"""

import os
import sys

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "objectada_project")


def word(value):
    return value.to_bytes(2, "little")


def dword(value):
    return value.to_bytes(4, "little")


def cstring(text):
    data = text.encode("cp1252")
    if len(data) < 0xFF:
        return bytes([len(data)]) + data
    return b"\xff" + word(len(data)) + data


def new_class(name, schema):
    return b"\xff\xff" + word(schema) + word(len(name)) + name.encode()


def reference(index):
    return word(0x8000 | index)


#  The option blocks between the source list and the library options,
#  copied from a project of five sources saved by Aonix ObjectAda 7.2. It
#  names its main unit, and refers to two classes it declares by their
#  numbers, which depend on the number of sources; both are set for the
#  project at hand.
COMPILER_AND_BUILD_OPTIONS = bytes.fromhex(
    "ffff0b00100043436f6d70696c65724f7074696f6e7300000000010000000000"
    "0000000000000000000000000000000000000000000000000000000000000232"
    "3502383000000000010000000235300100000001000000000000000000000001"
    "0000000000000001000000000000000100000001000000010000000000000001"
    "0000000100000001000000000000000100000000033130300000000000000000"
    "0980000000000100000000000000000000000000000000000000000000000000"
    "0000000000000000000002323502383000000000010000000235300100000001"
    "0000000000000000000000010000000000000001000000000000000100000001"
    "0000000100000000000000010000000100000001000000000000000100000000"
    "033130300000000000000000ffff0f000d00434275696c644f7074696f6e7300"
    "0000000100000000000000000000000000000000000000000000002000000020"
    "0000000001000000010000c00000000000000000000000000000000000000100"
    "1a70726f647563655f636f72706f726174655f62756c6c736869740000000000"
    "0000000000000000000100000000000000010000000000000000000000000000"
    "00022d6700010000000c80000000000100000000000000000000000000000000"
    "0000000000000020000000200000000001000000010000c00000000000000000"
    "0000000000000000000000000000000000000000000000000000010000000000"
    "000001000000000000000000000000000000022d670001000000")
TEMPLATE_SOURCES = 5
TEMPLATE_MAIN = "produce_corporate_bullshit"


def replace_once(data, old, new):
    assert data.count(old) == 1, old
    return data.replace(old, new)


def project(path, schema, project_name, sources, library_dir_was,
            search_path, saved_in, main):
    """Writes one project file.

    sources holds (absolute, name, relative) triples; library_dir_was is
    the absolute path of the library directory where the project was last
    saved; saved_in, the project's directory there (PTC releases record it,
    Aonix ones leave it empty).
    """
    count = len(sources)
    data = bytearray(dword(0) + word(1))
    data += new_class("CTarget", schema)
    data += dword(0) + dword(1)
    data += cstring("Win32 (Intel) Debug") + cstring("Win32 (Intel)")
    data += dword(1) + cstring(project_name) + bytes(9)
    data += cstring(search_path.split(";")[0])
    data += word(count)
    for index, (absolute, name, relative) in enumerate(sources):
        #  MFC numbers each class and each object it writes: the class
        #  CTarget is 1, the target 2, the class CTargetFile 3.
        data += new_class("CTargetFile", 9) if index == 0 else reference(3)
        data += cstring(absolute) + cstring(name) + cstring(relative)
        data += bytes(10)

    #  The classes of the option blocks are numbered after the sources.
    options = COMPILER_AND_BUILD_OPTIONS
    options = replace_once(options, reference(4 + TEMPLATE_SOURCES),
                           reference(4 + count))
    options = replace_once(options, reference(7 + TEMPLATE_SOURCES),
                           reference(7 + count))
    options = replace_once(options, cstring(TEMPLATE_MAIN), cstring(main))
    data += options

    data += new_class("CAdaOptions", 9)
    data += cstring(library_dir_was)
    data += cstring(library_dir_was.split("\\")[-1])
    data += cstring("obj") + cstring("info") + cstring("xref")
    data += bytes(6) + word(len(search_path.split(";")))
    data += cstring(search_path)
    data += b"\x00" + dword(1) + cstring(saved_in) + b"\x00" + word(1)
    data += cstring(main)

    data += new_class("CUnitOptions", 2)
    data += cstring("-G -na -stack  65536 -secstack  65536 "
                    "-taskstack  49152") + bytes(6)
    data += new_class("CEmbeddedOptions", 2) + bytes(17)
    data += reference(14 + count) + bytes(18) + dword(1) + bytes(10)
    data += dword(1) + dword(1) + bytes(64)

    with open(os.path.join(HERE, path), "wb") as output:
        output.write(bytes(data))


def main():
    was = "C:\\Old Place\\Legacy"

    #  The legacy application, saved by Aonix ObjectAda 7.2. Its sources
    #  are named in the case the IDE shows them, and are on disk in
    #  lower case; one of them has been deleted since. It links to the
    #  library of the common project and to a Win32 binding that is not
    #  installed here.
    project(
        "app/legacy.prj", 15, "legacy",
        [(was + "\\src\\Sensors.SPC", "Sensors.SPC",
          "..\\..\\src\\Sensors.SPC"),
         (was + "\\src\\sensors.bdy", "sensors.bdy",
          "..\\..\\src\\sensors.bdy"),
         (was + "\\src\\Control.ada", "Control.ada",
          "..\\..\\src\\Control.ada"),
         (was + "\\src\\legacy_main.adb", "legacy_main.adb",
          "..\\..\\src\\legacy_main.adb"),
         (was + "\\src\\retired.adb", "retired.adb",
          "..\\..\\src\\retired.adb")],
        library_dir_was=was + "\\app\\legacy-Win32(Intel)-Debug",
        search_path=(
            "c:\\program files\\aonix\\objectada\\lib\\rts;"
            + was + "\\common\\common-Win32(Intel)-Debug;"
            "c:\\program files\\aonix\\objectada\\win32ada\\binding\\lib"),
        saved_in="",
        main="legacy_main")

    #  The library, saved by PTC ObjectAda64 10.
    project(
        "common/common.prj", 19, "common",
        [(was + "\\common\\units\\units.ads", "units.ads",
          "..\\units\\units.ads")],
        library_dir_was=was + "\\common\\common-Win32(Intel)-Debug",
        search_path=(
            "c:\\program files (x86)\\ptc\\objectada64\\lib\\rts"),
        saved_in=was + "\\common",
        main="units")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        HERE = sys.argv[1]
    main()
