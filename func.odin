#+feature dynamic-literals
package calc

import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"

void :: struct {}

func_arr := []string {
	"sqrt",
	"pow",
	"round",
	"sin",
	"sen", // "sin" alias to allow for writing of sen(PI)
	"cos",
	"cou", // "cos" alias to allow for writing of cou(HI)
	"tan",
	"chan", // "tan" alias
	"clamp",
	"fac", // factorial(silnia)
	"vecLen",
	"elim", // limit value to certain ranges. Usefull for custom functions
	"emin",
	"emax",
}

func_wrap :: proc(
	name: string,
	args: []f64,
	cur_depth, max_depth: i32,
	customs: ^CustomData,
	debug: bool,
) -> (
	result: f64,
	succes: bool,
) {
	arg_len := len(args)
	switch name {
	case "sqrt":
		if arg_len == 1 {
			return math.sqrt_f64(args[0]), true
		}
	case "pow":
		if arg_len == 2 {
			return math.pow_f64(args[0], args[1]), true
		}
	case "round":
		if arg_len == 2 {
			return func_round(args[0], args[1]), true
		}
	case "sin", "sen":
		if arg_len == 1 {
			return math.sin_f64(args[0]), true
		}
	case "cos", "cou":
		if arg_len == 1 {
			return math.cos_f64(args[0]), true
		}
	case "tan", "chan":
		if arg_len == 1 {
			return math.tan_f64(args[0]), true
		}
	case "clamp":
		if arg_len == 3 {
			return math.clamp(args[0], args[1], args[2]), true
		}
	case "fac":
		if arg_len == 1 {
			return f64(math.factorial(int(args[0]))), true
		}
	case "vecLen":
		if arg_len > 0 {
			return func_vec_len(args), true
		}
	case "elim":
		if arg_len == 3 {
			return func_elim(args[0], args[1], args[2])
		}
	case "emin":
		if arg_len == 2 {
			return func_emin(args[0], args[1])
		}
	case "emax":
		if arg_len == 2 {
			return func_emax(args[0], args[1])
		}
	case:
		func, ok := customs.functions[name]
		if ok && func.args == arg_len {
			return solve_custom_function(
				func.operation,
				args,
				cur_depth,
				max_depth,
				customs,
				debug,
			)
		}
	}


	return 0, false
}

solve_custom_function :: proc(
	operation: string,
	args: []f64,
	cur_depth, max_depth: i32,
	customs: ^CustomData,
	debug: bool,
) -> (
	result: f64,
	succes: bool,
) {
	operation := strings.clone(operation)
	for i := 0; i < len(args); i += 1 {
		buf: [4]byte
		old := fmt.bprintf(buf[:], "$%i", i + 1)
		buf2: [16]byte
		new := fmt.bprintf(buf2[:], "%.15g", args[i])
		old_operation := operation
		operation, _ = strings.replace_all(operation, old, new)
		delete(old_operation)
	}


	all: bool
	old_op := operation
	operation, all = strings.replace_all(operation, " ", "")
	if all {
		delete(old_op)
	}
	r, ok := solve_no_iter(operation, cur_depth + 1, max_depth, customs, debug)
	delete(operation)

	result, ok = strconv.parse_f64(r)

	if ok {
		buf: [16]byte
		return result, true
	}
	return 0, false
}

func_vec_len :: proc(values: []f64) -> f64 {
	result := values[0]

	for i := 1; i < len(values); i += 1 {
		result = math.sqrt(math.pow_f64(result, 2) + math.pow_f64(values[i], 2))
	}

	return result
}

func_round :: proc(value: f64, zeros: f64) -> f64 {
	zeros := math.floor_f64(zeros)
	mult := math.pow_f64(10, zeros)
	v := math.round_f64(value * mult) / mult
	return v
}

func_elim :: proc(value, min, max: f64) -> (result: f64, ok: bool) {
	if value <= max && value >= min {
		return value, true
	}
	return 0, false
}

func_emin :: proc(value, min: f64) -> (result: f64, ok: bool) {
	if value >= min {
		return value, true
	}
	return 0, false
}

func_emax :: proc(value, max: f64) -> (result: f64, ok: bool) {
	if value <= max {
		return value, true
	}
	return 0, false
}

calculate_functons :: proc(
	content: string,
	cur_depth, max_depth: i32,
	customs: ^CustomData,
	debug: bool,
) -> (
	result: string,
	succes: bool,
) {
	if cur_depth > max_depth && max_depth != -1 {
		return strings.clone(content), false
	}

	functions := [dynamic]FuncData{}
	defer delete(functions)
	find_all_functions(content, customs, &functions)


	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	offset := 0

	content_len := len(content)

	succes = true

	for data in functions {

		strings.write_string(&b, content[offset:data.pos])

		params_start := data.pos + len(data.func) + 1
		if params_start >= content_len {
			return strings.clone(content), false
		}

		params_end := strings.index_rune(content[params_start:], ')')
		if params_end == -1 {
			return strings.clone(content), false
		}

		params_end += params_start

		if params_end >= content_len {
			return strings.clone(content), false
		}

		params := [dynamic]f64{}
		defer delete(params)

		str_params := content[params_start:params_end]
		str_params_arr, _ := strings.split(str_params, ",")
		defer delete(str_params_arr)
		for param in str_params_arr {
			f_param, ok := strconv.parse_f64(param)
			if ok {
				append(&params, f_param)
			} else {
				return strings.clone(content), false
			}
		}

		result, ok := func_wrap(data.func, params[:], cur_depth, max_depth, customs, debug)

		if ok {
			fmt.sbprintf(&b, "%.15g", result)
		} else {
			strings.write_string(&b, content[data.pos:params_end + 1])
			succes = false
		}

		offset = (params_end + 1)
	}
	strings.write_string(&b, content[offset:])

	return strings.clone(strings.to_string(b)), succes
}
