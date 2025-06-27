package main

import "core:encoding/base64"
import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:slice"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

/*
NOTE:Issue with the way raylib does scissoring. Means having one scroll-area within another is impossible. Currently working around by disabling the outer scroll area when then inner one is activated.
TODO:Set dropdown box max size such that elements aren't drawn outside of scroll area.
*/

GuiControl :: struct {
	id:      i32,
	hovered: bool,
}

HoverStack :: struct {
	stack: [dynamic]^GuiControl,
	count: i32,
}

hover_stack_add :: proc(gui_control: ^GuiControl) {
	already_added: bool

	if state.hover_stack.count == 0 {
		for item in state.hover_stack.stack {
			if item.id == gui_control.id {
				already_added = true
			}
		}
	} else {
		for item, i in state.hover_stack.stack {
			if item.id == gui_control.id {
				ordered_remove(&state.hover_stack.stack, i)
			}
		}
	}
	if !already_added {
		append(&state.hover_stack.stack, gui_control)
		state.hover_stack.count += 1
	}
}

is_current_hover :: proc(gui_control: GuiControl) -> bool {
	if len(state.hover_stack.stack) > 0 && state.gui_enabled {
		if state.hover_stack.stack[len(state.hover_stack.stack) - 1].id == gui_control.id {
			return true
		}
	}
	return false
}

clean_hover_stack :: proc() {
	for item, i in state.hover_stack.stack {
		if item.hovered == false {
			ordered_remove(&state.hover_stack.stack, i)
		}
	}
	state.hover_stack.count = 0
}

clear_hover_stack :: proc() {
	clear(&state.hover_stack.stack)
	state.hover_stack.count = 0
}

GuiLabel :: proc(bounds: rl.Rectangle, text: cstring) {
	initial_text_size := state.gui_properties.TEXT_SIZE
	label_string: cstring
	if text != "" {
		if string(text)[0] != '#' {
			if !fit_text(text, bounds.width, .DEFAULT, &state.gui_properties.TEXT_SIZE) {
				label_string = crop_text(text, bounds.width, state.gui_properties.TEXT_SIZE)
			} else {
				label_string = text
			}
		} else {
			label_string = text
		}
	}
	rl.GuiLabel(bounds, label_string)
	state.gui_properties.TEXT_SIZE = initial_text_size
	set_text_size(state.gui_properties.TEXT_SIZE)
}

ButtonState :: struct {
	using gui_control: GuiControl,
}

init_button_state :: proc(button_state: ^ButtonState) {
	button_state.id = GUI_ID

	GUI_ID += 1
}

GuiButton :: proc {
	GuiButtonWithState,
	GuiButtonStateless,
}

GuiButtonWithState :: proc(
	bounds: rl.Rectangle,
	button_state: ^ButtonState,
	text: cstring,
	icon: rl.GuiIconName = rl.GuiIconName.ICON_NONE,
) -> bool {
	using state.gui_properties

	initial_alignment := rl.GuiGetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT)
	defer {
		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT,
			cast(i32)initial_alignment,
		)
	}

	border: f32 : 2

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{
			bounds.x + border,
			bounds.y + border,
			bounds.width - (border * 2),
			bounds.height - (border * 2),
		},
		BUTTON_COLOUR,
	)
	text_align_center()
	if icon != rl.GuiIconName.ICON_NONE {
		initial_text_colour := rl.GuiGetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL,
		)
		rl.GuiDrawIcon(
			icon,
			cast(i32)(bounds.x),
			cast(i32)(bounds.y),
			cast(i32)(bounds.height / 16),
			BUTTON_BORDER_COLOUR,
		)
		rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL, 0x000000FF)
		GuiLabel(
			{
				bounds.x + border,
				bounds.y + border,
				bounds.width - (border * 2),
				bounds.height - (border * 2),
			},
			text,
		)

		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL,
			initial_text_colour,
		)
	} else {
		GuiLabel(
			{
				bounds.x + border,
				bounds.y + border,
				bounds.width - (border * 2),
				bounds.height - (border * 2),
			},
			text,
		)
	}

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		button_state.hovered = true
		hover_stack_add(button_state)
	} else {
		button_state.hovered = false
	}

	if is_current_hover(button_state) && rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)

		if rl.IsMouseButtonReleased(.LEFT) {
			button_state.hovered = false
			return true
		}
	}
	return false
}

GuiButtonStateless :: proc(
	bounds: rl.Rectangle,
	text: cstring,
	icon: rl.GuiIconName = rl.GuiIconName.ICON_NONE,
) -> bool {
	using state.gui_properties

	initial_alignment := rl.GuiGetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT)
	defer {
		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT,
			cast(i32)initial_alignment,
		)
	}

	border: f32 : 2

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{
			bounds.x + border,
			bounds.y + border,
			bounds.width - (border * 2),
			bounds.height - (border * 2),
		},
		BUTTON_COLOUR,
	)
	text_align_center()

	if icon != rl.GuiIconName.ICON_NONE {
		initial_text_colour := rl.GuiGetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL,
		)
		rl.GuiDrawIcon(
			icon,
			cast(i32)(bounds.x),
			cast(i32)(bounds.y),
			cast(i32)(bounds.height / 16),
			BUTTON_BORDER_COLOUR,
		)
		rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL, 0x000000FF)
		GuiLabel(
			{
				bounds.x + border,
				bounds.y + border,
				bounds.width - (border * 2),
				bounds.height - (border * 2),
			},
			text,
		)
		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiControlProperty.TEXT_COLOR_NORMAL,
			initial_text_colour,
		)
	} else {
		GuiLabel(
			{
				bounds.x + border,
				bounds.y + border,
				bounds.width - (border * 2),
				bounds.height - (border * 2),
			},
			text,
		)
	}

	if len(state.hover_stack.stack) == 0 && state.gui_enabled {
		if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
			rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)

			if rl.IsMouseButtonReleased(.LEFT) {
				return true
			}
		}
	}
	return false
}

TextInputState :: struct {
	using gui_control: GuiControl,
	edit_mode:         bool,
	loaded:            bool,
	delete_mode_count: int,
	left_mode_count:   int,
	right_mode_count:  int,
	builder:           strings.Builder,
	text:              cstring,
	edit_text:         string,
	start_idx:         int,
	end_idx:           int,
	cursor_idx:        int,
	cursor_pos:        f32,
}

init_text_input_state :: proc(input_state: ^TextInputState) {
	input_state.id = GUI_ID
	input_state.builder = strings.builder_make()

	GUI_ID += 1
}

clear_text_input :: proc(input_state: ^TextInputState) {
	strings.builder_reset(&input_state.builder)
	input_state.text = strings.to_cstring(&input_state.builder)
	input_state.edit_text = ""
	input_state.start_idx = 0
	input_state.end_idx = 0
	input_state.cursor_idx = 0
	input_state.cursor_pos = 0
}

set_text_input :: proc(input_state: ^TextInputState, text: cstring, width: f32) {
	clear(&input_state.builder.buf)
	for char in string(text) {
		append(&input_state.builder.buf, byte(char))
	}
	input_state.text = strings.to_cstring(&input_state.builder)

	input_state.start_idx = 0
	input_state.end_idx = len(string(input_state.text))

	for rl.MeasureText(
		    cstr(string(input_state.text)[input_state.start_idx:input_state.end_idx]),
		    25,
	    ) >=
	    cast(i32)width {
		input_state.end_idx -= 1
	}
	input_state.edit_text = string(input_state.text)[input_state.start_idx:input_state.end_idx]
}

