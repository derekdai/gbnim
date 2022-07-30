import common, gbasm

let ops = gbasm:
  LD SP,0xc000        # 1
  RST 0x08
  [0x08]
  RST 0x10            # 2
  [0x10]
  RST 0x18            # 3
  [0x18]
  RST 0x20            # 4
  [0x20]
  RST 0x28            # 5
  [0x28]
  RST 0x30            # 6
  [0x30]
  RST 0x38            # 7
  [0x38]
  RST 0x00            # 8
let cpu = newCpu(ops)
cpu.step 2            # 1
assert cpu.r(SP) == 0xc000 - 2
assert cpu.pc == 0x08
cpu.step              # 2
assert cpu.r(SP) == 0xc000 - 4
assert cpu.pc == 0x10
cpu.step              # 3
assert cpu.r(SP) == 0xc000 - 6
assert cpu.pc == 0x18
cpu.step              # 4
assert cpu.r(SP) == 0xc000 - 8
assert cpu.pc == 0x20
cpu.step              # 5
assert cpu.r(SP) == 0xc000 - 10
assert cpu.pc == 0x28
cpu.step              # 6
assert cpu.r(SP) == 0xc000 - 12
assert cpu.pc == 0x30
cpu.step              # 7
assert cpu.r(SP) == 0xc000 - 14
assert cpu.pc == 0x38
cpu.step              # 8
assert cpu.r(SP) == 0xc000 - 16
assert cpu.pc == 0x00
