package main

import "core:strings"
import rl "vendor:raylib"

draw_load_screen :: proc() {
	using state.gui_properties

	defer GuiMessageBoxQueue(&state.load_screen_state.message_queue)

	state.cursor.x = PADDING_LEFT
	state.cursor.y = PADDING_TOP

	TEXT_SIZE = TEXT_SIZE_DEFAULT
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

	if (GuiButton(
			   {state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT},
			   "Back",
		   )) {
		state.load_screen_state.first_load = true
		state.current_screen_state = state.title_screen_state
		return
	}

	state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

	TEXT_SIZE = TEXT_SIZE_TITLE
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

	initial_text_alignment := rl.GuiGetStyle(
		.DEFAULT,
		cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT,
	)
	text_align_center()
	GuiLabel(
		{
			state.cursor.x,
			state.cursor.y,
			state.window_width - (state.cursor.x * 2),
			MENU_BUTTON_HEIGHT,
		},
		"Load Combat",
	)
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, initial_text_alignment)

	state.cursor.x = PADDING_LEFT
	state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

	set_text_size(TEXT_SIZE_DEFAULT)

	rl.GuiLine(
		{
			state.cursor.x,
			state.cursor.y,
			state.window_width - PADDING_LEFT - PADDING_RIGHT,
			LINE_WIDTH,
		},
		"",
	)
	state.cursor.y += LINE_WIDTH + MENU_BUTTON_PADDING

	if (GuiFileDialog(
			   {
				   state.cursor.x,
				   state.cursor.y,
				   state.window_width - PADDING_LEFT - PADDING_RIGHT,
				   state.window_height - state.cursor.y - PADDING_BOTTOM,
			   },
		   )) {
		ok := load_combat_file(str(state.load_screen_state.selected_file))

		if ok {
			state.current_screen_state = state.setup_screen_state
		} else {
			new_message := MessageBoxState{}

			init_message_box(&new_message, "Error!", "Cannot load file!")
			add_message(&state.load_screen_state.message_queue, new_message)
		}
	}
}

get_current_dir_files :: proc() {
	file_list := rl.LoadDirectoryFiles(state.load_screen_state.current_dir)
	clear(&state.load_screen_state.dirs_list)
	clear(&state.load_screen_state.files_list)

	for i in 0 ..< file_list.count {
		if (rl.IsPathFile(file_list.paths[i])) {
			append(&state.load_screen_state.files_list, file_list.paths[i])
		} else {
			append(&state.load_screen_state.dirs_list, file_list.paths[i])
		}
	}
}
