#+feature dynamic-literals
package calc

import "base:runtime"
import "core:fmt"
import "core:slice"
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
		if r == '(' {
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

find_last_op :: proc(s: string, looking_for: []rune) -> int {
	scope_start: bool = true
	ignore_next: bool = true
	found_e: bool = false
	final_id: int = -1
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
		if r == '(' {
			scope_start = true
		}

		found_e = false
		if r == 'e' {
			found_e = true
		}

		if found {
			if !ignore_next {
				ignore_next = true
				final_id = id
			}
		} else {
			ignore_next = false
		}
	}
	return final_id
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

str_len_ord :: proc(lhs, rhs: string) -> bool{
	return len(lhs) < len(rhs)
}

FuncData :: struct{
	pos: int,
	func: string
}

find_all_functions :: proc(s: string, customs: ^CustomData, out: ^[dynamic]FuncData) {
	depth := 0

	func_arr_len := len(func_arr)
	full_func_arr := make([]string, len(customs.functions) + func_arr_len)
	defer delete(full_func_arr)

	for func, pos in func_arr{
		full_func_arr[pos] = func
	}
	k := 0
	for key, value in customs.functions{
		full_func_arr[func_arr_len + k] = key
	}

	slice.sort_by(full_func_arr[:], str_len_ord)

	s_len := len(s)

	for i := 0; i<len(s); i+=1 {
		r := s[i]
		switch r {
		case '<', '(':
			depth += 1

		case '>', ')':
			depth -= 1
		case:
			#reverse for func in full_func_arr{
				f_len := len(func)
				f_end := i + f_len
				if f_end >= s_len{
					continue
				}
				
				if s[i:f_end] == func && s[f_end] == '(' {
					append(out, FuncData{i, func})
					i += f_len
				}
			}
		}
	}
}

/// Find all scopes ignoring nested scopes
find_all_scopes :: proc(s: string, out: ^[dynamic]Scope) {
	scope_start := -1

	scope_recursion := 0
	scope_mode: ScopeMode

	temp_func := false
	ignore_end := 0
	for r, pos in s {
		switch r {
		case '<':
			scope_recursion += 1
		case '>':
			scope_recursion -= 1
		case '(':
			if scope_recursion == 0 {
				scope_start = pos
				if temp_func {
					scope_mode = .Func
				} else {
					scope_mode = .Def
				}
			}
			scope_recursion += 1

		case ')':
			if ignore_end == 0 {
				scope_recursion -= 1
				if scope_recursion == 0 {
					append(out, Scope{scope_start, pos, s[scope_start + 1:pos], scope_mode})
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

split_preserving_brackets :: proc(s: string, splitters: []rune) -> (res: []string) {
	depth := 0

	splits := [dynamic]int{}
	defer delete(splits)

	for r, id in s {
		switch r {
		case '<', '(':
			depth += 1

		case '>', ')':
			depth -= 1

		case:
			if slice.contains(splitters, r) && depth == 0 {
				append(&splits, id)
			}
		}
	}

	n := len(splits)
	res = make([]string, n + 1, context.temp_allocator)

	if n == 0 {
		res[0] = s
	} else {
		res[0] = s[0:splits[0]]

		for i := 1; i < n; i += 1 {
			res[i] = s[splits[i - 1] + 1:splits[i]]
		}

		res[n] = s[splits[n - 1] + 1:]
	}

	return res
}

find_all_iterators :: proc(s: string, out: ^[dynamic]Iterator) {
	iter_start := -1

	iter_recursion := 0

	for r, pos in s {
		switch r {
		case '<':
			if iter_recursion == 0 {
				iter_start = pos
			}
			iter_recursion += 1

		case '>':
			iter_recursion -= 1
			if iter_recursion == 0 {
				content: string = s[iter_start + 1:pos]
				append(
					out,
					Iterator{iter_start, pos, split_preserving_brackets(content, {','}), 1},
				)
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
		switch r {
		case '0':
			if start {
				ignore_end += 1
			}
		case '.':
			start = true
			ignore_end += 1
		case:
			ignore_end = 0
		}
	}
	final_end := end - ignore_end
	if final_end == 2 && s[0] == '-' && s[1] == '0' {
		return s[1:final_end]
	}
	return s[:final_end]
}
