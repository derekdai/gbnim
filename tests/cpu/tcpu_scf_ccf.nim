import common, gbasm

let ops = gbasm:
  SCF                   # 1
  CCF                   # 2
  CCF                   # 3
  SCF                   # 4
let cpu = newCpu(ops)
assert cpu.aluFlags == {}
cpu.step                # 1
assert cpu.aluFlags == {AluFlag.C}
cpu.step                # 2
assert cpu.aluFlags == {}
cpu.step                # 3
assert cpu.aluFlags == {AluFlag.C}
cpu.step                # 4
assert cpu.aluFlags == {AluFlag.C}