GuiTextInput :: proc(bounds: rl.Rectangle, input_state: ^TextInputState) {
	using state.gui_properties

	border: f32 : 2
	SPACING: f32 : 2.4

	x := bounds.x + border
	y := bounds.y + border
	width := bounds.width - (border * 2)
	height := bounds.height - (border * 2)

	initial_text_spacing := rl.GuiGetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SPACING)
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SPACING, 2)
	initial_text_size := TEXT_SIZE

	text_align_left()

	defer {
		rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SPACING, initial_text_spacing)
		set_text_size(TEXT_SIZE_DEFAULT)
		text_align_center()
	}

	set_text_size(25)

	rl.DrawRectangleRec(
		{x - border, y - border, width + (border * 2), height + (border * 2)},
		BUTTON_BORDER_COLOUR if !input_state.edit_mode else BUTTON_ACTIVE_COLOUR,
	)
	rl.DrawRectangleRec({x, y, width, height}, BACKGROUND_COLOUR)

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		input_state.hovered = true
		hover_stack_add(input_state)
	} else {
		input_state.hovered = false
	}

	if input_state.edit_mode {
		char: rune

		char = rl.GetCharPressed()
		for int(char) != 0 {
			switch char {
			case 'A' ..= 'Z', 'a' ..= 'z', '0' ..= '9':
				inject_at(&input_state.builder.buf, input_state.cursor_idx, byte(char))
				input_state.text = strings.to_cstring(&input_state.builder)
				input_state.cursor_idx += 1
				input_state.end_idx += 1

				if rl.MeasureText(input_state.text, TEXT_SIZE) < cast(i32)width {
					input_state.cursor_pos +=
						cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE) + SPACING
				} else {
					input_state.edit_text =
					string(input_state.text)[input_state.start_idx:input_state.end_idx]

					if rl.MeasureText(cstr(input_state.edit_text), TEXT_SIZE) < cast(i32)width {
						input_state.cursor_pos +=
							cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE) + SPACING
					} else {
						input_state.start_idx += 1
						input_state.cursor_pos -=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.start_idx - 1]),
							TEXT_SIZE,
						)
						input_state.cursor_pos += cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE)
						input_state.edit_text =
						string(input_state.text)[input_state.start_idx:input_state.end_idx]
					}
				}
			case '_', '-', '/', '\\', '.', ',', '!', '@', ' ':
				inject_at(&input_state.builder.buf, input_state.cursor_idx, byte(char))
				input_state.text = strings.to_cstring(&input_state.builder)
				input_state.cursor_idx += 1
				input_state.end_idx += 1

				if rl.MeasureText(input_state.text, TEXT_SIZE) < cast(i32)width {
					input_state.cursor_pos +=
						cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE) + SPACING
				} else {
					input_state.edit_text =
					string(input_state.text)[input_state.start_idx:input_state.end_idx]

					if rl.MeasureText(cstr(input_state.edit_text), TEXT_SIZE) < cast(i32)width {
						input_state.cursor_pos +=
							cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE) + SPACING
					} else {
						input_state.start_idx += 1
						input_state.cursor_pos -=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.start_idx - 1]),
							TEXT_SIZE,
						)
						input_state.cursor_pos += cast(f32)rl.MeasureText(cstr(char), TEXT_SIZE)
						input_state.edit_text =
						string(input_state.text)[input_state.start_idx:input_state.end_idx]
					}
				}
			}
			char = rl.GetCharPressed()
		}

		if rl.IsKeyPressed(.BACKSPACE) {
			if input_state.text != "" && input_state.cursor_idx > 0 {
				popped_rune := rune(input_state.builder.buf[input_state.cursor_idx - 1])
				ordered_remove(&input_state.builder.buf, input_state.cursor_idx - 1)
				input_state.cursor_idx -= 1
				input_state.end_idx -= 1
				input_state.cursor_pos -=
					cast(f32)rl.MeasureText(cstr(popped_rune), TEXT_SIZE) + SPACING

				if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
				   input_state.start_idx > 0 {
					input_state.start_idx -= 1
					input_state.cursor_pos +=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.start_idx]),
							TEXT_SIZE,
						) +
						SPACING
					input_state.edit_text =
					string(input_state.text)[input_state.start_idx:input_state.end_idx]
				}
				input_state.text = strings.to_cstring(&input_state.builder)
			}
		}

		if rl.IsKeyDown(.BACKSPACE) {
			input_state.delete_mode_count += 1
		} else if rl.IsKeyReleased(.BACKSPACE) {
			input_state.delete_mode_count = 0
		}

		if input_state.delete_mode_count >= 30 {
			if input_state.text != "" {
				if (FRAME % 5 == 0) && input_state.cursor_idx > 0 {
					popped_rune := rune(input_state.builder.buf[input_state.cursor_idx - 1])
					ordered_remove(&input_state.builder.buf, input_state.cursor_idx - 1)
					input_state.cursor_idx -= 1
					input_state.end_idx -= 1
					input_state.cursor_pos -=
						cast(f32)rl.MeasureText(cstr(popped_rune), TEXT_SIZE) + SPACING

					if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
					   input_state.start_idx > 0 {
						input_state.start_idx -= 1
						input_state.cursor_pos +=
							cast(f32)rl.MeasureText(
								cstr(cast(rune)string(input_state.text)[input_state.start_idx]),
								TEXT_SIZE,
							) +
							SPACING
						input_state.edit_text =
						string(input_state.text)[input_state.start_idx:input_state.end_idx]
					}
					input_state.text = strings.to_cstring(&input_state.builder)
				}
			}
			if rl.IsKeyReleased(.BACKSPACE) {
				input_state.delete_mode_count = 0
			}
		}

		if rl.IsKeyPressed(.LEFT) {
			if input_state.text != "" && input_state.cursor_idx > 0 {
				input_state.cursor_idx -= 1
				input_state.cursor_pos -=
					cast(f32)rl.MeasureText(
						cstr(cast(rune)string(input_state.text)[input_state.cursor_idx]),
						TEXT_SIZE,
					) +
					SPACING

				if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
				   input_state.start_idx > 0 {
					input_state.start_idx -= 1
					input_state.end_idx -= 1
					input_state.cursor_pos +=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.start_idx]),
							TEXT_SIZE,
						) +
						SPACING
					input_state.edit_text =
					string(input_state.text)[input_state.start_idx:input_state.end_idx]
				}
			}
		}

		if rl.IsKeyDown(.LEFT) {
			input_state.left_mode_count += 1
		} else if rl.IsKeyReleased(.LEFT) {
			input_state.left_mode_count = 0
		}

		if input_state.left_mode_count >= 30 {
			if input_state.text != "" && input_state.cursor_idx > 0 {
				if (FRAME % 5 == 0) {
					input_state.cursor_idx -= 1
					input_state.cursor_pos -=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.cursor_idx]),
							TEXT_SIZE,
						) +
						SPACING

					if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
					   input_state.start_idx > 0 {
						input_state.start_idx -= 1
						input_state.end_idx -= 1
						input_state.cursor_pos +=
							cast(f32)rl.MeasureText(
								cstr(cast(rune)string(input_state.text)[input_state.start_idx]),
								TEXT_SIZE,
							) +
							SPACING
						input_state.edit_text =
						string(input_state.text)[input_state.start_idx:input_state.end_idx]
					}
				}
			}
			if rl.IsKeyReleased(.LEFT) {
				input_state.left_mode_count = 0
			}
		}

		if rl.IsKeyPressed(.RIGHT) {
			if input_state.text != "" && input_state.cursor_idx < len(string(input_state.text)) {
				input_state.cursor_idx += 1
				input_state.cursor_pos +=
					cast(f32)rl.MeasureText(
						cstr(cast(rune)string(input_state.text)[input_state.cursor_idx - 1]),
						TEXT_SIZE,
					) +
					SPACING

				if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
				   input_state.end_idx < input_state.cursor_idx {
					input_state.end_idx += 1
				}
				if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
				   input_state.cursor_pos > width {
					input_state.start_idx += 1
					input_state.cursor_pos -=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.start_idx - 1]),
							TEXT_SIZE,
						) +
						SPACING
					input_state.edit_text =
					string(input_state.text)[input_state.start_idx:input_state.end_idx]
				}
			}
		}

		if rl.IsKeyDown(.RIGHT) {
			input_state.right_mode_count += 1
		} else if rl.IsKeyReleased(.RIGHT) {
			input_state.right_mode_count = 0
		}

		if input_state.right_mode_count >= 30 {
			if input_state.text != "" && input_state.cursor_idx < len(string(input_state.text)) {
				if (FRAME % 5 == 0) {
					input_state.cursor_idx += 1
					input_state.cursor_pos +=
						cast(f32)rl.MeasureText(
							cstr(cast(rune)string(input_state.text)[input_state.cursor_idx - 1]),
							TEXT_SIZE,
						) +
						SPACING

					if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
					   input_state.end_idx < input_state.cursor_idx {
						input_state.end_idx += 1
					}

					if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width &&
					   input_state.cursor_pos > width {
						input_state.start_idx += 1
						input_state.cursor_pos -=
							cast(f32)rl.MeasureText(
								cstr(
									cast(rune)string(input_state.text)[input_state.start_idx - 1],
								),
								TEXT_SIZE,
							) +
							SPACING
						input_state.edit_text =
						string(input_state.text)[input_state.start_idx:input_state.end_idx]
					}
				}
			}
			if rl.IsKeyReleased(.RIGHT) {
				input_state.right_mode_count += 1
			}
		}

		for input_state.cursor_pos > width {
			input_state.start_idx += 1
			input_state.cursor_pos -=
				cast(f32)rl.MeasureText(
					cstr(cast(rune)string(input_state.text)[input_state.start_idx - 1]),
					TEXT_SIZE,
				) +
				SPACING
			input_state.edit_text =
			string(input_state.text)[input_state.start_idx:input_state.end_idx]
		}

		rl.DrawLine(
			cast(i32)(x + input_state.cursor_pos),
			cast(i32)y,
			cast(i32)(x + input_state.cursor_pos),
			cast(i32)(y + height),
			BUTTON_BORDER_COLOUR,
		)

		if rl.IsKeyPressed(.ENTER) {
			input_state.edit_mode = false
		}

		if rl.MeasureText(input_state.text, TEXT_SIZE) > cast(i32)width {
			GuiLabel({x, y, width, height}, cstr(input_state.edit_text))
		} else {
			GuiLabel({x, y, width, height}, input_state.text)
		}
	} else {
		GuiLabel({x, y, width, height}, input_state.text)
	}

	if is_current_hover(input_state) {
		rl.DrawRectangleRec({x, y, width, height}, BUTTON_HOVER_COLOUR)
		if rl.IsMouseButtonReleased(.LEFT) {
			input_state.edit_mode = true
		}
	} else {
		if rl.IsMouseButtonReleased(.LEFT) {
			input_state.edit_mode = false
		}
	}
}

