import cpu
import memory

type
  Dmg* = ref object

proc newDmg*(): Dmg =
  discard

func run*(self: Dmg) =
  discard
