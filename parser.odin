#+feature dynamic-literals
package calc

import "core:fmt"
import "core:math"
import "core:slice"
import "core:strconv"
import "core:strings"

Operator :: enum {
	Nil,
	Add,
	Sub,
	Mult,
	Div,
	Pow,
}

ScopeMode :: enum {
	Def,
	Func,
}

Scope :: struct {
	start, end: int,
	content:    string,
	scope_mode: ScopeMode,
}

Iterator :: struct {
	start, end: int,
	content:    []string,
	divider:    int, // divide number bu this before doing modulo to find correct option
}

Part :: struct {
	parent:      ^Part,
	left, right: ^Part,
	content:     string,
	operator:    Operator,
}

CustomData :: struct {
	functions: map[string]Function,
	consts:    map[string]string,
}
Function :: struct {
	args:      int,
	operation: string,
}

delete_part :: proc(part: ^Part) {
	if part == nil {
		return
	}

	delete_part(part.left)
	delete_part(part.right)
	free(part)
}

delete_iter :: proc(iter: ^Iterator) {
	delete(iter.content)
	free(iter)
}

repeat :: proc(r: rune, n: int) -> string {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	for i in 0 ..< n {
		strings.write_rune(&b, r)
	}

	return strings.clone(strings.to_string(b))
}

print_part :: proc(part: ^Part) {
	stack := [dynamic]^Part{}
	defer delete(stack)

	current_part: ^Part = part
	prefix := ""
	repeat_offset: int = 0

	for {
		if current_part == nil {
			if len(stack) == 0 {
				break
			}
			current_part = pop_dynamic_array(&stack).right
			repeat_offset = 1
			prefix = "R"

		} else {
			repeat_str := repeat('-', len(stack) + repeat_offset)
			defer delete(repeat_str)
			fmt.printfln("%s: %s %v", prefix, repeat_str, current_part)

			append(&stack, current_part)
			current_part = current_part.left
			repeat_offset = 0
			prefix = "L"
		}
	}
}

solve_part :: proc(part: ^Part, debug: bool) -> (result: f64, succes: bool) {
	switch part.operator {
	case .Nil:
		minus_count := 0
		for r in part.content {
			if r == '-' {
				minus_count += 1
			} else {
				break
			}
		}
		flip := (minus_count % 2) != 0
		result, ok := strconv.parse_f64(part.content[minus_count:])
		if flip {
			result = -result
		}
		if ok {
			return result, true

		} else if debug {
			fmt.eprintfln("Cant parse \"%s\" to f64", part.content)
		}
	case .Add:
		left, l_ok := solve_part(part.left, debug)
		right, r_ok := solve_part(part.right, debug)

		if l_ok && r_ok {
			return left + right, true
		}
	case .Sub:
		left, l_ok := solve_part(part.left, debug)
		right, r_ok := solve_part(part.right, debug)

		if l_ok && r_ok {
			return left - right, true
		}
	case .Mult:
		left, l_ok := solve_part(part.left, debug)
		right, r_ok := solve_part(part.right, debug)

		if l_ok && r_ok {
			return left * right, true
		}
	case .Div:
		left, l_ok := solve_part(part.left, debug)
		right, r_ok := solve_part(part.right, debug)

		if l_ok && r_ok {
			if right == 0 {
				return 0, true
			}
			return left / right, true
		}

	case .Pow:
		left, l_ok := solve_part(part.left, debug)
		right, r_ok := solve_part(part.right, debug)

		if l_ok && r_ok {
			return math.pow_f64(left, right), true
		}
	}
	return {}, false
}

solve_iterator :: proc(i: ^Iterator, gen: int) -> (result: string, succes: bool) {
	n := len(i.content)
	if n == 0 {
		return "", false
	}

	local_gen: int = gen / i.divider
	return i.content[local_gen % n], true
}

first_order_ops := []rune{'^'}

second_order_ops := []rune{'*', '/'}

third_order_ops := []rune{'+', '-'}

ops_map := map[rune]Operator {
	'*' = .Mult,
	'/' = .Div,
	'+' = .Add,
	'-' = .Sub,
	'^' = .Pow,
}

// Rounded to 15 numbers after dot
const_map := map[string]string {
	"PI"  = "3.14159265358979323846264338327950288",
	"HI"  = "3.14159265358979323846264338327950288", // alias for "PI" to allow for writing of "cou(HI)"
	"TAU" = "6.28318530717958647692528676655900576",
	"E"   = "2.71828182845904523536",
}

split_part :: proc(p: ^Part, parsers: ^[]rune) {
	current_part: ^Part = p
	stack := [dynamic]^Part{}
	defer delete(stack)
	for {
		if current_part != nil {
			if current_part.operator == Operator.Nil {
				occurences := [dynamic]int{}
				defer delete(occurences)

				find_all_ops(current_part.content, parsers^, &occurences)

				#reverse for id in occurences {
					operator: rune = rune(current_part.content[id])
					ops, ok := ops_map[operator]
					if !ok {
						//			fmt.println("Not Ok", operator)
						return
					}
					left_part: ^Part = new(Part)
					left_part.content = current_part.content[:id]
					right_part: ^Part = new(Part)
					right_part.content = current_part.content[id + 1:]
					current_part.left = left_part
					current_part.right = right_part
					current_part.operator = ops

					current_part = current_part.left
					append(&stack, current_part.right)
				}
			} else {
				append(&stack, current_part.left, current_part.right)
			}
		}
		if len(stack) > 0 {
			current_part = pop(&stack)
		} else {
			break
		}
	}
}

