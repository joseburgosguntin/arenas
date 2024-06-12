package virt

import "../page"
import "core:mem"
import "core:mem/virtual"
import "core:sync"
import "core:testing"

Arena :: struct {
	buf:      [^]u8,
	cap, len: uint,
	mutex:    sync.Recursive_Mutex,
}

arena_init :: proc(size: uint) -> (arena: Arena, err: mem.Allocator_Error) {
	cap := cast(uint)cast(uintptr)page.ceil(cast(^u8)cast(uintptr)size)
	buf := raw_data(virtual.reserve(cap) or_return)
	arena = Arena {
		buf = buf,
		cap = cap,
		len = 0,
	}
	return arena, err
}
arena_destroy :: proc(arena: ^Arena) {
	sync.guard(&arena.mutex)
	virtual.release(arena.buf, arena.cap)
	arena^ = Arena {
		buf   = nil,
		len   = 0,
		cap   = 0,
		mutex = sync.Recursive_Mutex{},
	}
}

arena_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	bytes: []byte,
	err: mem.Allocator_Error,
) {

	arena := cast(^Arena)allocator_data

	sync.guard(&arena.mutex)

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		align_mask := cast(uint)alignment - 1
		aligned_used := (arena.len + align_mask) &~ align_mask

		if arena.cap - aligned_used < cast(uint)size {
			return nil, .Out_Of_Memory
		}

		ptr := arena.buf[aligned_used:]
		virtual.commit(page.ceil(ptr), cast(uint)size) or_return

		arena.len += cast(uint)size
		return mem.byte_slice(ptr, size), nil

	case .Free:
		return nil, .Mode_Not_Implemented

	case .Free_All:
		arena.len = 0

	case .Resize:
		return mem.default_resize_bytes_align(
			mem.byte_slice(old_memory, old_size),
			size,
			alignment,
			arena_allocator(arena),
		)

	case .Resize_Non_Zeroed:
		return mem.default_resize_bytes_align_non_zeroed(
			mem.byte_slice(old_memory, old_size),
			size,
			alignment,
			arena_allocator(arena),
		)

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {
				.Alloc,
				.Alloc_Non_Zeroed,
				.Free_All,
				.Resize,
				.Resize_Non_Zeroed,
				.Query_Features,
			}
		}
		return nil, nil

	case .Query_Info:
		return nil, .Mode_Not_Implemented
	}

	return nil, nil
}

arena_allocator :: proc(arena: ^Arena) -> mem.Allocator {
	return {procedure = arena_allocator_proc, data = arena}
}

@(test)
test_int_too_many :: proc(t: ^testing.T) {
	CAP :: 10 * mem.Megabyte
	arena, err := arena_init(CAP)
	testing.expect_value(t, err, nil)
	defer arena_destroy(&arena)
	context.allocator = arena_allocator(&arena)

	vec, err_1 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_1, nil)
	byte, err_2 := new(u8)
	testing.expect_value(t, err_2, mem.Allocator_Error.Out_Of_Memory)
}

@(test)
test_append_too_many :: proc(t: ^testing.T) {
	CAP :: 10 * mem.Megabyte
	arena, err := arena_init(CAP)
	testing.expect_value(t, err, nil)
	defer arena_destroy(&arena)
	context.allocator = arena_allocator(&arena)

	vec, err_1 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_1, nil)
	x, err_2 := append(&vec, 0)
	testing.expect_value(t, err_2, mem.Allocator_Error.Out_Of_Memory)
}

@(test)
test_free_all :: proc(t: ^testing.T) {
	CAP :: 10 * mem.Megabyte
	arena, err := arena_init(CAP)
	testing.expect_value(t, err, nil)
	defer arena_destroy(&arena)
	context.allocator = arena_allocator(&arena)

	vec_1, err_1 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_1, nil)
	free_all()
	vec_2, err_2 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_2, nil)
	vec_3, err_3 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_3, mem.Allocator_Error.Out_Of_Memory)
}

@(test)
test_250_gb_access :: proc(t: ^testing.T) {
	CAP :: 250 * mem.Gigabyte
	arena, err := arena_init(CAP)
	testing.expect_value(t, err, nil)
	defer arena_destroy(&arena)
	context.allocator = arena_allocator(&arena)

	vec_1, err_1 := make([dynamic]u8, arena.cap, arena.cap)
	testing.expect_value(t, err_1, mem.Allocator_Error.Out_Of_Memory)
}

@(test)
test_overwritting :: proc(t: ^testing.T) {
	CAP :: 2
	arena, err := arena_init(CAP)
	testing.expect_value(t, err, nil)
	defer arena_destroy(&arena)
	context.allocator = arena_allocator(&arena)

	n_1, err_1 := new(u8)
	testing.expect_value(t, err_1, nil)
	n_1^ = 0xff
	n_2, err_2 := new(u8)
	testing.expect_value(t, err_2, nil)
	n_2^ = 0x00
	testing.expect_value(t, n_1^, 0xff)
	testing.expect_value(t, n_2^, 0x00)
}
