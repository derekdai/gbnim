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
  echo cpu[rA]
  cpu[rB] = 123
  echo cpu[rB]
  cpu[rC] = 12
  echo cpu[rC]
  echo cpu[fC]
  cpu[fC] = true
  echo cpu[fC]
  cpu[rBC] = 456
  echo cpu[rBC]
