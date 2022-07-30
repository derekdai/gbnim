import common, gbasm

block:
  let ops = gbasm:
    SLA B               # 1
    LD D,0b10101010     # 2
    SLA D
    LD HL,0xc000        # 3
    LD (HL),0b1000_0001
    SLA (HL)
    SLA (HL)
  let cpu = newCpu(ops)
  cpu.step              # 1
  assert cpu.r(B) == 0
  assert cpu.f == {Z}
  cpu.step 2            # 2
  assert cpu.r(D) == 0b0101_0100
  assert cpu.f == {Flag.C}
  cpu.step 2            # 3
  assert cpu[0xc000] == 0b1000_0001
  cpu.step
  assert cpu[0xc000] == 0b0000_0010
  assert cpu.f == {Flag.C}
  cpu.step
  assert cpu[0xc000] == 0b0000_0100
  assert cpu.f == {}

block:
  let ops = gbasm:
    SRL E               # 1
    LD D,0b01010101     # 2
    SRL D
    LD HL,0xc000        # 3
    LD (HL),0b1000_0001
    SRL (HL)
    SRL (HL)
  let cpu = newCpu(ops)
  cpu.step              # 1
  assert cpu.r(E) == 0
  assert cpu.f == {Z}
  cpu.step 2            # 2
  assert cpu.r(D) == 0b0010_1010
  assert cpu.f == {Flag.C}
  cpu.step 2            # 3
  assert cpu[0xc000] == 0b1000_0001
  cpu.step
  assert cpu[0xc000] == 0b0100_0000
  assert cpu.f == {Flag.C}
  cpu.step
  assert cpu[0xc000] == 0b0010_0000
  assert cpu.f == {}

block:
  let ops = gbasm:
    SRA H               # 1
    LD D,0b01010101     # 2
    SRA D
    LD HL,0xc000        # 3
    LD (HL),0b1000_0001
    SRA (HL)
    SRA (HL)
  let cpu = newCpu(ops)
  cpu.step              # 1
  assert cpu.r(H) == 0
  assert cpu.f == {Z}
  cpu.step 2            # 2
  assert cpu.r(D) == 0b0010_1010
  assert cpu.f == {Flag.C}
  cpu.step 2            # 3
  assert cpu[0xc000] == 0b1000_0001
  cpu.step
  assert cpu[0xc000] == 0b1100_0000
  assert cpu.f == {Flag.C}
  cpu.step
  assert cpu[0xc000] == 0b1110_0000
  assert cpu.f == {}

