discard """
  output:'''0
123
12
false
true
456
1
0xeffe
'''
"""

import cpu
import memory
import std/strformat

block:
  var cpu = newSm83(nil)
  echo cpu.a
  cpu.b = 123
  echo cpu.b
  cpu.c = 12
  echo cpu.c

  echo cpu.f(C)
  cpu.setF(C)
  echo cpu.f(C)
  cpu.bc = 456
  echo cpu.bc

block:
  let rom = newRom(@[0u8])
  let mc = newMemoryCtrl()
  mc.map(ROM0, rom)
  let c = newSm83(mc)

  c.step()
  echo c.pc

block:
  let rom = newRom(@[0xc3u8, 0xfe, 0xef])
  let mc = newMemoryCtrl()
  mc.map(ROM0, rom)
  let c = newSm83(mc)

  c.step()

  echo &"0x{c.pc:x}"
