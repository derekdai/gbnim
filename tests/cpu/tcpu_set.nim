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
cpu.f = {Z, N, C, H}
cpu.step                # 1
assert cpu.r(B) == 0b0000_0001
assert cpu.f == {Z, N, C, H}
cpu.f = {Z, N}
cpu.step                # 2
assert cpu.r(A) == 0b1000_0000
assert cpu.f == {Z, N}
cpu.f = {}
cpu.step 3              # 3
assert cpu[0xc000] == 0b0001_1000
assert cpu.f == {}
cpu.step 2              # 4
assert cpu.r(D) == 0xff
assert cpu.f == {}

