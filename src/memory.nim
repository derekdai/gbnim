import ./types

type
  Memory* = ref object of RootObj
  MemoryCtrl* = ref object
    blocks: array[16, Memory]
  Rom* = ref object of Memory

method load*(self: Memory; a: Address; buf: pointer; len: uint16) {.base.} = discard
method store*(self: var Memory; a: Address; buf: pointer; len: uint16) {.base.} = discard

proc newMemoryCtrl*(): MemoryCtrl =
  MemoryCtrl()
