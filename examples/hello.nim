import cpu, memory

block:
  let rom = newRom(@[0u8])
  let mc = newMemoryCtrl()
  mc.map(ROM0, rom)
  let c = newCpu(mc)

  c.step()
  assert c.pc == 0x1

block:
  let rom = newRom(@[0xc3u8, 0xfe, 0xef])
  let mc = newMemoryCtrl()
  mc.map(ROM0, rom)
  let c = newCpu(mc)

  c.step()

  assert c.pc == 0xeffe
