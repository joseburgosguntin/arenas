package page

import "base:intrinsics"
import "core:os"
import "core:testing"


MIN_SIGNED :: [9]u64 {
	0x00,
	0xff,
	0xffff,
	0x00,
	0xffff_ffff,
	0x00,
	0xffff_ffff_ffff,
	0x00,
	0xffff_ffff_ffff_ffff,
}

MAX_SIGNED :: [9]u64 {
	0x00,
	0xff >> 1,
	0xffff >> 1,
	0x00,
	0xffff_ffff >> 1,
	0x00,
	0xffff_ffff_ffff >> 1,
	0x00,
	0xffff_ffff_ffff_ffff >> 1,
}


checked_add_unsigned :: proc(
	a, b: $T,
) -> (
	result: T,
	overflowed: bool,
) where intrinsics.type_is_unsigned(T) {
	result = a + b
	if result < a {
		return result, true
	}
	return result, false
}

checked_add_signed :: proc(
	a, b: $T,
) -> (
	result: T,
	overflowed: bool,
) where !intrinsics.type_is_unsigned(T) {
	min, max := MIN_SIGNED, MAX_SIGNED
	if (b > 0 && a > cast(T)max[size_of(T)] - b) || (b < 0 && a < cast(T)min[size_of(T)] - b) {
		return 0, true
	} else {
		return a + b, false
	}
}

checked_add :: proc {
	checked_add_unsigned,
	checked_add_signed,
}

ceil_integer :: proc(n: $T) -> T where intrinsics.type_is_integer(T) {
	page_size := cast(uint)os.get_page_size()
	addr_uint := cast(uint)n
	res, flag := checked_add(addr_uint, page_size)
	assert(!flag)
	next_page_start := floor_integer(addr_uint + page_size)
	if addr_uint & (page_size - 1) == 0 {
		return n
	} else {
		return next_page_start
	}
}

ceil_ptr :: proc(address: ^$T) -> ^T {
	res := ceil_integer(cast(uint)cast(uintptr)address)
	return cast(^T)cast(uintptr)res
}

ceil :: proc {
	ceil_ptr,
	ceil_integer,
}

floor_integer :: proc(n: $T) -> T where intrinsics.type_is_integer(T) {
	page_size := cast(uint)os.get_page_size()
	return n &~ (page_size - 1)
}

floor_ptr :: proc(address: ^$T) -> ^T {
	res := floor_integer(cast(uint)cast(uintptr)address)
	return cast(^T)cast(uintptr)res
}

floor :: proc {
	floor_ptr,
	floor_integer,
}

@(test)
test_checked_add :: proc(t: ^testing.T) {
	_, u64_1 := checked_add(cast(u64)0xffff_ffff_ffff_ffff, cast(u64)0xffff_ffff_ffff_ffff)
	testing.expect_value(t, u64_1, true)
	_, i64_1 := checked_add(cast(i64)0x0fff_ffff_ffff_ffff, cast(i64)0x0fff_ffff_ffff_ffff)
	testing.expect_value(t, i64_1, false)

	_, u64_2 := checked_add(cast(u64)0xffff_ffff_ffff_ff00, cast(u64)0x0000_0000_0000_00ff)
	testing.expect_value(t, u64_2, false)
	_, i64_2 := checked_add(
		transmute(i64)cast(u64)0xffff_ffff_ffff_ff00,
		transmute(i64)cast(u64)0x0000_0000_0000_00ff,
	)
	testing.expect_value(t, i64_2, false)
}

@(test)
test_ceil :: proc(t: ^testing.T) {
	page_size := cast(uint)os.get_page_size()

	n_1 := ceil(page_size)
	testing.expect_value(t, n_1, page_size * 1)
	p_1 := ceil(cast(^u8)cast(uintptr)(page_size))
	testing.expect_value(t, p_1, cast(^u8)cast(uintptr)(page_size * 1))

	n_2 := ceil(page_size + 1)
	testing.expect_value(t, n_2, page_size * 2)
	p_2 := ceil(cast(^u8)cast(uintptr)(page_size + 1))
	testing.expect_value(t, p_2, cast(^u8)cast(uintptr)(page_size * 2))

	n_3 := ceil(page_size - 1)
	testing.expect_value(t, n_3, page_size * 1)
	p_3 := ceil(cast(^u8)cast(uintptr)(page_size - 1))
	testing.expect_value(t, p_3, cast(^u8)cast(uintptr)(page_size * 1))
}

@(test)
test_floor :: proc(t: ^testing.T) {
	page_size := cast(uint)os.get_page_size()

	n_1 := floor(page_size)
	testing.expect_value(t, n_1, page_size * 1)
	p_1 := floor(cast(^u8)cast(uintptr)(page_size))
	testing.expect_value(t, p_1, cast(^u8)cast(uintptr)(page_size * 1))

	n_2 := floor(page_size + 1)
	testing.expect_value(t, n_2, page_size * 1)
	p_2 := floor(cast(^u8)cast(uintptr)(page_size + 1))
	testing.expect_value(t, p_2, cast(^u8)cast(uintptr)(page_size * 1))

	n_3 := floor(page_size - 1)
	testing.expect_value(t, n_3, page_size * 0)
	p_3 := floor(cast(^u8)cast(uintptr)(page_size - 1))
	testing.expect_value(t, p_3, cast(^u8)cast(uintptr)(page_size * 0))
}
