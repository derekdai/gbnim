import common, gbasm

block:
  let cpu = newSm83()
  assert cpu.ticks == 0
  assert cpu.ime == false

block:
  let cpu = newSm83()
  cpu[BC] = 0x1234
  assert cpu[B] == 0x12
  assert cpu[C] == 0x34
  cpu[DE] = 0x5678
  assert cpu[D] == 0x56
  assert cpu[E] == 0x78
  cpu[HL] = 0x9abc
  assert cpu[H] == 0x9a
  assert cpu[L] == 0xbc
  cpu[AF] = 0xdef0
  assert cpu[A] == 0xde
  assert cpu[F] == 0xf0

block:
  let ops = gbasm:
    LD BC,0x1234              # 1
    LD DE,0x5678              # 2
    LD HL,0x9abc              # 3
    LD SP,0xcfff              # 4
    LD HL,0xdef0
    PUSH HL
    POP AF
  let cpu = newCpu(ops)
  cpu.step                    # 1
  assert cpu[B] == 0x12
  assert cpu[C] == 0x34
  cpu.step                    # 2
  assert cpu[D] == 0x56
  assert cpu[E] == 0x78
  cpu.step                    # 3
  assert cpu[H] == 0x9a
  assert cpu[L] == 0xbc
  cpu.step 4                  # 4
  assert cpu[A] == 0xde
  assert cpu[F] == 0xf0
