import common, gbasm

let ops = gbasm:
  CPL                   # 1
  LD A,0b1010_1010      # 1
  CPL
let cpu = newCpu(ops)
cpu.step                # 1
assert cpu[A] == 0xff
assert cpu.aluFlags == {N,H}
cpu.step 2              # 2
assert cpu[A] == 0b0101_0101
assert cpu.aluFlags == {N,H}