ToggleState :: struct {
	using gui_control: GuiControl,
	text:              cstring,
	toggle:            ^bool,
}

init_toggle_state :: proc(toggle_state: ^ToggleState, text: cstring, toggle: ^bool) {
	toggle_state.id = GUI_ID
	toggle_state.text = text
	toggle_state.toggle = toggle

	GUI_ID += 1
}

GuiToggle :: proc(bounds: rl.Rectangle, toggle_state: ^ToggleState) -> bool {
	using state.gui_properties

	initial_alignment := rl.GuiGetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT)

	defer {
		rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, initial_alignment)
	}

	border :: 2

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{
			bounds.x + border,
			bounds.y + border,
			bounds.width - (border * 2),
			bounds.height - (border * 2),
		},
		BUTTON_COLOUR,
	)
	text_align_center()
	GuiLabel(bounds, toggle_state.text)

	if toggle_state.toggle^ {
		rl.DrawRectangleRec(bounds, BUTTON_ACTIVE_COLOUR)
	}

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		toggle_state.hovered = true
		hover_stack_add(toggle_state)
	} else {
		toggle_state.hovered = false
	}

	if is_current_hover(toggle_state) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
		if rl.IsMouseButtonReleased(.LEFT) {
			toggle_state.toggle^ = !toggle_state.toggle^
			return true
		}
	}
	return false
}

ToggleSliderState :: struct {
	using gui_control: GuiControl,
	options:           []cstring,
	selected:          int,
}

init_toggle_slider_state :: proc(slider_state: ^ToggleSliderState, options: []cstring) {
	slider_state.id = GUI_ID
	slider_state.options = options

	GUI_ID += 1
}

GuiToggleSlider :: proc(bounds: rl.Rectangle, slider_state: ^ToggleSliderState) -> int {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	border: f32 : 2

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{x + border, y + border, width - (border * 2), height - (border * 2)},
		BUTTON_COLOUR,
	)

	option_bounds := rl.Rectangle {
		x + cast(f32)(slider_state.selected * (cast(int)width / len(slider_state.options))),
		y,
		cast(f32)(cast(int)width / len(slider_state.options)),
		height,
	}

	rl.DrawRectangleRec(option_bounds, BUTTON_ACTIVE_COLOUR)

	GuiLabel(bounds, slider_state.options[slider_state.selected])

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		slider_state.hovered = true
		hover_stack_add(slider_state)
	} else {
		slider_state.hovered = false
	}

	if is_current_hover(slider_state) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
		if rl.IsMouseButtonReleased(.LEFT) {
			if (slider_state.selected != len(slider_state.options) - 1) {
				slider_state.selected += 1
			} else {
				slider_state.selected = 0
			}
		}
	}
	return slider_state.selected

}

CheckBoxState :: struct {
	using gui_control: GuiControl,
	text:              cstring,
	toggle:            ^bool,
}

init_check_box :: proc(check_box_state: ^CheckBoxState, text: cstring, toggle: ^bool) {
	check_box_state.id = GUI_ID
	check_box_state.text = text
	check_box_state.toggle = toggle

	GUI_ID += 1
}

GuiCheckBox :: proc {
	GuiCheckBoxWithState,
	GuiCheckBoxStateless,
}

GuiCheckBoxWithState :: proc(bounds: rl.Rectangle, check_box_state: ^CheckBoxState) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	border: f32 : 2

	box_x := x
	box_y := y
	box_width := height
	box_height := height

	label_x := box_x + box_width + border
	label_y := y
	label_width := width - box_width - (border * 4)
	label_height := height

	rl.DrawRectangleRec({box_x, box_y, box_width, box_height}, BUTTON_BORDER_COLOUR)

	if !check_box_state.toggle^ {
		rl.DrawRectangleRec(
			{box_x + border, box_y + border, box_width - (border * 2), box_height - (border * 2)},
			BUTTON_COLOUR,
		)
	} else {
		rl.DrawRectangleRec(
			{box_x + border, box_y + border, box_width - (border * 2), box_height - (border * 2)},
			BUTTON_ACTIVE_COLOUR,
		)
	}

	GuiLabel({label_x, label_y, label_width, label_height}, check_box_state.text)

	if rl.CheckCollisionPointRec(state.mouse_pos, {box_x, box_y, box_width, box_height}) {
		check_box_state.hovered = true
		hover_stack_add(check_box_state)
	} else {
		check_box_state.hovered = false
	}

	if is_current_hover(check_box_state) {
		rl.DrawRectangleRec({box_x, box_y, box_width, box_height}, BUTTON_HOVER_COLOUR)
		if rl.IsMouseButtonReleased(.LEFT) {
			check_box_state.toggle^ = !check_box_state.toggle^
		}
	}

}

GuiCheckBoxStateless :: proc(bounds: rl.Rectangle, text: cstring, toggle: ^bool) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	box_x := x
	box_y := y
	box_width := height
	box_height := height

	label_x := box_x + box_width
	label_y := y
	label_width := width - box_width
	label_height := height

	border: f32 : 2

	rl.DrawRectangleRec({box_x, box_y, box_width, box_height}, BUTTON_BORDER_COLOUR)
	if !toggle^ {
		rl.DrawRectangleRec(
			{box_x + border, box_y + border, box_width - (border * 2), box_height - (border * 2)},
			BUTTON_COLOUR,
		)
	} else {
		rl.DrawRectangleRec(
			{box_x + border, box_y + border, box_width - (border * 2), box_height - (border * 2)},
			BUTTON_ACTIVE_COLOUR,
		)
	}

	GuiLabel({label_x, label_y, label_width, label_height}, text)

	if state.gui_enabled {
		if rl.CheckCollisionPointRec(state.mouse_pos, {box_x, box_y, box_width, box_height}) {
			rl.DrawRectangleRec({box_x, box_y, box_width, box_height}, BUTTON_HOVER_COLOUR)
			if rl.IsMouseButtonReleased(.LEFT) {
				toggle^ = !toggle^
			}
		}
	}
}

EntityButtonState :: struct {
	using guiControl: GuiControl,
	entity:           ^Entity,
	btn_list:         ^[dynamic]EntityButtonState,
	index:            int,
	up_button:        ButtonState,
	down_button:      ButtonState,
	check_box:        CheckBoxState,
}

init_entity_button_state :: proc(
	button_state: ^EntityButtonState,
	entity: ^Entity,
	btn_list: ^[dynamic]EntityButtonState,
	index: int,
) {
	button_state.id = GUI_ID
	button_state.entity = entity
	button_state.btn_list = btn_list
	button_state.index = index

	GUI_ID += 1

	up_button := ButtonState{}
	down_button := ButtonState{}

	init_button_state(&button_state.up_button)
	init_button_state(&button_state.down_button)

	init_check_box(&button_state.check_box, "visible", &entity.visible)
}

GuiEntityButtonClickable :: proc(
	bounds: rl.Rectangle,
	button_state: ^EntityButtonState,
) -> (
	clicked: bool,
) {
	using state.gui_properties
	rl.GuiSetIconScale(1)
	defer rl.GuiSetIconScale(2)

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	BORDER: f32 : 2
	MARGIN: f32 : 0.01

	INITIATIVE_SPLIT: f32 : 0.14
	NAME_SPLIT: f32 : 0.54
	HEALTH_SPLIT: f32 : 0.29

	LABELS_WIDTH: f32 = (width - (BORDER * 2)) - (height * 0.35) - (height * 0.1)

	initiative_x := x + BORDER + (height * 0.35) + (height * 0.1)
	initiative_y := y + BORDER
	initiative_width := LABELS_WIDTH * INITIATIVE_SPLIT
	initiative_height := height - (BORDER * 2)

	name_x := initiative_x + initiative_width + (LABELS_WIDTH * MARGIN)
	name_y := y + BORDER
	name_width := LABELS_WIDTH * NAME_SPLIT
	name_height := height - (BORDER * 2)

	health_x := initiative_x + initiative_width + name_width + (LABELS_WIDTH * MARGIN)
	health_y := y + BORDER
	health_width := LABELS_WIDTH * HEALTH_SPLIT
	health_height := height - (BORDER * 2)

	//Draw border
	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{x + BORDER, y + BORDER, width - (BORDER * 2), height - (BORDER * 2)},
		BUTTON_COLOUR,
	)

	GuiLabel({name_x, name_y, name_width, name_height}, cstr(button_state.entity.alias))

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		button_state.hovered = true
		hover_stack_add(button_state)
	} else {
		button_state.hovered = false
	}

	if is_current_hover(button_state) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
		if rl.IsMouseButtonReleased(.LEFT) {
			clicked = true
			return
		}
	}

	if GuiButton(
		{x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)},
		&button_state.up_button,
		rl.GuiIconText(.ICON_ARROW_UP, ""),
	) {
		if (button_state.index > 0) {
			temp_entity := button_state.btn_list[button_state.index - 1]
			button_state.btn_list[button_state.index - 1] =
				button_state.btn_list[button_state.index]
			button_state.btn_list[button_state.index] = temp_entity
		}
	}

	if GuiButton(
		{x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)},
		&button_state.down_button,
		rl.GuiIconText(.ICON_ARROW_DOWN, ""),
	) {
		if (button_state.index < len(button_state.btn_list^) - 1) {
			temp_entity := button_state.btn_list[button_state.index + 1]
			button_state.btn_list[button_state.index + 1] =
				button_state.btn_list[button_state.index]
			button_state.btn_list[button_state.index] = temp_entity
		}
	}
	//Initiative label
	GuiLabel(
		{initiative_x, initiative_y, initiative_width, initiative_height},
		cstr(button_state.entity.initiative),
	)
	//Health label
	health_label_text: cstring
	if button_state.entity.temp_HP > 0 {
		health_label_text = fmt.ctprintf(
			"%v/%v+%v",
			button_state.entity.HP,
			button_state.entity.HP_max,
			button_state.entity.temp_HP,
		)
	} else {
		health_label_text = fmt.ctprintf(
			"%v/%v",
			button_state.entity.HP,
			button_state.entity.HP_max,
		)
	}

	GuiLabel({health_x, health_y, health_width, health_height}, cstr(health_label_text))
	text_align_left()
	GuiCheckBox(
		{x + (width * 0.75), y + (height * 0.75), (width * 0.25), (height * 0.2)},
		&button_state.check_box,
	)
	text_align_center()
	return
}

