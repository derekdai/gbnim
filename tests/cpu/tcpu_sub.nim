import common, gbasm

block:
  let ops = gbasm:
    SUB A,A                 # 1
    LD A,1                  # 2
    LD B,1
    SUB A,B
    SUB A,B                 # 3
    LD A,0x10               # 4
    SUB A,B
    XOR A,A                 # 5
    LD B,0x10
    SUB A,B
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step 3                # 2
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step                  # 3
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, Flag.H, N}
  cpu.step 2                # 4
  assert cpu.r(A) == 0xf
  assert cpu.f == {Flag.H, N}
  cpu.step 3                # 5
  assert cpu.r(A) == 0xf0
  assert cpu.f == {Flag.C, N}

block:
  let ops = gbasm:
    SBC A,A                 # 1
    LD L,1                  # 2
    SBC A,L
    LD A,0                  # 3
    SBC A,0
    SBC A,0xf               # 4
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0
  assert cpu.f == {Z, N}
  cpu.step 2                # 2
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, H, N}
  cpu.step 2                # 3
  assert cpu.r(A) == 0xff
  assert cpu.f == {Flag.C, H, N}
  cpu.step                  # 4
  assert cpu.r(A) == 0xef
  assert cpu.f == {N, H}

block:
  let ops = gbasm:
    DEC A                   # 1
    LD B,0x10               # 2
    DEC B
    LD C,1                  # 3
    DEC C
  let cpu = newCpu(ops)
  cpu.step                  # 1
  assert cpu.r(A) == 0xff
  assert cpu.f == {N, H}
  cpu.step 2                # 2
  assert cpu.r(B) == 0xf
  assert cpu.f == {N, H}
  cpu.step 2                # 3
  assert cpu.r(C) == 0
  assert cpu.f == {N, Z}

