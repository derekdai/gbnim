import std/strformat

proc hex*(v: uint8): string = &"0x{v:02x}"

proc hex*(v: uint16): string = &"0x{v:04x}"