GuiEntityButton :: proc(bounds: rl.Rectangle, button_state: ^EntityButtonState) {
	using state.gui_properties
	rl.GuiSetIconScale(1)
	defer rl.GuiSetIconScale(2)

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	BORDER: f32 : 2
	MARGIN: f32 : 0.01

	INITIATIVE_SPLIT: f32 : 0.14
	NAME_SPLIT: f32 : 0.54
	HEALTH_SPLIT: f32 : 0.29

	LABELS_WIDTH: f32 = (width - (BORDER * 2)) - (height * 0.35) - (height * 0.1)

	initiative_x := x + BORDER + (height * 0.35) + (height * 0.1)
	initiative_y := y + BORDER
	initiative_width := LABELS_WIDTH * INITIATIVE_SPLIT
	initiative_height := height - (BORDER * 2)

	name_x := initiative_x + initiative_width + (LABELS_WIDTH * MARGIN)
	name_y := y + BORDER
	name_width := LABELS_WIDTH * NAME_SPLIT
	name_height := height - (BORDER * 2)

	health_x := initiative_x + initiative_width + name_width + (LABELS_WIDTH * MARGIN)
	health_y := y + BORDER
	health_width := LABELS_WIDTH * HEALTH_SPLIT
	health_height := height - (BORDER * 2)

	name := button_state.entity.alias
	initiative := button_state.entity.initiative
	//Draw border
	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{x + BORDER, y + BORDER, width - (BORDER * 2), height - (BORDER * 2)},
		BUTTON_COLOUR,
	)

	GuiLabel({name_x, name_y, name_width, name_height}, cstr(name))

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		button_state.hovered = true
		hover_stack_add(button_state)
	} else {
		button_state.hovered = false
	}

	if GuiButton(
		{x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)},
		&button_state.up_button,
		rl.GuiIconText(.ICON_ARROW_UP, ""),
	) {
		if (button_state.index > 0) {
			temp_entity := button_state.btn_list[button_state.index - 1]
			button_state.btn_list[button_state.index - 1] =
				button_state.btn_list[button_state.index]
			button_state.btn_list[button_state.index] = temp_entity
		}
	}

	if GuiButton(
		{x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)},
		&button_state.down_button,
		rl.GuiIconText(.ICON_ARROW_DOWN, ""),
	) {
		if (button_state.index < len(button_state.btn_list^) - 1) {
			temp_entity := button_state.btn_list[button_state.index + 1]
			button_state.btn_list[button_state.index + 1] =
				button_state.btn_list[button_state.index]
			button_state.btn_list[button_state.index] = temp_entity
		}
	}

	//Initiative label
	GuiLabel({initiative_x, initiative_y, initiative_width, initiative_height}, cstr(initiative))
	//Health label
	health_label_text: cstring
	if button_state.entity.temp_HP > 0 {
		health_label_text = fmt.ctprintf(
			"%v/%v+%v",
			button_state.entity.HP,
			button_state.entity.HP_max,
			button_state.entity.temp_HP,
		)
	} else {
		health_label_text = fmt.ctprintf(
			"%v/%v",
			button_state.entity.HP,
			button_state.entity.HP_max,
		)
	}

	GuiLabel({health_x, health_y, health_width, health_height}, cstr(health_label_text))
	//Visibility option 
	text_align_left()
	GuiCheckBox(
		{x + (width * 0.8), y + (height * 0.75), (height * 0.2), (height * 0.2)},
		"visible",
		&button_state.entity.visible,
	)
	text_align_center()
}

dropdown_bounds: rl.Rectangle
dropdown_content_rec: rl.Rectangle
dropdown_view: rl.Rectangle
dropdown_scrolll: rl.Vector2

DropdownState :: struct {
	using gui_control: GuiControl,
	title:             cstring,
	static_title:      bool,
	labels:            []cstring,
	selected:          i32,
	active:            bool,
	btn_list:          ^map[i32]^bool,
}

init_dropdown_state :: proc(
	dropdown_state: ^DropdownState,
	title: cstring,
	labels: []cstring,
	btn_list: ^map[i32]^bool,
) {
	dropdown_state.id = GUI_ID
	dropdown_state.labels = labels
	dropdown_state.btn_list = btn_list

	if title != "" {
		dropdown_state.title = title
		dropdown_state.static_title = true
	}

	GUI_ID += 1
}

@(deferred_in = _draw_dropdown)
GuiDropdownControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownState) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	initial_text_size := TEXT_SIZE

	defer {
		TEXT_SIZE = initial_text_size
		rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
	}

	border: f32 : 2
	max_items: f32 : 4

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		dropdown_state.hovered = true
		hover_stack_add(dropdown_state)
	} else {
		dropdown_state.hovered = false
	}

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{x + border, y + border, width - (border * 2), height - (border * 2)},
		BUTTON_COLOUR,
	)
	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) && is_current_hover(dropdown_state) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
	}

	if !dropdown_state.static_title {
		dropdown_state.title = dropdown_state.labels[dropdown_state.selected]
	}
	GuiLabel(
		{x + border, y + border, width - (2 * border), height - (2 * border)},
		dropdown_state.title,
	)
}

@(private)
_draw_dropdown :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownState) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	bounds_check_x := x
	bounds_check_y := y
	bounds_check_width := width
	bounds_check_height := height

	cursor_x: f32 = x
	cursor_y: f32 = y

	border: f32 : 2
	max_items: f32 : 4

	dropdown_height: f32 =
		cast(f32)(max_items * LINE_HEIGHT) if (cast(f32)len(dropdown_state.labels) >= max_items) else cast(f32)len(dropdown_state.labels) * LINE_HEIGHT

	if y <= (state.window_height / 2) {
		cursor_y += LINE_HEIGHT
		bounds_check_y += LINE_HEIGHT
	} else {
		cursor_y -= dropdown_height
		bounds_check_y -= dropdown_height
	}

	if rl.CheckCollisionPointRec(
		state.mouse_pos,
		bounds if (!dropdown_state.active) else rl.Rectangle{bounds.x, cursor_y, bounds.width, bounds.height + dropdown_height},
	) {
		dropdown_state.hovered = true
		hover_stack_add(dropdown_state)
	} else {
		dropdown_state.hovered = false
	}

	if is_current_hover(dropdown_state) {
		if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
			if rl.IsMouseButtonReleased(.LEFT) {
				if !dropdown_state.active {
					for _, dropdown_active in dropdown_state.btn_list {
						dropdown_active^ = false
					}
					dropdown_state.active = true
				} else {
					dropdown_state.active = false
				}
				if (dropdown_state.active) {
					dropdown_bounds = {x, cursor_y, width, LINE_HEIGHT * max_items}
					dropdown_content_rec = {x, cursor_y, width, 0}
					dropdown_view = {0, 0, 0, 0}
					dropdown_scrolll = {0, 0}
				}
			}
		}
	}

	if dropdown_state.active {
		rl.DrawRectangleRec({x, cursor_y, width, dropdown_height}, BUTTON_BORDER_COLOUR)
		rl.DrawRectangleRec(
			{x + border, cursor_y + border, width - (border * 2), dropdown_height - (border * 2)},
			DROPDOWN_COLOUR,
		)

		if (cast(i32)len(dropdown_state.labels) > cast(i32)max_items) {
			dropdown_content_rec.width = width - 14
			dropdown_content_rec.height = cast(f32)len(dropdown_state.labels) * LINE_HEIGHT

			rl.GuiScrollPanel(
				dropdown_bounds,
				nil,
				dropdown_content_rec,
				&dropdown_scrolll,
				&dropdown_view,
			)
			rl.BeginScissorMode(
				cast(i32)dropdown_view.x,
				cast(i32)dropdown_view.y,
				cast(i32)dropdown_view.width,
				cast(i32)dropdown_view.height,
			)
			rl.ClearBackground(DROPDOWN_COLOUR)
		} else {
			dropdown_content_rec.width = width
		}

		cursor_y += dropdown_scrolll.y

		selected_cursor_y := cursor_y + (cast(f32)dropdown_state.selected * LINE_HEIGHT)
		currently_selected := rl.Rectangle {
			x,
			selected_cursor_y,
			dropdown_content_rec.width,
			LINE_HEIGHT,
		}

		rl.DrawRectangleRec(currently_selected, DROPDOWN_SELECTED_COLOUR)

		for label, i in dropdown_state.labels {
			option_bounds := rl.Rectangle{x, cursor_y, dropdown_content_rec.width, LINE_HEIGHT}

			if rl.CheckCollisionRecs(
				option_bounds,
				{bounds_check_x, bounds_check_y, bounds_check_width, dropdown_height},
			) {
				GuiLabel(
					{
						option_bounds.x + (cast(f32)border * 2),
						option_bounds.y,
						dropdown_content_rec.width - (border * 2),
						LINE_HEIGHT,
					},
					label,
				)
				rl.GuiLine(
					{option_bounds.x, option_bounds.y, option_bounds.width, cast(f32)border},
					"",
				)

				if rl.CheckCollisionPointRec(state.mouse_pos, option_bounds) {
					rl.DrawRectangleRec(option_bounds, DROPDOWN_HOVER_COLOUR)
					//Draw highlight colour
					if rl.IsMouseButtonReleased(.LEFT) {
						dropdown_state.selected = cast(i32)i
						dropdown_state.active = false
						state.hover_consumed = false
					}
				}
			}
			cursor_y += LINE_HEIGHT
		}

		if (cast(i32)len(dropdown_state.labels) > cast(i32)max_items) {
			rl.EndScissorMode()
		} else {
			dropdown_scrolll.y = 0
		}
	}
}

