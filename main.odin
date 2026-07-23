#+feature dynamic-literals
package calc

import "core:encoding/ini"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

EditMode :: enum {
	Append,
	Replace,
}

print_help :: proc() {
	print_arr := []string {
		"Usage: {exec} [options]",
		"",
		"Options:",
		"-h, --help                     Prints this message",
		"-d, --debug                    Prints debug messages",
		"-H, --headless \"<func>\"	       Runs program in headless mode",
		"-p, --path						Prints filepath, that is expected for configuration"
	}

	for line in print_arr {
		fmt.println(line)
	}
}

print_path :: proc(){
	conf_file, conf_ok := get_config_file_path("calc.ini")
	customs_file, ok := get_config_file_path("customs.json")
	fmt.println("Config file:", conf_file)
	fmt.println("Customs file:", customs_file)
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	args := os.args

	headless := false
	h_func := ""
	debug := false

	for cur_arg := 1; cur_arg < len(args); cur_arg += 1 {
		arg := args[cur_arg]

		switch arg {
		case "-h", "--help":
			print_help()
			return
		case "-p", "--path":
			print_path()
			return
		case "-d", "--debug":
			debug = true
		case "-H", "--headless":
			headless = true
			if cur_arg + 1 < len(args) {
				h_func = args[cur_arg + 1]
				cur_arg += 1
			} else {
				fmt.println("function for headless mode was not provided")
				fmt.println("Example usage: calc -h \"2+2\"")
				return
			}
				case:
			fmt.printfln("Option %s is not supported", arg)
		}
	}

	c: Config = Config {
		30,
		800,
		200,
		40,
		20,
		0.45,
		0.05,
		0.33,
		{0, 0, 0, 255},
		{255, 255, 255, 255},
		{0, 0, 0, 255},
		{255, 255, 255, 255},
		100
	}

	conf_file, conf_ok := get_config_file_path("calc.ini")
	if conf_ok {
		config_map, map_err, map_ok := ini.load_map_from_path(conf_file, context.temp_allocator)
		defer delete(config_map)
		if map_ok {
			update_config(&config_map, &c)
		}
		delete(conf_file)
	}

	customs: CustomData
	customs_file, ok := get_config_file_path("customs.json")
	if ok{
		load_custom_functions(customs_file, &customs)
		delete(customs_file)
	}
	defer delete_customs(&customs)

	if headless {
		run_headless(h_func, &customs, &c, debug)
	} else {
		run_gui(&customs, &c, debug)
	}

	free_all(context.temp_allocator)
}

run_headless :: proc(func: string, customs: ^CustomData, config: ^Config, debug: bool) {
	f_clone := strings.clone(func)
	result, ok, all := solve(f_clone, config.max_depth, customs, debug)
	if !all{
		delete(f_clone)
	}

	//defer delete(result)
	if ok {
		fmt.println(strip_zeros(result))
	} else {
		fmt.println("Failed to solve equasion")
		fmt.println("Try using --debug to check what failed")
	}
}

