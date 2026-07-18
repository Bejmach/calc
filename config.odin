package calc

import "core:encoding/ini"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import "core:strings"

import rl "vendor:raylib"

Config :: struct {
	fps:                                                     i32,
	width, height:                                           i32,
	func_font_size, result_font_size:                        i32,
	key_wait_time, key_repeat_time:                          f32,
	blink_time:                                              f32,
	background_color, input_color, func_color, result_color: rl.Color,
	max_depth:                                               i32,
}

get_config_file_path :: proc(file: string) -> (path: string, ok: bool) {
	config_dir, dir_err := os.user_config_dir(context.temp_allocator)
	if dir_err != nil {
		return "", false
	}

	b := strings.builder_make()
	defer strings.builder_destroy(&b)
	strings.write_string(&b, config_dir)
	strings.write_string(&b, "/calc/")
	strings.write_string(&b, file)
	path = strings.clone(strings.to_string(b))
	return path, true
}

load_custom_functions :: proc(path: string, e: ^CustomData) -> bool {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return false
	}
	defer delete(data)

	err2 := json.unmarshal(data, e)
	if err2 != nil {
		return false
	}

	return false
}

delete_customs :: proc(e: ^CustomData) {
	for key, value in e.functions {
		delete(key) // free the key string
		delete(value.operation) // free the operation string
	}
	for key, value in e.consts {
		delete(key)
		delete(value)
	}

	delete(e.functions)
	delete(e.consts)
}

update_config :: proc(conf_map: ^ini.Map, conf: ^Config) {
	// Window
	parse_i32(conf_map, "Window", "fps", &conf.fps)
	parse_i32(conf_map, "Window", "width", &conf.width)
	parse_i32(conf_map, "Window", "height", &conf.height)

	// Usage
	parse_f32(conf_map, "Usage", "key_wait_time", &conf.key_wait_time)
	parse_f32(conf_map, "Usage", "key_repeat_time", &conf.key_repeat_time)

	// Theme
	parse_i32(conf_map, "Theme", "func_font_size", &conf.func_font_size)
	parse_i32(conf_map, "Theme", "result_font_size", &conf.result_font_size)
	parse_f32(conf_map, "Theme", "blink_time", &conf.blink_time)

	parse_color(conf_map, "Theme", "background_color", &conf.background_color)
	parse_color(conf_map, "Theme", "input_color", &conf.input_color)
	parse_color(conf_map, "Theme", "func_color", &conf.func_color)
	parse_color(conf_map, "Theme", "result_color", &conf.result_color)
}

parse_i32 :: proc(conf_map: ^ini.Map, section, key: string, dst: ^i32) {
	if value, ok := conf_map[section][key]; ok {
		if parsed, ok := strconv.parse_int(value); ok {
			dst^ = i32(parsed)
		}
	}
}

parse_f32 :: proc(conf_map: ^ini.Map, section, key: string, dst: ^f32) {
	if value, ok := conf_map[section][key]; ok {
		if parsed, ok := strconv.parse_f32(value); ok {
			dst^ = parsed
		}
	}
}

parse_int :: proc(conf_map: ^ini.Map, section, key: string, dst: ^int) {
	if value, ok := conf_map[section][key]; ok {
		if parsed, ok := strconv.parse_int(value); ok {
			dst^ = parsed
		}
	}
}

parse_color :: proc(conf_map: ^ini.Map, section, key: string, dst: ^rl.Color) {
	if value, ok := conf_map[section][key]; ok {

		split := strings.split(value, ",")
		defer delete(split)

		r, g, b, a := u8(255), u8(255), u8(255), u8(255)

		if len(split) > 0 {
			if v, ok := strconv.parse_int(strings.trim_space(split[0])); ok {
				r = u8(v)
			}
		}
		if len(split) > 1 {
			if v, ok := strconv.parse_int(strings.trim_space(split[1])); ok {
				g = u8(v)
			}
		}
		if len(split) > 2 {
			if v, ok := strconv.parse_int(strings.trim_space(split[2])); ok {
				b = u8(v)
			}
		}
		if len(split) > 3 {
			if v, ok := strconv.parse_int(strings.trim_space(split[3])); ok {
				a = u8(v)
			}
		}

		dst^ = rl.Color{r, g, b, a}
	}
}
