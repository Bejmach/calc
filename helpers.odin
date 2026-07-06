package calc

import "core:fmt"
import "core:strings"

find_all_ops :: proc(s: string, looking_for: []rune, out: ^[dynamic]int) {
	// Ignore operators at the start of function
	scope_start: bool = true
	ignore_next: bool = true
	found_e: bool = false
	for r, id in s {
		found: bool = false

		for op in looking_for {
			if op == r {
				if !scope_start && !((op == '-' || op == '+') && found_e) {
					found = true
				}
			}
		}

		scope_start = false
		if r == '('{
			scope_start = true
		}

		found_e = false
		if r == 'e' {
			found_e = true
		}

		if found {
			if !ignore_next {
				ignore_next = true
				append(out, id)
			}
		} else {
			ignore_next = false
		}
	}
}

find_all_ocurences :: proc {
	find_all_ocurences_rune,
	find_all_ocurences_substr,
}

find_all_ocurences_rune :: proc(s: string, r: rune, out: ^[dynamic]int) {
	offset := 0

	for {
		idx := strings.index_rune(s[offset:], r)
		if idx == -1 {
			break
		}

		actual_idx := offset + idx

		offset = actual_idx + 1

		append(out, actual_idx)
	}
}

find_all_ocurences_substr :: proc(s: string, sub: string, out: ^[dynamic]int) {
	offset := 0

	for {
		idx := strings.index(s[offset:], sub)
		if idx == -1 {
			break
		}

		actual_idx := offset + idx

		offset = actual_idx + len(sub)

		append(out, actual_idx)
	}
}

/// Find all scopes ignoring nested scopes
find_all_scopes :: proc(s: string, out: ^[dynamic]Scope) {
	offset := 0

	scope_start := -1

	scope_recursion := 0
	is_func := false
	temp_func := false
	ignore_end := 0
	for r, pos in s {
		if r == '(' {
			if scope_recursion == 0 {
				scope_start = pos
				if temp_func {
					is_func = true
				}
			}
			scope_recursion += 1
		}
		if r == ')' {
			if ignore_end == 0 {
				scope_recursion -= 1
				if scope_recursion == 0 {
					append(out, Scope{scope_start, pos, s[scope_start + 1:pos], is_func})
					is_func = false
				}
			} else {
				ignore_end -= 1
			}

		}
		temp_func = true
		for op in ops_map {
			if r == op {
				temp_func = false
			}
		}
	}
}

/// Get scope id on position from scope array
/// Return -1 if position not in scope
get_scope :: proc(pos: int, scopes: ^[]Scope) -> int {
	for scope, id in scopes {
		if scope.start <= pos && pos <= scope.end {
			return id
		}
	}
	return -1
}

strip_zeros :: proc(s: string) -> string {
	end: int = len(s)
	ignore_end: int = 0
	start: bool = false
	for r in s {
		switch r{
		case '0':
			if start{
				ignore_end += 1
			}
		case '.':
			start = true
			ignore_end += 1
		case:
			ignore_end = 0
		}
	}
	final_end := end-ignore_end
	if final_end == 2 && s[0] == '-' && s[1] == '0'{
		return s[1:final_end]
	}
	return s[:final_end]
}