run_gui :: proc(customs: ^CustomData, config: ^Config, debug: bool) {
	// Default config

	result: string

	measured_text: string

	ok: bool = false

	cur_func := [dynamic]u8{0}
	defer delete(cur_func)
	parsed_func: string
	cursor := 0

	exitWindowRequested: bool = false
	exitWindow: bool = false

	is_backspace_pressed: bool = false
	backspace_timer: f32 = 0.0

	edit_mode := EditMode.Append

	blink_counter := 0

	blink_frames := int(f32(config.fps) * config.blink_time)
	blink_cycle := blink_frames * 2


	text_box := rl.Rectangle{20, 20, f32(config.width) - 40, f32(config.func_font_size) + 10}

	rl.SetTraceLogLevel(.ERROR)
	rl.InitWindow(config.width, config.height, "calc")
	rl.SetExitKey(.ESCAPE)

	rl.SetTargetFPS(config.fps)
	for (!exitWindow) {

		delta := rl.GetFrameTime()
		blink_counter = (blink_counter + 1) % blink_cycle

		if rl.WindowShouldClose() {
			exitWindow = true
		}

		if rl.IsKeyPressed(.INSERT) {
			switch edit_mode {
			case .Append:
				edit_mode = .Replace
			case .Replace:
				edit_mode = .Append
			}
		}

		if rl.IsKeyPressed(.LEFT) {
			cursor = math.clamp(cursor - 1, 0, len(cur_func) - 1)
			measured_text = parsed_func[0:cursor]
		}
		if rl.IsKeyPressed(.RIGHT) {
			cursor = math.clamp(cursor + 1, 0, len(cur_func) - 1)
			measured_text = parsed_func[0:cursor]
		}
		char: rune = rl.GetCharPressed()

		if char > 0 {
			for char > 0 {
				if char >= 32 && char <= 125 {
					switch edit_mode {
					case .Append:
						inject_at(&cur_func, cursor, u8(char))
					case .Replace:
						if cursor == len(cur_func) - 1 {
							inject_at(&cur_func, cursor, u8(char))
						} else {
							cur_func[cursor] = u8(char)
						}
					}

					cursor += 1
				}
				char = rl.GetCharPressed()
			}

			parsed_func = transmute(string)cur_func[:len(cur_func) - 1]

			f_clone := strings.clone(parsed_func)
			all: bool
			
			result, ok, all = solve(f_clone, config.max_depth, customs, debug)

			//fmt.println(result)
			if ok {
				result = strip_zeros(result)
			}
			measured_text = parsed_func[0:cursor]

			if !all {
				delete(f_clone)
			}

			//fmt.println(result)
		}

		if rl.IsKeyDown(.BACKSPACE) {
			backspace_timer += delta

			allow_use: bool = !is_backspace_pressed
			if backspace_timer > (config.key_wait_time + config.key_repeat_time) {
				backspace_timer -= config.key_repeat_time
				allow_use = true
			}

			if allow_use {
				is_backspace_pressed = true
				if len(cur_func) > 1 && cursor > 0 {
					ordered_remove(&cur_func, cursor - 1)
					cursor -= 1

					parsed_func = transmute(string)cur_func[:len(cur_func) - 1]

					f_clone := strings.clone(parsed_func)
					all: bool

					result, ok, all = solve(f_clone, config.max_depth, customs, debug)
					if ok {
						result = strip_zeros(result)
					}
					measured_text = parsed_func[0:cursor]

					if !all {
						delete(f_clone)
					}
					//fmt.println(result)
				}
			}
		} else if rl.IsKeyReleased(.BACKSPACE) && is_backspace_pressed {
			backspace_timer = 0.0
			is_backspace_pressed = false
		}

		if rl.IsKeyPressed(.ENTER) {
			if ok {
				fmt.print(result)

				exitWindow = true
			}
		}

		// Draw

		rl.BeginDrawing()
		rl.ClearBackground(config.background_color)

		rl.DrawRectangleRec(text_box, config.input_color)
		rl.DrawText(
			cstring(raw_data(cur_func)),
			i32(text_box.x) + 5,
			i32(text_box.y) + 8,
			config.func_font_size,
			config.func_color,
		)

		// Draw blinking pointer
		if blink_counter < blink_frames {
			cstr_measured: cstring = strings.clone_to_cstring(measured_text)
			defer delete(cstr_measured)
			offset_x := rl.MeasureText(cstr_measured, config.func_font_size)

			if cursor == 0 {
				offset_x -= 4
			}

			cursor_rect: rl.Rectangle

			switch edit_mode {
			case .Append:
				if cursor < len(parsed_func) {
					cursor_rect = rl.Rectangle {
						text_box.x + f32(offset_x) + 6,
						text_box.y + (text_box.height * 0.1),
						2,
						text_box.height - (text_box.height * 0.2),
					}
				} else {
					cursor_rect = rl.Rectangle {
						text_box.x + f32(offset_x) + 7,
						text_box.y + text_box.height - (text_box.height * 0.2),
						f32(config.func_font_size) / 2,
						2,
					}
				}
			case .Replace:
				if cursor < len(parsed_func) {
					current_char := parsed_func[cursor:cursor + 1]
					str_char := string(current_char)
					measured_char := strings.clone_to_cstring(str_char)

					cursor_rect = rl.Rectangle {
						text_box.x + f32(offset_x) + 7,
						text_box.y + text_box.height - (text_box.height * 0.2),
						f32(rl.MeasureText(measured_char, config.func_font_size)) + 4,
						2,
					}
				} else {
					cursor_rect = rl.Rectangle {
						text_box.x + f32(offset_x) + 7,
						text_box.y + text_box.height - (text_box.height * 0.2),
						f32(config.func_font_size) / 2,
						2,
					}
				}
			}

			rl.DrawRectangleRec(cursor_rect, config.func_color)
		}

		if ok {
			cresult: cstring = strings.clone_to_cstring(result)
			defer delete(cresult)
			rl.DrawText(
				cresult,
				i32(text_box.x),
				i32(text_box.y + text_box.height) + 20,
				config.result_font_size,
				config.result_color,
			)
		}

		rl.EndDrawing()

	}
	rl.CloseWindow()
}

is_any_key_pressed :: proc() -> bool {
	key := int(rl.GetKeyPressed())

	return key >= 32 && key <= 126
}
