import common, gbasm

block:
  let ops = gbasm:
    LD A,255            # 1
    DEC A
    JR NZ,-3
  let cpu = newCpu(ops, {ffHram, ffWRam0, ffTimer})
  cpu.step
  while cpu.pc < 6:
    cpu.step
  assert cpu.pc == 6
