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

Scope :: struct {
	start, end: int,
	content:    string,
	is_func:    bool,
}

Part :: struct {
	parent:      ^Part,
	left, right: ^Part,
	content:     string,
	operator:    Operator,
}

delete_part :: proc(part: ^Part) {
	if part == nil {
		return
	}

	delete_part(part.left)
	delete_part(part.right)
	free(part)
}

repeat :: proc(r: rune, n: int) -> string {
	b := strings.builder_make()

	for i in 0 ..< n {
		strings.write_rune(&b, r)
	}

	return strings.to_string(b)
}

print_part :: proc(part: ^Part) {
	stack := [dynamic]^Part{}

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
			fmt.printfln(
				"%s: %s %v",
				prefix,
				repeat('-', len(stack) + repeat_offset),
				current_part,
			)

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
	return 0, false
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
					operator: rune = rune(p.content[id])
					ops, ok := ops_map[operator]
					if !ok {
						//			fmt.println(operator)
						return
					}
					left_part: ^Part = new(Part)
					left_part.content = current_part.content[:id]
					right_part: ^Part = new(Part)
					right_part.content = current_part.content[id + 1:]
					current_part.left = left_part
					current_part.right = right_part
					current_part.operator = ops
				}
			}
			append(&stack, current_part.left, current_part.right)
		}
		if len(stack) > 0 {
			current_part = pop(&stack)
		} else {
			break
		}
	}


}

/// Tries to solve passed string and returns provided string if failed
solve :: proc(s: string, is_first: bool, debug: bool) -> (r: string, succes: bool) {
	scopes := [dynamic]Scope{}
	defer delete(scopes)

	final_func := s
	if is_first {
		final_func, _ = strings.replace_all(s, " ", "")

		for key, value in const_map {
			final_func, _ = strings.replace_all(final_func, key, value)
		}
	}

	find_all_scopes(final_func, &scopes)
	//fmt.println(scopes)

	for scope, id in scopes {
		scope_result: string
		ok: bool = true

		if !scope.is_func {
			scope_result, ok = solve(scope.content, false, debug)
		} else {
			parts, _ := strings.split(scope.content, ",")
			builder := strings.builder_make()
			strings.write_rune(&builder, '(')
			for part, id in parts {
				part_result, part_ok := solve(part, false, debug)
				strings.write_string(&builder, part_result)
				if id < len(parts) - 1 {
					strings.write_rune(&builder, ',')
				}
				if !part_ok {
					ok = false
				}
			}
			strings.write_rune(&builder, ')')
			scope_result = strings.to_string(builder)
		}

		//fmt.println(scope_result, ok)
		if ok {
			scope_len := scope.end - scope.start + 1
			result_len := len(scope_result)
			len_dif := scope_len - result_len

			builder := strings.builder_make()
			strings.write_string(&builder, final_func[:scope.start])
			strings.write_string(&builder, scope_result)
			strings.write_string(&builder, final_func[scope.end + 1:])
			final_func = strings.to_string(builder)

			//fmt.println(final_func)

			for &scope in scopes {
				scope.start -= len_dif
				scope.end -= len_dif
			}
		}
	}

	final_func, _ = calculate_functons(final_func)

	base_part: ^Part = new(Part)
	defer delete_part(base_part)
	base_part.content = final_func

	// Operation order reversed because the solver works from bottom of the tree where the later solved operatiors land
	split_part(base_part, &third_order_ops)
	split_part(base_part, &second_order_ops)
	split_part(base_part, &first_order_ops)

	current_part: ^Part = base_part
	stack := [dynamic]^Part{}
	defer delete(stack)
	for {
		if current_part != nil {
			if current_part.operator == Operator.Nil {
				split_part(current_part, &first_order_ops)
			}
			append(&stack, current_part.left, current_part.right)
		}
		if len(stack) > 0 {
			current_part = pop(&stack)
		} else {
			break
		}
	}

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
