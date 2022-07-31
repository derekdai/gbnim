import gbasm
import common

block:
  let ops = gbasm:
    NOP
  let cpu = newCpu(ops)
  assert not cpu.ime
  cpu.step
  assert cpu.pc == 1

block:
  let ops = gbasm:
    EI                      # 1
    DI                      # 2
    EI                      # 3
    NOP
    INC A                   # 4
    DEC C
    LD (0xff00+C),A
    NOP
    LD C,0x0f               # 5
    LD (0xff00+C),A
  let cpu = newCpu(ops)
  cpu.step
  assert cpu.ime == true
  cpu.step
  assert cpu.ime == false
  cpu.step 2
  assert cpu.ime == true
  assert cpu.pc == 4
  cpu.step 4
  assert cpu.ime == true
  assert cpu[0xffff] == 1
  assert cpu.pc == 8
  cpu.step 3
  assert cpu.ime == false
  assert cpu[0xffff] == 1
  assert cpu[0xff0f] == 0
  assert cpu.pc == 0x40 + 1