DropdownSelectState :: struct {
	using guiControl: GuiControl,
	title:            cstring,
	check_box_states: []CheckBoxState,
	selected:         []bool,
	active:           bool,
	btn_list:         ^map[i32]^bool,
}

init_dropdown_select_state :: proc(
	dropdown_state: ^DropdownSelectState,
	title: cstring,
	labels: []cstring,
	btn_list: ^map[i32]^bool,
) {
	dropdown_state.id = GUI_ID
	dropdown_state.title = title
	dropdown_state.check_box_states = make_slice(
		[]CheckBoxState,
		len(labels),
		allocator = static_alloc,
	)
	dropdown_state.selected = make_slice([]bool, len(labels), allocator = static_alloc)
	dropdown_state.btn_list = btn_list

	GUI_ID += 1

	for _, i in labels {
		init_check_box(&dropdown_state.check_box_states[i], labels[i], &dropdown_state.selected[i])
	}
}

DeInitDropdownSelectState :: proc(dropdown_state: ^DropdownSelectState) {
	delete(dropdown_state.title)
	delete(dropdown_state.check_box_states)
	delete(dropdown_state.selected)
	clear(dropdown_state.btn_list)
}

@(deferred_in = _draw_dropdown_select)
GuiDropdownSelectControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownSelectState) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	initial_text_size := TEXT_SIZE

	defer {
		TEXT_SIZE = initial_text_size
		set_text_size(initial_text_size)
	}

	border: f32 : 2
	max_items: f32 : 4

	if !dropdown_state.active {
		if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
			dropdown_state.hovered = true
			hover_stack_add(dropdown_state)
		} else {
			dropdown_state.hovered = false
		}
	}

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(
		{x + border, y + border, width - (border * 2), height - (border * 2)},
		BUTTON_COLOUR,
	)
	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) && is_current_hover(dropdown_state) {
		rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
	}
	GuiLabel(
		{x + border, y + border, width - (border * 2), height - (border * 2)},
		dropdown_state.title,
	)
}

@(private)
_draw_dropdown_select :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownSelectState) {
	using state.gui_properties

	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	bounds_check_x := x
	bounds_check_y := y
	bounds_check_width := width
	bounds_check_height := height

	cursor_x: f32 = x
	cursor_y: f32 = y

	border: f32 : 2
	max_items: f32 : 4

	dropdown_height: f32 =
		cast(f32)(max_items * LINE_HEIGHT) if (cast(f32)len(dropdown_state.check_box_states) >= max_items) else cast(f32)len(dropdown_state.check_box_states) * LINE_HEIGHT

	if y <= (state.window_height / 2) {
		cursor_y += LINE_HEIGHT
		bounds_check_y += LINE_HEIGHT
	} else {
		cursor_y -= dropdown_height
		bounds_check_y -= dropdown_height
	}

	if dropdown_state.active {
		if rl.CheckCollisionPointRec(
			state.mouse_pos,
			rl.Rectangle {
				bounds_check_x,
				bounds_check_y if (y > (state.window_height / 2)) else bounds.y,
				bounds_check_width,
				bounds_check_height + dropdown_height,
			},
		) {
			dropdown_state.hovered = true
			hover_stack_add(dropdown_state)
		} else {
			dropdown_state.hovered = false
		}

		rl.DrawRectangleRec({x, cursor_y, width, dropdown_height}, BUTTON_BORDER_COLOUR)
		rl.DrawRectangleRec(
			{x + border, cursor_y + border, width - (border * 2), dropdown_height - (border * 2)},
			DROPDOWN_COLOUR,
		)
		dropdown_bounds = {x, cursor_y, width, dropdown_height}

		cursor_y += dropdown_scrolll.y

		if (cast(f32)len(dropdown_state.check_box_states) > max_items) {
			dropdown_content_rec.width = width - 14
			dropdown_content_rec.height =
				cast(f32)len(dropdown_state.check_box_states) * LINE_HEIGHT
			rl.GuiScrollPanel(
				dropdown_bounds,
				nil,
				dropdown_content_rec,
				&dropdown_scrolll,
				&dropdown_view,
			)
			rl.BeginScissorMode(
				cast(i32)dropdown_view.x,
				cast(i32)dropdown_view.y,
				cast(i32)dropdown_view.width,
				cast(i32)dropdown_view.height,
			)
		} else {
			dropdown_content_rec.width = width
		}

		check_box_x := x + border
		check_box_width := dropdown_content_rec.width - (border * 2)
		check_box_height := LINE_HEIGHT - (border * 10)

		for &check_box_state, i in dropdown_state.check_box_states {
			if rl.CheckCollisionRecs(
				{
					check_box_x,
					cursor_y + (LINE_HEIGHT / 2) - (check_box_height / 2),
					check_box_width,
					check_box_height,
				},
				{bounds_check_x, bounds_check_y, bounds_check_width, dropdown_height},
			) {
				GuiCheckBox(
					{
						check_box_x,
						cursor_y + (LINE_HEIGHT / 2) - (check_box_height / 2),
						check_box_width,
						check_box_height,
					},
					&check_box_state,
				)
				rl.GuiLine(
					{x, cursor_y + LINE_HEIGHT, dropdown_content_rec.width, cast(f32)border},
					"",
				)
			}
			cursor_y += LINE_HEIGHT
		}

		if (cast(i32)len(dropdown_state.check_box_states) > cast(i32)max_items) {
			rl.EndScissorMode()
		} else {
			dropdown_scrolll.y = 0
		}
	}

	if is_current_hover(dropdown_state) {
		if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
			if rl.IsMouseButtonReleased(.LEFT) {
				if !dropdown_state.active {
					for _, dropdown_active in dropdown_state.btn_list {
						dropdown_active^ = false
					}
					dropdown_state.active = true
				} else {
					dropdown_state.active = false
					return
				}
				if (dropdown_state.active) {
					dropdown_bounds = {x, cursor_y, width, LINE_HEIGHT * max_items}
					dropdown_content_rec = {x, cursor_y, width, 0}
					dropdown_view = {0, 0, 0, 0}
					dropdown_scrolll = {0, 0}
					return
				}
			}
		}
	}
}

TabControlState :: struct {
	using guiControl: GuiControl,
	options:          []cstring,
	selected:         i32,
}

init_tab_control_state :: proc(tab_state: ^TabControlState, options: []cstring) {
	tab_state.id = GUI_ID
	tab_state.options = options[:]

	GUI_ID += 1
}

