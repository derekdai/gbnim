import common, gbasm

let ops = gbasm:
  SCF                   # 1
  CCF                   # 2
  CCF                   # 3
  SCF                   # 4
let cpu = newCpu(ops)
assert cpu.f == {}
cpu.step                # 1
assert cpu.f == {Flag.C}
cpu.step                # 2
assert cpu.f == {}
cpu.step                # 3
assert cpu.f == {Flag.C}
cpu.step                # 4
assert cpu.f == {Flag.C}