solve :: proc(
	s: string,
	customs: ^CustomData,
	debug: bool,
) -> (
	r: string,
	succes: bool,
	was_allocated := false,
) {
	old_func := s
	final_func, all := strings.replace_all(s, " ", "", context.allocator)
	if all {
		was_allocated = true
		delete(old_func)
	}

	final_const_arr := make([]string, len(const_map) + len(customs.consts))
	defer delete(final_const_arr)

	k := 0

	for key, value in const_map {
		final_const_arr[k] = key
		k += 1
	}
	for key, value in customs.consts {
		final_const_arr[k] = key
		k += 1
	}

	slice.sort_by(final_const_arr[:], str_len_ord)

	#reverse for const in final_const_arr {
		old_func := final_func

		new_value, ok := const_map[const]
		if !ok {
			new_value, _ = customs.consts[const]
		}

		final_func, all = strings.replace_all(final_func, const, new_value)
		if all {
			was_allocated = true
			delete(old_func)
		}
	}

	r, succes, all = solve_iter(final_func, customs, debug)

	if was_allocated {
		delete(final_func)
	}

	return r, succes, was_allocated
}

solve_iter :: proc(
	s: string,
	custom_functions: ^CustomData,
	debug: bool,
) -> (
	r: string,
	succes: bool,
	was_allocated: bool,
) {
	gen_iterations := 1

	iterators := [dynamic]Iterator{}
	defer delete(iterators)

	// Get all iterators in function
	find_all_iterators(s, &iterators)

	if len(iterators) == 0 {
		r, succes = solve_no_iter(s, custom_functions, debug)
		if succes {
			r = strip_zeros(r)
		}
		return r, succes, false
	}

	// assing dividers for all iterators, to make the furthest ones change the most frequently
	#reverse for &iter in iterators {
		iter.divider = gen_iterations
		gen_iterations *= len(iter.content)
	}

	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	strings.write_rune(&b, '<')

	for g := 0; g < gen_iterations; g += 1 {
		offset := 0

		local_b := strings.builder_make()
		defer strings.builder_destroy(&local_b)

		for &iter in iterators {
			result, ok := solve_iterator(&iter, g)

			strings.write_string(&local_b, s[offset:iter.start])
			strings.write_string(&local_b, result)

			offset = iter.end + 1
		}

		strings.write_string(&local_b, s[offset:])

		local_func := strings.to_string(local_b)

		result, ok, all := solve_iter(local_func, custom_functions, debug)
		if ok {
			strings.write_string(&b, result)
			if all {
				delete(result)
			}
		} else {
			strings.write_string(&b, "ERR")
		}
		if g < gen_iterations - 1 {
			strings.write_string(&b, ", ")
		}
	}

	strings.write_rune(&b, '>')

	return strings.clone(strings.to_string(b)), true, true
}

/// Tries to solve passed string and returns provided string if failed
solve_no_iter :: proc(
	s: string,
	custom_functions: ^CustomData,
	debug: bool,
) -> (
	r: string,
	succes: bool,
) {
	scopes := [dynamic]Scope{}
	defer delete(scopes)

	find_all_scopes(s, &scopes)
	if debug {
		fmt.println(scopes)
	}

	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	offset := 0

	for scope, id in scopes {
		strings.write_string(&b, s[offset:scope.start])

		if scope.scope_mode == .Def {
			scope_result, _ := solve_no_iter(scope.content, custom_functions, debug)
			strings.write_string(&b, scope_result)
		} else if scope.scope_mode == .Func {
			parts := split_preserving_brackets(scope.content, {','})

			strings.write_rune(&b, '(')
			for part, id in parts {
				part_result, _ := solve_no_iter(part, custom_functions, debug)
				strings.write_string(&b, part_result)
				if id < len(parts) - 1 {
					strings.write_rune(&b, ',')
				}
			}
			strings.write_rune(&b, ')')
		}

		//fmt.println(scope_result, ok)
		offset = scope.end + 1
	}
	strings.write_string(&b, s[offset:])

	final_func := strings.to_string(b)

	final_func, _ = calculate_functons(final_func, custom_functions, debug)
	defer delete(final_func)

	base_part: ^Part = new(Part)
	defer delete_part(base_part)
	base_part.content = final_func

	// Operation order reversed because the solver works from bottom of the tree where the later solved operatiors land
	split_part(base_part, &third_order_ops)
	split_part(base_part, &second_order_ops)
	split_part(base_part, &first_order_ops)

	if debug {
		print_part(base_part)
	}
	result, ok := solve_part(base_part, debug)
	//fmt.println(result)
	if ok {
		result_str := fmt.tprintf("%.15f", result)
		//		fmt.println(result_str)
		return result_str, true
	}
	return s, false
}