GuiTabControl :: proc(bounds: rl.Rectangle, tab_state: ^TabControlState) -> i32 {
	using state.gui_properties

	cursor_x := bounds.x
	cursor_y := bounds.y

	button_width := bounds.width / cast(f32)len(tab_state.options) + 1

	selected_padding: f32 : 5
	border: f32 : 2

	tab_bounds := make([dynamic]rl.Rectangle, allocator = frame_alloc)

	for _, i in tab_state.options {
		switch i {
		case 0:
			if cast(i32)i == tab_state.selected {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x,
						cursor_y - selected_padding,
						button_width + selected_padding,
						state.gui_properties.LINE_HEIGHT + selected_padding,
					},
				)
			} else {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x,
						cursor_y,
						button_width,
						state.gui_properties.LINE_HEIGHT,
					},
				)
			}
		case 1 ..< len(tab_state.options) - 1:
			if cast(i32)i == tab_state.selected {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x - selected_padding,
						cursor_y - selected_padding,
						button_width + (selected_padding * 2),
						state.gui_properties.LINE_HEIGHT + selected_padding,
					},
				)
			} else {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x,
						cursor_y,
						button_width,
						state.gui_properties.LINE_HEIGHT,
					},
				)
			}
		case len(tab_state.options) - 1:
			if cast(i32)i == tab_state.selected {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x - selected_padding,
						cursor_y - selected_padding,
						button_width + selected_padding,
						state.gui_properties.LINE_HEIGHT + selected_padding,
					},
				)
			} else {
				append(
					&tab_bounds,
					rl.Rectangle {
						cursor_x,
						cursor_y,
						button_width,
						state.gui_properties.LINE_HEIGHT,
					},
				)
			}
		}
		cursor_x +=
			button_width -
			(cast(f32)len(tab_state.options) / (cast(f32)len(tab_state.options) - 1))
	}

	text_align_center()

	hovered := false

	for bounds, i in tab_bounds {
		if cast(i32)i != tab_state.selected {
			rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
			rl.DrawRectangleRec(
				{
					bounds.x + border,
					bounds.y + border,
					bounds.width - (border * 2),
					bounds.height - (border * 2),
				},
				BUTTON_COLOUR,
			)
			GuiLabel(
				{
					bounds.x + border,
					bounds.y + border,
					bounds.width - (border * 2),
					bounds.height - (border * 2),
				},
				tab_state.options[i],
			)
		}
	}

	for bounds, i in tab_bounds {
		if cast(i32)i == tab_state.selected {
			rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
			rl.DrawRectangleRec(
				{
					bounds.x + selected_padding,
					bounds.y + selected_padding,
					bounds.width - (selected_padding * 2),
					bounds.height - (selected_padding * 2),
				},
				BUTTON_COLOUR,
			)
			GuiLabel(
				{
					bounds.x + selected_padding,
					bounds.y + selected_padding,
					bounds.width - (selected_padding * 2),
					bounds.height - (selected_padding * 2),
				},
				tab_state.options[i],
			)
		}

		if state.gui_enabled {
			if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
				hovered = true
				rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
			}

			if is_current_hover(tab_state) {
				if rl.IsMouseButtonPressed(.LEFT) {
					if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
						tab_state.selected = cast(i32)i
					}
				}
			}
		}
	}

	if hovered {
		tab_state.hovered = true
		hover_stack_add(tab_state)
	} else {
		tab_state.hovered = false
	}

	return tab_state.selected
}

PanelState :: struct {
	rec:           rl.Rectangle,
	content_rec:   rl.Rectangle,
	view:          rl.Rectangle,
	scroll:        rl.Vector2,
	height_needed: f32,
	active:        bool,
}

init_panel_state :: proc(state: ^PanelState) {
	state.rec = {0, 0, 0, 0}
	state.content_rec = {}
	state.view = {0, 0, 0, 0}
	state.scroll = {0, 0}
}

GuiPanel :: proc(bounds: rl.Rectangle, panel_state: ^PanelState, text: cstring) {
	rl.GuiPanel({bounds.x, bounds.y, bounds.width, bounds.height}, text)

	panel_state.rec = {
		bounds.x,
		bounds.y + state.gui_properties.LINE_HEIGHT,
		bounds.width,
		bounds.height - state.gui_properties.LINE_HEIGHT,
	}

	rl.DrawRectangleRec(
		{bounds.x, bounds.y, bounds.width, state.gui_properties.LINE_HEIGHT},
		state.gui_properties.HEADER_COLOUR,
	)
	text_align_center()
	GuiLabel({bounds.x, bounds.y, bounds.width, state.gui_properties.LINE_HEIGHT}, text)
}

MessageBoxState :: struct {
	using guiControl: GuiControl,
	title:            cstring,
	message:          cstring,
}

init_message_box :: proc(message_box_state: ^MessageBoxState, title: cstring, message: cstring) {
	message_box_state.id = GUI_ID
	message_box_state.title = title
	message_box_state.message = message

	GUI_ID += 1
}

GuiMessageBox :: proc(bounds: rl.Rectangle, message_box_state: ^MessageBoxState) -> bool {
	using state.gui_properties

	initial_text_size := TEXT_SIZE
	defer set_text_size(initial_text_size)

	border: f32 : 2
	padding: f32 = bounds.width * 0.1

	inner_bounds := rl.Rectangle {
		bounds.x + border,
		bounds.y + border,
		bounds.width - (border * 2),
		bounds.height - (border * 2),
	}

	top_bar_bounds := rl.Rectangle{bounds.x, bounds.y, bounds.width, bounds.height * 0.3}

	label_bounds := rl.Rectangle {
		bounds.x + padding,
		bounds.y + bounds.height * 0.35,
		bounds.width - (padding * 2),
		bounds.height * 0.35,
	}

	button_bounds := rl.Rectangle {
		bounds.x + padding,
		bounds.y + bounds.height * 0.7,
		bounds.width - (padding * 2),
		bounds.height * 0.25,
	}

	if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
		message_box_state.hovered = true
		hover_stack_add(message_box_state)
	} else {
		message_box_state.hovered = false
	}

	TEXT_SIZE = TEXT_SIZE_DEFAULT
	set_text_size(TEXT_SIZE)

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(inner_bounds, rl.WHITE)

	rl.DrawRectangleRec(top_bar_bounds, BUTTON_BORDER_COLOUR)

	GuiLabel(top_bar_bounds, message_box_state.title)

	GuiLabel(label_bounds, message_box_state.message)

	button_state := ButtonState{}
	button_state.id = message_box_state.id

	if GuiButton(button_bounds, &button_state, "Close") {
		return true
	}

	return false
}

MessageBoxQueueState :: struct {
	messages: [dynamic]MessageBoxState,
}

add_message :: proc(message_queue: ^MessageBoxQueueState, message_box: MessageBoxState) {
	append(&message_queue.messages, message_box)
}

remove_message :: proc(message_queue: ^MessageBoxQueueState, message_box: ^MessageBoxState) {
	for test_message_box, i in message_queue.messages {
		if test_message_box.id == message_box.id {
			ordered_remove(&message_queue.messages, i)
			message_box.hovered = false
		}
	}
}

GuiMessageBoxQueue :: proc(message_queue_state: ^MessageBoxQueueState) {
	cursor_x: f32 = state.window_width - 350
	cursor_y: f32 = 50

	message_loop: for &message_box, i in message_queue_state.messages {
		if GuiMessageBox({cursor_x, cursor_y, 300, 100}, &message_box) {
			remove_message(message_queue_state, &message_box)
		}
		cursor_y += 110

		if i >= 4 {
			break message_loop
		}
	}
}

PopupState :: struct {
	using gui_control: GuiControl,
	dialog:            cstring,
	options:           []cstring,
}

init_popup :: proc(popup_state: ^PopupState, dialog: cstring, options: []cstring) {
	popup_state.id = GUI_ID
	popup_state.dialog = dialog
	popup_state.options = options

	GUI_ID += 1
}

GuiPopup :: proc(bounds: rl.Rectangle, popup_state: ^PopupState) -> int {
	using state.gui_properties

	gui_enable()

	rl.BeginScissorMode(
		cast(i32)bounds.x,
		cast(i32)bounds.y,
		cast(i32)bounds.width,
		cast(i32)bounds.height,
	)
	defer rl.EndScissorMode()

	border: f32 : 2
	padding: f32 = bounds.width * 0.1

	inner_bounds := rl.Rectangle {
		bounds.x + border,
		bounds.y + border,
		bounds.width - (border * 2),
		bounds.height - (border * 2),
	}

	top_bar_bounds := rl.Rectangle{bounds.x, bounds.y, bounds.width, bounds.height * 0.3}

	label_bounds := rl.Rectangle {
		bounds.x + padding,
		bounds.y + bounds.height * 0.35,
		bounds.width - (padding * 2),
		bounds.height * 0.35,
	}

	rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
	rl.DrawRectangleRec(inner_bounds, rl.WHITE)

	rl.DrawRectangleRec(top_bar_bounds, BUTTON_BORDER_COLOUR)

	GuiLabel(label_bounds, popup_state.dialog)

	options_bounds := make([dynamic]rl.Rectangle, allocator = frame_alloc)

	options_y := bounds.y + (bounds.height * 0.7)
	options_width :=
		(bounds.width - (padding * 2) - (padding * cast(f32)len(popup_state.options))) /
		cast(f32)len(popup_state.options)

	cursor_x := bounds.x + padding

	for option, i in popup_state.options {
		append(
			&options_bounds,
			rl.Rectangle {
				cursor_x + (cast(f32)i * (options_width + padding)),
				options_y,
				options_width,
				bounds.height * 0.25,
			},
		)
	}

	for bounds, i in options_bounds {
		rl.DrawRectangleRec(bounds, BUTTON_BORDER_COLOUR)
		rl.DrawRectangleRec(
			{
				bounds.x + border,
				bounds.y + border,
				bounds.width - (border * 2),
				bounds.height - (border * 2),
			},
			BUTTON_COLOUR,
		)
		GuiLabel(bounds, popup_state.options[i])
		if rl.CheckCollisionPointRec(state.mouse_pos, bounds) {
			rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
			rl.DrawRectangleRec(bounds, BUTTON_HOVER_COLOUR)
			if rl.IsMouseButtonReleased(.LEFT) {
				gui_enable()
				return i
			}
		}
	}

	gui_disable()
	return -1
}

