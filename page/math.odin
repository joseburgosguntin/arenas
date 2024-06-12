package page

import "core:os"
import "core:testing"

checked_add :: proc(a, b: uint) -> (result: uint, overflowed: bool) {
	result = a + b
	if result < a {
		return result, true
	}
	return result, false
}

PAGE_SIZE := cast(uint)os.get_page_size()

ceil :: proc(address: ^$T) -> ^T {
	addr_uint := cast(uint)cast(uintptr)address
	next_page_start := floor(cast(^T)cast(uintptr)(addr_uint + PAGE_SIZE))
	if addr_uint & (PAGE_SIZE - 1) == 0 {
		return address
	} else {
		return next_page_start
	}
}

floor :: proc(address: ^$T) -> ^T {
	return cast(^T)cast(uintptr)(cast(uint)cast(uintptr)address &~ (PAGE_SIZE - 1))
}

@(test)
test_checked_add :: proc(t: ^testing.T) {
	_, flag1 := checked_add(0xffffffffffffffff, 0xffffffffffffffff)
	testing.expect_value(t, flag1, true)

	_, flag2 := checked_add(0xffffffffffffff00, 0x00000000000000ff)
	testing.expect_value(t, flag2, false)
}

@(test)
test_ceil :: proc(t: ^testing.T) {
	n_1 := ceil(cast(^u8)cast(uintptr)(PAGE_SIZE))
	testing.expect_value(t, n_1, cast(^u8)cast(uintptr)(PAGE_SIZE * 1))

	n_2 := ceil(cast(^u8)cast(uintptr)(PAGE_SIZE + 1))
	testing.expect_value(t, n_2, cast(^u8)cast(uintptr)(PAGE_SIZE * 2))

	n_3 := ceil(cast(^u8)cast(uintptr)(PAGE_SIZE - 1))
	testing.expect_value(t, n_3, cast(^u8)cast(uintptr)(PAGE_SIZE * 1))
}

@(test)
test_floor :: proc(t: ^testing.T) {
	n_1 := floor(cast(^u8)cast(uintptr)(PAGE_SIZE))
	testing.expect_value(t, n_1, cast(^u8)cast(uintptr)(PAGE_SIZE * 1))

	n_2 := floor(cast(^u8)cast(uintptr)(PAGE_SIZE + 1))
	testing.expect_value(t, n_2, cast(^u8)cast(uintptr)(PAGE_SIZE * 1))

	n_3 := floor(cast(^u8)cast(uintptr)(PAGE_SIZE - 1))
	testing.expect_value(t, n_3, cast(^u8)cast(uintptr)(PAGE_SIZE * 0))
}
