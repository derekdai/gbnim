import gbasm
import common

let ops = gbasm:
  EI                    # 1
  DI                    # 2
let cpu = newCpu(ops)
assert cpu.ime == false
cpu.step                # 1
assert cpu.ime == true
cpu.step                # 2
assert cpu.ime == false
