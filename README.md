# ⛱️ arenas

```odin
package main

import "core:mem"
import "path/to/arenas/virt"
import "path/to/arenas/buf"

main :: proc() {
  // small, stack allocated
  {
    CAP :: 100 * mem.Kilobyte
    arr : [CAP]u8
    arena := buf.arena_init(&arr)
    context.allocator = buf.arena_allocator(&arena)

    vec_1, err_1 := make([dynamic]u8, CAP, CAP)
  }

  // large, heap allocated, lazily commits pages
  {
    CAP :: 10 * mem.Megabyte
    arena, err := virt.arena_init(CAP)
    if err != nil {
        return
    }
    defer virt.arena_destroy(&arena)
    context.allocator = virt.arena_allocator(&arena)

    // rounds up to the next page
    vec_1, err_1 := make([dynamic]u8, arena.cap, arena.cap)
  }
}
```

## Development

```sh
odin build ./virt # Build arena/virt
odin test ./virt  # Run arena/virt tests
odin build ./buf # Build arena/buf
odin test ./buf   # Run arena/buf tests
```

## References

Odin's built in arenas [core:mem/virtual](https://github.com/odin-lang/Odin/tree/master/core/mem/virtual)
