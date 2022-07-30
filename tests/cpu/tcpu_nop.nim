import gbasm
import common

let ops = gbasm:
  NOP
  NOP
let cpu = newCpu(ops)
cpu.step()
assert cpu.ticks == 4
assert cpu.pc == 1
assert cpu.aluFlags == {}
cpu.step()
assert cpu.ticks == 8
assert cpu.pc == 2
assert cpu.aluFlags == {}

