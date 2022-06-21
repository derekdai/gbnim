discard """
  output:'''0
123
12
false
true
456
'''
"""

import cpu

block:
  var cpu = newCpu()
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
