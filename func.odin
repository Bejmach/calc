#+feature dynamic-literals
package calc

import "core:slice"
import "core:fmt"
import "core:math"
import "core:strconv"
import "core:strings"

void :: struct {}

function :: struct {
	name: string,
	args: int,
}

func_arr := []string{
	"sqrt",
	"pow",
	"round",
	"sin",
	"sen", // "sin" alias to allow for writing of sen(PI)
	"cos",
	"cou", // "cos" alias to allow for writing of cou(HI)
	"tan",
	"vecLen"
}

func_wrap :: proc(name: string, args: []f64) -> (result: f64, succes: bool) {
	switch name {
	case "sqrt":
		if len(args) == 1 {
			return math.sqrt_f64(args[0]), true
		}
	case "pow":
		if len(args) == 2 {
			return math.pow_f64(args[0], args[1]), true
		}
	case "round":
		if len(args) == 2 {
			return func_round(args[0], args[1]), true
		}
	case "sin", "sen":
		if len(args) == 1 {
			return math.sin_f64(args[0]), true
		}
	case "cos", "cou":
		if len(args) == 1 {
			return math.cos_f64(args[0]), true
		}
	case "tan":
		if len(args) == 1 {
			return math.tan_f64(args[0]), true
		}
	case "vecLen":
		if len(args) > 0{
			return func_vec_len(args), true
		}
	}


	return 0, false
}

func_vec_len :: proc(values: []f64) -> f64{
	result := values[0]

	for i := 1; i<len(values); i+=1{
		result = math.sqrt( math.pow_f64(result, 2) + math.pow_f64(values[i], 2) )
	}

	return result
}

func_round :: proc(value: f64, zeros: f64) -> f64 {
	zeros := math.floor_f64(zeros)
	mult := math.pow_f64(10, zeros)
	v := math.round_f64(value * mult) / mult
	return v
}

calculate_functons :: proc(content: string) -> (result: string, succes: bool) {
	new_content := content
	for func in func_arr {
		//fmt.println(new_content, func)

		offset := 0
		id := strings.index(new_content[offset:], func)
		for id != -1 {
			//fmt.println(id, func)
			content_len := len(new_content)

			params := [dynamic]f64{}
			defer delete(params)

			params_start := id + len(func) + 1
			if params_start >= content_len {
				return content, false
			}

			params_end := strings.index_rune(new_content[params_start:], ')')
			if params_end == -1 {
				return content, false
			}

			params_end += params_start

			if params_end >= content_len {
				return content, false
			}

			//fmt.println(params_start, params_end)

			str_params := new_content[params_start:params_end]
			str_params_arr, _ := strings.split(str_params, ",")
			for param in str_params_arr {
				f_param, ok := strconv.parse_f64(param)
				if ok {
					append(&params, f_param)
				} else {
					return content, false
				}
			}

			result, ok := func_wrap(func, params[:])
			//fmt.println(ok)
			if ok {
				builder := strings.builder_make()
				strings.write_string(&builder, new_content[:id])
				fmt.sbprintf(&builder, "%.15g", result)
				if params_end + 2 < content_len {
					strings.write_string(&builder, new_content[params_end + 1:])
				}
				new_content = strings.to_string(builder)
				//fmt.println(new_content)
			} else{
				offset += (params_end - id + 1)
			}

			id = strings.index(new_content[offset:], func)
		}
	}

	return new_content, true
}
