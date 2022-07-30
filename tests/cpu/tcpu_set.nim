import common, gbasm

let ops = gbasm:
  SET 0,B               # 1
  SET 7,A               # 2
  LD HL,0xc000          # 3
  SET 3,(HL)
  SET 4,(HL)
  LD D,0xff             # 4
  SET 0,D
  SET 7,D
let cpu = newCpu(ops)
cpu.aluFlags = {Z, N, C, H}
cpu.step                # 1
assert cpu[B] == 0b0000_0001
assert cpu.aluFlags == {Z, N, C, H}
cpu.aluFlags = {Z, N}
cpu.step                # 2
assert cpu[A] == 0b1000_0000
assert cpu.aluFlags == {Z, N}
cpu.aluFlags = {}
cpu.step 3              # 3
assert cpu[0xc000] == 0b0001_1000
assert cpu.aluFlags == {}
cpu.step 2              # 4
assert cpu[D] == 0xff
assert cpu.aluFlags == {}