GuiFileDialog :: proc(bounds: rl.Rectangle) -> bool {
	using state.gui_properties

	cursor_x := bounds.x
	cursor_y := bounds.y

	TEXT_SIZE = TEXT_SIZE_DEFAULT
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

	if (GuiButton(
			   {cursor_x, cursor_y, NAVBAR_SIZE, NAVBAR_SIZE},
			   rl.GuiIconText(.ICON_ARROW_LEFT, ""),
		   )) {
		current_dir_split := strings.split(string(state.load_screen_state.current_dir), "/")
		outer_directory := strings.clone_to_cstring(
			strings.join(current_dir_split[:len(current_dir_split) - 1], "/"),
		)

		inject_at(
			&state.load_screen_state.dir_nav_list,
			state.load_screen_state.current_dir_index,
			outer_directory,
		)
		state.load_screen_state.current_dir = outer_directory
		get_current_dir_files()
	}
	cursor_x += NAVBAR_SIZE + NAVBAR_PADDING

	if (GuiButton(
			   {cursor_x, cursor_y, NAVBAR_SIZE, NAVBAR_SIZE},
			   rl.GuiIconText(.ICON_ARROW_RIGHT, ""),
		   )) {
		if (state.load_screen_state.current_dir_index <
			   (cast(u32)len(state.load_screen_state.dir_nav_list) - 1)) {
			state.load_screen_state.current_dir =
				state.load_screen_state.dir_nav_list[state.load_screen_state.current_dir_index + 1]
			state.load_screen_state.current_dir_index += 1
			get_current_dir_files()
		}
	}
	cursor_x += NAVBAR_SIZE + NAVBAR_PADDING

	path_text_length := bounds.width - cursor_x - (NAVBAR_SIZE * 3)
	GuiLabel(
		{cursor_x, cursor_y, path_text_length, NAVBAR_SIZE},
		state.load_screen_state.current_dir,
	)
	cursor_x += path_text_length + NAVBAR_PADDING

	if (GuiButton({cursor_x, cursor_y, (NAVBAR_SIZE * 3), NAVBAR_SIZE}, "Select")) {
		//Check selected file and return true.
		//For logic with this element interacting with the outer program.
		if (rl.FileExists(state.load_screen_state.selected_file)) {
			if (rl.GetFileExtension(state.load_screen_state.selected_file) == cstring(".combat")) {
				state.load_screen_state.first_load = true
				return true
			}
		}
	}
	cursor_x = bounds.x
	cursor_y += NAVBAR_SIZE + NAVBAR_PADDING

	panel_width := bounds.width
	panel_height := state.window_height - cursor_y - PADDING_BOTTOM

	if (state.load_screen_state.first_load) {
		//State reset in case of going in and out of loading screen.
		state.load_screen_state.selected_file = nil
		state.load_screen_state.first_load = false
		state.load_screen_state.panel.content_rec = {cursor_x, cursor_y, panel_width, 0}
	}

	GuiPanel(
		{cursor_x, cursor_y, panel_width, panel_height},
		&state.load_screen_state.panel,
		"Files",
	)

	cursor_x += PADDING_ICONS
	cursor_y += LINE_HEIGHT + PADDING_ICONS + state.load_screen_state.panel.scroll.y

	icons_per_row := cast(i32)(state.load_screen_state.panel.content_rec.width /
		(ICON_SIZE + PADDING_ICONS))
	num_rows_max := cast(i32)((state.load_screen_state.panel.rec.height -
			PADDING_TOP -
			PADDING_BOTTOM) /
		(ICON_SIZE + PADDING_ICONS))

	file_counter: u32 = 0
	dir_count: u32 = cast(u32)len(state.load_screen_state.dirs_list)
	file_count: u32 = cast(u32)len(state.load_screen_state.files_list)

	num_rows_needed := (cast(f32)(dir_count + file_count) / cast(f32)icons_per_row)

	if (num_rows_needed / cast(f32)cast(i32)(num_rows_needed)) > 1 {
		num_rows_needed = cast(f32)cast(i32)(num_rows_needed) + 1
	}

	dynamic_icon_padding := cast(f32)((cast(i32)state.load_screen_state.panel.content_rec.width %
			(icons_per_row * cast(i32)ICON_SIZE)) /
		(icons_per_row + 1))

	if (dynamic_icon_padding < PADDING_ICONS) {
		dynamic_icon_padding = PADDING_ICONS
	}

	if (cast(i32)num_rows_needed > num_rows_max) {
		state.load_screen_state.panel.content_rec.width = panel_width - 14
		state.load_screen_state.panel.content_rec.height =
			(num_rows_needed * ICON_SIZE + PADDING_ICONS) + (PADDING_ICONS * 2) + LINE_HEIGHT
		rl.GuiScrollPanel(
			state.load_screen_state.panel.rec,
			nil,
			state.load_screen_state.panel.content_rec,
			&state.load_screen_state.panel.scroll,
			&state.load_screen_state.panel.view,
		)

		rl.BeginScissorMode(
			cast(i32)state.load_screen_state.panel.view.x,
			cast(i32)state.load_screen_state.panel.view.y,
			cast(i32)state.load_screen_state.panel.view.width,
			cast(i32)state.load_screen_state.panel.view.height,
		)
	} else {
		state.load_screen_state.panel.content_rec.width = panel_width
	}

	rl.GuiSetIconScale(10)

	draw_loop: for _ in 0 ..< num_rows_needed {
		for _ in 0 ..< icons_per_row {
			//Draw each file icon, with padding
			if file_counter < dir_count + file_count {
				filename: cstring = ""
				if (file_counter < dir_count) {
					path_split := strings.split(
						string(state.load_screen_state.dirs_list[file_counter]),
						FILE_SEPERATOR,
						allocator = frame_alloc,
					)
					filename = strings.clone_to_cstring(
						path_split[len(path_split) - 1],
						allocator = frame_alloc,
					)

					if (GuiButton(
							   {cursor_x, cursor_y, ICON_SIZE, ICON_SIZE},
							   filename,
							   rl.GuiIconName.ICON_FOLDER,
						   )) {
						//Folder clicked, change this to be current folder.
						inject_at(
							&state.load_screen_state.dir_nav_list,
							state.load_screen_state.current_dir_index,
							state.load_screen_state.dirs_list[file_counter],
						)
						state.load_screen_state.current_dir =
							state.load_screen_state.dirs_list[file_counter]
						get_current_dir_files()
						break draw_loop
					}

					TEXT_SIZE = 20
					rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
				} else {
					path_split := strings.split(
						string(state.load_screen_state.files_list[file_counter - dir_count]),
						FILE_SEPERATOR,
						allocator = frame_alloc,
					)
					filename = strings.clone_to_cstring(
						path_split[len(path_split) - 1],
						allocator = frame_alloc,
					)
					if (GuiButton(
							   {cursor_x, cursor_y, ICON_SIZE, ICON_SIZE},
							   filename,
							   rl.GuiIconName.ICON_FILETYPE_TEXT,
						   )) {
						state.load_screen_state.selected_file =
							state.load_screen_state.files_list[file_counter - dir_count]
					}

					if state.load_screen_state.files_list[file_counter - dir_count] ==
					   state.load_screen_state.selected_file {
						rl.DrawRectangleRec(
							{cursor_x, cursor_y, ICON_SIZE, ICON_SIZE},
							BUTTON_ACTIVE_COLOUR,
						)
					}

					set_text_size(20)
				}
				cursor_x += ICON_SIZE + dynamic_icon_padding
				file_counter += 1
			}
		}
		cursor_x = bounds.x + PADDING_ICONS
		cursor_y += ICON_SIZE + PADDING_ICONS
	}

	rl.GuiSetIconScale(2)

	if (cast(i32)num_rows_needed > num_rows_max) {
		rl.EndScissorMode()
	} else {
		state.load_screen_state.panel.scroll.y = 0
	}
	return false
}

