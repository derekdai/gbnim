# Package

version       = "0.1.0"
author        = "Derek Dai"
description   = "GameBoy emulator written in Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["gbnim"]


# Dependencies

requires "nim >= 1.7.1"
requires "sdl2"
requires "libbacktrace"
requires "gbasm >= 0.2.0"
