import common, gbasm

block:
  let ops = gbasm:
    CP A,L                # 1
    LD L,0x10             # 2
    CP A,L
    LD L,0x01             # 3
    CP A,L
    LD L,0x01             # 4
    LD A,0x10
    CP A,L
    XOR A,A               # 5
    CP A,0x01
    LD HL,0xc000          # 6
    INC (HL)
    INC A
    CP A,(HL)
  let cpu = newCpu(ops)
  cpu.step                # 1
  assert cpu.f == {Z, N}
  cpu.step 2              # 2
  assert cpu.f == {N, C}
  cpu.step 2              # 3
  assert cpu.f == {N, C, H}
  cpu.step 3              # 4
  assert cpu.f == {N, H}
  cpu.step 2              # 5
  assert cpu.f == {N, C, H}
  cpu.step 4              # 6
  assert cpu.f == {Z, N}
