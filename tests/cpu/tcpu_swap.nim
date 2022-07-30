import common, gbasm

let ops = gbasm:
  SWAP A                # 1
  LD D,0xf0             # 2
  SWAP D
  LD HL,0xc000          # 3
  LD (HL),0xab
  SWAP (HL)
let cpu = newCpu(ops)
cpu.step                # 1
assert cpu.r(A) == 0
assert cpu.aluFlags == {Z}
cpu.step 2              # 2
assert cpu.r(D) == 0x0f
assert cpu.aluFlags == {}
cpu.step 3              # 3
assert cpu[0xc000] == 0xba
assert cpu.aluFlags == {}
