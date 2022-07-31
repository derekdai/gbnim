import gbasm
import common

block:
  let ops = gbasm:
    NOP
  let cpu = newCpu(ops, {ffHram, ffWRam0, ffInterrupt})
  assert not cpu.ime
  cpu.step
  assert cpu.pc == 1

block:
  let ops = gbasm:
    EI                      # 1
    DI                      # 2
    EI                      # 3
    NOP
    LD SP,0xcfff            # 4
    INC A
    DEC C
    LD (0xff00+C),A
    NOP
    LD C,0x0f               # 5
    LD (0xff00+C),A
  let cpu = newCpu(ops, {ffWRam0, ffInterrupt})
  cpu.step                  # 1
  assert cpu.ime == true
  cpu.step                  # 2
  assert cpu.ime == false
  cpu.step 2                # 3, 啟用 interrupt
  assert cpu.ime == true
  assert cpu.pc == 4
  cpu.step 5                # 4, 寫 0b000_0001 到 IE 啟用 VBlank interrupt
  assert cpu.ime == true
  assert cpu[0xffff] == 1
  assert cpu.pc == 11
  cpu.step 3                # 5, 寫 0xb0000_0001 到 IF, 觸發 VBlank interrupt
  assert cpu.ime == false
  assert cpu[0xffff] == 1
  assert cpu[0xff0f] == 0
  assert cpu.pc == 0x40 + 1
