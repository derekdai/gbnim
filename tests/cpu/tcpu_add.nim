import common, gbasm

block:
  let ops = gbasm:
    LD A,0xf
    LD B,1
    ADD A,B
    LD B,0xf0
    ADD A,B
    LD B,0xff
    ADD A,B
    LD L,1
    ADD A,L
  let cpu = newCpu(ops)
  cpu.step()
  assert cpu.r(A) == 0xf
  cpu.step()
  assert cpu.r(B) == 0x1
  cpu.step()
  assert cpu.r(A) == 0x10
  assert cpu.r(B) == 0x1
  assert cpu.f == {Flag.H}
  cpu.step(2)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Z}
  cpu.step(2)
  assert cpu.r(A) == 0xff
  assert cpu.f == {}
  cpu.step(2)
  assert cpu.r(A) == 0
  assert cpu.f == {Flag.C, Flag.H, Z}

block:
  let ops = gbasm:
    ADC A,H             # 1
    ADC A,H             # 2
    XOR A,A             # 3
    LD H,0xf
    ADC A,H
    LD H,0xff           # 4
    ADC A,H
    LD A,0b10101010     # 5
    LD H,0b01010101
    ADC A,H
  let cpu = newCpu(ops)
  cpu.f{H} = true
  cpu.step()                # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true
  cpu.step()                # 2
  assert cpu.r(A) == 1
  assert cpu.f == {}
  cpu.step()                # 3
  assert cpu.r(A) == 0
  assert cpu.f == {Z}
  cpu.f{C} = true
  cpu.step(2)
  assert cpu.r(A) == 0x10
  assert cpu.f == {Flag.H}
  cpu.f{C} = true           # 4
  cpu.r(A) = 0
  cpu.step(2)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Flag.H, Z}
  cpu.f{C} = true           # 5
  cpu.step(3)
  assert cpu.r(A) == 0x00
  assert cpu.f == {Flag.C, Flag.H, Z}

block:
  let ops = gbasm:
    INC A                   # 1
    JR NZ,-3
    LD A,0xf                # 2
    INC A
  let cpu = newCpu(ops)
  cpu.step()                # 1
  assert cpu.r(A) == 1
  assert cpu.f == {}
  while true:
    cpu.step()
    if cpu.pc > 2:
      break
    cpu.step()
    if cpu.f{Flag.H}:
      assert (cpu.r(A) and 0xf) == 0
  assert cpu.r(A) == 0
  assert cpu.f == {Flag.H, Z}
  cpu.step 2                # 2
  assert cpu.r(A) == 0x10
  assert cpu.f == {Flag.H}

