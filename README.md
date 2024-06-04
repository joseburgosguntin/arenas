# ⛱️ arenas

```odin
package main

import "path/to/arenas/virt"

main :: proc {
  // small, stack allocated
  {
    CAP :: 100 * mem.Kilobyte
    arr : [CAP]u8
    arena := arena_init(&arr)
    context.allocator = arena_allocator(&arena)

    vec_1, err_1 := make([dynamic]u8, CAP, CAP)
  }

  // large, heap allocated, lazily commits pages
  {
    CAP :: 10 * mem.Megabyte
    arena, err := arena_init(CAP)
    if err != nil {
        return
    }
    testing.expect_value(t, err, nil)
    defer arena_destroy(&arena)
    context.allocator = arena_allocator(&arena)

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