GuiEntityStats :: proc(bounds: rl.Rectangle, entity: ^Entity, initiative: ^TextInputState = nil) {
	using state.gui_properties

	if entity != nil {
		cursor_x := bounds.x
		cursor_y := bounds.y

		start_x := bounds.x

		defer state.cursor.x = cursor_x
		defer state.cursor.y = cursor_y

		width := bounds.width
		height := bounds.height

		GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.alias)
		cursor_y += LINE_HEIGHT

		if entity.icon_data != "" {
			start_y := cursor_y

			scale := (width / 2) / cast(f32)entity.icon.width
			rl.DrawTextureEx(entity.icon, {cursor_x, cursor_y}, 0, scale, rl.WHITE)
			cursor_x += width / 2

			GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, entity.size)
			cursor_x += width / 4
			GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, entity.race)
			cursor_x = start_x + (width / 2)
			cursor_y += LINE_HEIGHT

			GuiLabel(
				{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
				rl.GuiIconText(.ICON_SHIELD, cstr(entity.AC)),
			)
			cursor_x += width / 4
			GuiLabel(
				{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
				rl.GuiIconText(.ICON_HEART, cstr(entity.HP)),
			)
			cursor_x = start_x + (width / 2)
			cursor_y += LINE_HEIGHT

			GuiLabel({cursor_x, cursor_y, (width / 2), LINE_HEIGHT}, entity.speed)
			cursor_x = start_x
			if ((start_y + (width / 2)) > (cursor_y)) {
				cursor_y = start_y + (width / 2) + PANEL_PADDING
			} else {
				cursor_y += LINE_HEIGHT + PANEL_PADDING
			}

			text_align_left()

			if initiative != nil {
				GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, "Initiative:")
				cursor_x += width / 2

				GuiTextInput({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, initiative)
				entity.initiative = to_i32(initiative.text)
				cursor_x = start_x
				cursor_y += LINE_HEIGHT
			}

			text_align_center()
		} else {
			text_align_left()

			if initiative != nil {
				GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, "Initiative:")
				cursor_x += width / 2

				GuiTextInput({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, initiative)
				entity.initiative = to_i32(initiative.text)
				cursor_x = start_x
				cursor_y += LINE_HEIGHT
			}

			text_align_center()
			GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, entity.size)
			cursor_x += width / 2
			GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, entity.race)
			cursor_x = start_x
			cursor_y += LINE_HEIGHT

			GuiLabel(
				{cursor_x, cursor_y, width / 2, LINE_HEIGHT},
				rl.GuiIconText(.ICON_SHIELD, cstr(entity.AC)),
			)
			cursor_x += width / 2
			GuiLabel(
				{cursor_x, cursor_y, width / 2, LINE_HEIGHT},
				rl.GuiIconText(.ICON_HEART, cstr(entity.HP)),
			)
			cursor_x = start_x
			cursor_y += LINE_HEIGHT

			GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.speed)
			cursor_y += LINE_HEIGHT
		}

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Stat")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Score")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Modifier")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Save")
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "STR: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.STR))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.STR_mod, sep = "") if (entity.STR_mod >= 0) else cstr(entity.STR_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.STR_save, sep = "") if (entity.STR_save >= 0) else cstr(entity.STR_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "DEX: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.DEX))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.DEX_mod, sep = "") if (entity.DEX_mod >= 0) else cstr(entity.DEX_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.DEX_save, sep = "") if (entity.DEX_save >= 0) else cstr(entity.DEX_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "CON: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CON))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.CON_mod, sep = "") if (entity.CON_mod >= 0) else cstr(entity.CON_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.CON_save, sep = "") if (entity.CON_save >= 0) else cstr(entity.CON_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "INT: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.INT))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.INT_mod, sep = "") if (entity.INT_mod >= 0) else cstr(entity.INT_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.INT_save, sep = "") if (entity.INT_save >= 0) else cstr(entity.INT_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "WIS: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.WIS))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.WIS_mod, sep = "") if (entity.WIS_mod >= 0) else cstr(entity.WIS_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.WIS_save, sep = "") if (entity.WIS_save >= 0) else cstr(entity.WIS_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "CHA: ")
		cursor_x += width / 4
		GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CHA))
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.CHA_mod, sep = "") if (entity.CHA_mod >= 0) else cstr(entity.CHA_mod, sep = ""),
		)
		cursor_x += width / 4
		GuiLabel(
			{cursor_x, cursor_y, width / 4, LINE_HEIGHT},
			cstr("+", entity.CHA_save, sep = "") if (entity.CHA_save >= 0) else cstr(entity.CHA_save, sep = ""),
		)
		cursor_x = start_x
		cursor_y += LINE_HEIGHT

		rl.GuiLine({cursor_x, cursor_y, width, 2}, "")

		if (entity.conditions != ConditionSet{}) {
			GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, "Conditions:")
			cursor_y += LINE_HEIGHT

			for condition in gen_condition_string(entity.conditions) {
				GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, cstr(condition))
				cursor_y += LINE_HEIGHT
			}
		}

		vulnerabilities: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.dmg_vulnerabilities,
		)
		resistances: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.dmg_resistances,
		)
		immunities: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.dmg_immunities,
		)

		if len(vulnerabilities) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Vulnerabilities:")
			cursor_x += width / 3
		}
		if len(resistances) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Resistances:")
			cursor_x += width / 3
		}
		if len(immunities) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Immunities:")
			cursor_x = start_x
			cursor_y += LINE_HEIGHT
		}

		vulnerability_y, resistance_y, immunity_y: f32
		prev_y := cursor_y

		for vulnerability in vulnerabilities {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(vulnerability))
			cursor_y += LINE_HEIGHT
		}
		vulnerability_y = cursor_y
		if len(vulnerabilities) > 0 {
			cursor_x += width / 3
			cursor_y = prev_y
		}

		for resistance in resistances {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(resistance))
			cursor_y += LINE_HEIGHT
		}
		resistance_y = cursor_y
		if len(resistances) > 0 {
			cursor_x += width / 3
			cursor_y = prev_y
		}

		for immunity in immunities {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(immunity))
			cursor_y += LINE_HEIGHT
		}
		immunity_y = cursor_y
		if len(immunities) > 0 {
			cursor_x = start_x
		}

		if ((len(resistances) >= len(immunities)) && (len(resistances) >= len(vulnerabilities))) {
			cursor_y = resistance_y
		} else if ((len(immunities) >= len(resistances)) &&
			   (len(immunities) >= len(vulnerabilities))) {
			cursor_y = immunity_y
		} else {
			cursor_y = vulnerability_y
		}
		cursor_x = start_x

		temp_vulnerabilities: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.temp_dmg_vulnerabilities,
		)
		temp_resistances: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.temp_dmg_resistances,
		)
		temp_immunities: []string = gen_vulnerability_resistance_or_immunity_string(
			entity.temp_dmg_immunities,
		)

		if len(temp_resistances) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Resistances:")
			cursor_x += width / 3
		}
		if len(temp_immunities) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Immunities:")
			cursor_x += width / 3
		}
		if len(temp_vulnerabilities) > 0 {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Vulnerabilities:")
			cursor_x = start_x
		}
		if (len(temp_resistances) > 0 ||
			   len(temp_immunities) > 0 ||
			   len(temp_vulnerabilities) > 0) {
			cursor_x = start_x
			cursor_y += LINE_HEIGHT
		}

		temp_resistance_y, temp_immunity_y, temp_vulnerability_y: f32
		temp_prev_y := cursor_y

		for resistance in temp_resistances {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(resistance))
			cursor_y += LINE_HEIGHT
		}
		temp_resistance_y = cursor_y
		if len(temp_resistances) > 0 {
			cursor_x += width / 3
			cursor_y = temp_prev_y
		}

		for immunity in temp_immunities {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(immunity))
			cursor_y += LINE_HEIGHT
		}
		temp_immunity_y = cursor_y
		if len(temp_immunities) > 0 {
			cursor_x += width / 3
			cursor_y = temp_prev_y
		}

		for vulnerability in temp_vulnerabilities {
			GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(vulnerability))
			cursor_y += LINE_HEIGHT
		}
		temp_vulnerability_y = cursor_y
		if len(temp_vulnerabilities) > 0 {
			cursor_x = start_x
		}

		if ((len(temp_resistances) >= len(temp_immunities)) &&
			   (len(temp_resistances) >= len(temp_vulnerabilities))) {
			cursor_y = temp_resistance_y
		} else if ((len(temp_immunities) >= len(temp_resistances)) &&
			   (len(temp_immunities) >= len(temp_vulnerabilities))) {
			cursor_y = temp_immunity_y
		} else {
			cursor_y = temp_vulnerability_y
		}
		cursor_x = start_x

		text_align_left()

		if entity.skills != "" {
			GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, "Skills:")
			cursor_y += LINE_HEIGHT
			skills := strings.split(cast(string)entity.skills, ", ", allocator = frame_alloc)
			for skill in skills {
				GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, cstr(skill))
				cursor_y += LINE_HEIGHT
			}
		}
		GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.CR)
		cursor_y += LINE_HEIGHT

		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE,
			cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE,
		)
		rl.GuiSetStyle(
			.DEFAULT,
			cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL,
			cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE,
		)
	}
}
