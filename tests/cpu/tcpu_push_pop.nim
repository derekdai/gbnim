import common, gbasm

let ops = gbasm:
  LD SP,0xcfff          # 1
  LD BC,0x8800
  PUSH BC
  POP HL
  ADD HL,BC
  PUSH BC               # 2
  POP AF
let cpu = newCpu(ops)
cpu.step 3              # 1
assert cpu.r(SP) == 0xcfff - 2
cpu.step
assert cpu.r(SP) == 0xcfff
cpu.step
assert cpu.aluFlags == {AluFlag.C, H}
cpu.step 2              # 2
assert cpu.r(A) == 0x88
assert cpu.aluFlags == {}
