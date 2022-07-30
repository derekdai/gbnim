import common, gbasm

let ops = gbasm:
  RES 0,B               # 1
  RES 7,A               # 2
  LD D,0xff             # 3
  RES 0,D
  RES 7,D
  LD HL,0xc000          # 4
  LD (HL),0xff
  RES 3,(HL)
  RES 4,(HL)
let cpu = newCpu(ops)
cpu.aluFlags = {Z, N, C, H}
cpu.step                # 1
assert cpu[B] == 0
assert cpu.aluFlags == {Z, N, C, H}
cpu.aluFlags = {Z, N}
cpu.step                # 2
assert cpu[A] == 0
assert cpu.aluFlags == {Z, N}
cpu.aluFlags = {}              # 3
cpu.step 3
assert cpu[D] == 0b0111_1110
assert cpu.aluFlags == {}
cpu.step 4              # 4
assert cpu[0xc000] == 0b1110_0111
assert cpu.aluFlags == {}

