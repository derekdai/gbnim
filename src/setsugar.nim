import std/setutils

template `{}`*[T: enum](self: set[T]; flag: T): bool = flag in self
template `{}=`*[T: enum](self: set[T]; flag: T; value: bool) =
  if value:
    self.incl flag
  else:
    self.excl flag
template `+=`*[T: enum](self: set[T]; flag: T) = self.incl flag
template `-=`*[T: enum](self: set[T]; flag: T) = self.excl flag

type
  invert*[T: enum] = distinct T

template contains*[T](self: set[T]; flag: invert[T]): bool =
  T(flag.ord) in self
template `{}`*[T: enum](self: set[T]; flag: invert[T]): bool = not self{T(flag.ord)}
template `{}=`*[T: enum](self: set[T]; flag: invert[T]; value: bool) =
  self{T(flag.ord)} = not value
template `+=`*[T: enum](self: set[T]; flag: invert[T]) = self.excl T(flag.ord)
template `-=`*[T: enum](self: set[T]; flag: invert[T]) = self.incl T(flag.ord)
template inv*[T: enum](flag: T): invert[T] = invert[T](flag.ord)

func `$`*[E: enum; T: invert[E]](self: T): string {.inline.} = $"!{cast[E](self)}"

type
  iset*[E: enum] = distinct set[E]

template contains*[E: enum](self: iset[E]; flag: E): bool =
  flag notin set[E](self)
template incl*[E: enum; T: iset[E]](self: T; flag: E) =
  set[E](self).excl flag
template excl*[E: enum; T: iset[E]](self: T; flag: E) =
  set[E](self).incl flag
template `{}`*[E: enum](self: iset[E]; flag: E): bool = flag in self
template `{}=`*[E: enum](self: iset[E]; flag: E; value: bool) =
  if value:
    self.incl flag
  else:
    self.excl flag
proc default*[E: enum; T: iset[E]](_: typedesc[T]): T {.inline.} = iset[E](E.fullSet())
proc `$`*[E: enum; T: iset[E]](self: T): string =
  result = &"0b{cast[byte](self):b}{{"
  for i in E:
    if i in self:
      result.add &"{i},"
  if result.endsWith ',':
    result.setLen(result.len - 1)
  result.add "}"

