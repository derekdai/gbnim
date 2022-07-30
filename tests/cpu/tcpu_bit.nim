import common, gbasm

let ops = gbasm:
  BIT 0,B               # 1
  BIT 7,A               # 2
  LD E,0b1110_1111      # 3
  BIT 0,E
  BIT 7,E
  BIT 4,E
  LD HL,0xc000          # 4
  SET 3,(HL)
  BIT 3,(HL)
  RES 3,(HL)
  BIT 3,(HL)
let cpu = newCpu(ops)
cpu.f{C} = true
cpu.step                # 1
assert cpu.f == {Z, H, C}
assert cpu.r(B) == 0
cpu.f{C} = false
cpu.step                # 2
assert cpu.f == {Z, H}
assert cpu.r(A) == 0
cpu.f{C} = false
cpu.step 2              # 3
assert cpu.f == {Flag.H}
cpu.step
assert cpu.f == {Flag.H}
cpu.step
assert cpu.f == {Z, H}
cpu.step 3              # 4
assert cpu.f == {Flag.H}
cpu.step 2
assert cpu.f == {Z, H}

