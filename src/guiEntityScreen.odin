#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

draw_entity_screen :: proc() {
	using state.gui_properties

	state.cursor.x = PADDING_LEFT
	state.cursor.y = PADDING_TOP

	TEXT_SIZE = TEXT_SIZE_DEFAULT
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

	if (GuiButton(
			   {state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT},
			   "Back",
		   )) {
		state.entity_screen_state.first_load = true
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
		"Add Entity",
	)
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, initial_text_alignment)

	TEXT_SIZE = TEXT_SIZE_DEFAULT
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

	state.cursor.x = PADDING_LEFT
	state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

	current_panel_x := state.cursor.x
	panel_y := state.cursor.y

	panel_width := state.window_width / 3.5
	panel_height :=
		state.window_height -
		state.cursor.y -
		PADDING_BOTTOM -
		MENU_BUTTON_HEIGHT -
		MENU_BUTTON_PADDING
	dynamic_x_padding: f32 =
		((state.window_width - PADDING_LEFT - PADDING_RIGHT) - (3 * panel_width)) / 2

	if (state.entity_screen_state.first_load) {
		state.entity_screen_state.first_load = false
		state.entity_screen_state.panel_left.content_rec = {
			state.cursor.x,
			state.cursor.y,
			panel_width,
			0,
		}

		state.entity_screen_state.panel_mid.content_rec = {
			state.cursor.x,
			state.cursor.y,
			panel_width,
			0,
		}
	}

	scroll_locked := false

	for _, btn in state.entity_screen_state.btn_list {
		if btn^ {
			scroll_locked = true
		}
	}

	draw_width := panel_width - (PANEL_PADDING * 2)

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.entity_screen_state.panel_left,
		"Edit:",
	)
	state.cursor.x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
	state.cursor.y += PANEL_PADDING

	reset_left_x := state.cursor.x
	reset_left_y := state.cursor.y

	defer if GuiButton(
		{
			reset_left_x,
			reset_left_y,
			LINE_HEIGHT - (PANEL_PADDING * 2),
			LINE_HEIGHT - (PANEL_PADDING * 2),
		},
		&state.entity_screen_state.reset_button_left,
		rl.GuiIconText(.ICON_RESTART, ""),
	) {
		reload_entities()
		set_input_values(draw_width / 2, draw_width / 4)
	}
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y + LINE_HEIGHT + state.entity_screen_state.panel_left.scroll.y

	if (state.entity_screen_state.panel_left.height_needed >
		   state.entity_screen_state.panel_left.rec.height) {
		state.entity_screen_state.panel_left.content_rec.width = panel_width - 14
		state.entity_screen_state.panel_left.content_rec.height =
			state.entity_screen_state.panel_left.height_needed
		draw_width = panel_width - (PANEL_PADDING * 2) - 14

		rl.GuiScrollPanel(
			state.entity_screen_state.panel_left.rec,
			nil,
			state.entity_screen_state.panel_left.content_rec,
			&state.entity_screen_state.panel_left.scroll,
			&state.entity_screen_state.panel_left.view,
		)
		rl.BeginScissorMode(
			cast(i32)state.entity_screen_state.panel_left.view.x,
			cast(i32)state.entity_screen_state.panel_left.view.y,
			cast(i32)state.entity_screen_state.panel_left.view.width,
			cast(i32)state.entity_screen_state.panel_left.view.height,
		)
	} else {
		state.entity_screen_state.panel_left.content_rec.width = panel_width
		draw_width = panel_width - (PANEL_PADDING * 2)
	}
	//Panel contents
	{
		state.entity_screen_state.panel_left.height_needed = 0

		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_x := state.cursor.x
		start_y := state.cursor.y

		for i in 0 ..< state.num_custom_entities {
			entity := state.custom_entities[i]
			if GuiButton(
				{state.cursor.x, state.cursor.y, draw_width * 0.8, LINE_HEIGHT},
				entity.name,
			) {
				state.entity_screen_state.entity_to_edit = cast(i32)i
				state.entity_screen_state.entity_edit_mode = true
				set_input_values(draw_width / 2, draw_width / 4)
			}
			state.cursor.x += draw_width * 0.8

			if GuiButton(
				{state.cursor.x, state.cursor.y, draw_width / 5, LINE_HEIGHT},
				rl.GuiIconText(.ICON_BIN, ""),
			) {
				delete_custom_entity(cast(i32)i)
			}
			state.cursor.x = start_x
			state.cursor.y += LINE_HEIGHT + PANEL_PADDING
		}
		state.entity_screen_state.panel_left.height_needed =
			state.cursor.y + PANEL_PADDING - start_y
	}

	if (state.entity_screen_state.panel_left.height_needed >
		   state.entity_screen_state.panel_left.rec.height) {
		rl.EndScissorMode()
	} else {
		state.entity_screen_state.panel_left.scroll.y = 0
	}
	current_panel_x += panel_width + dynamic_x_padding
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.entity_screen_state.panel_mid,
		"Entity Options:",
	)

	state.cursor.x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
	state.cursor.y += PANEL_PADDING

	reset_mid_x := state.cursor.x
	reset_mid_y := state.cursor.y

	defer if GuiButton(
		{
			reset_mid_x,
			reset_mid_y,
			LINE_HEIGHT - (PANEL_PADDING * 2),
			LINE_HEIGHT - (PANEL_PADDING * 2),
		},
		&state.entity_screen_state.reset_button_mid,
		rl.GuiIconText(.ICON_RESTART, ""),
	) {
		state.entity_screen_state.entity_edit_mode = false
		set_input_values(draw_width / 2, draw_width / 4)
	}
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y + LINE_HEIGHT + state.entity_screen_state.panel_mid.scroll.y

	if (state.entity_screen_state.panel_mid.height_needed >
		   state.entity_screen_state.panel_mid.rec.height) {
		state.entity_screen_state.panel_mid.content_rec.width = panel_width - 14
		state.entity_screen_state.panel_mid.content_rec.height =
			state.entity_screen_state.panel_mid.height_needed
		draw_width = panel_width - (PANEL_PADDING * 2) - 14

		if !scroll_locked {
			rl.GuiScrollPanel(
				state.entity_screen_state.panel_mid.rec,
				nil,
				state.entity_screen_state.panel_mid.content_rec,
				&state.entity_screen_state.panel_mid.scroll,
				&state.entity_screen_state.panel_mid.view,
			)
		}

		rl.BeginScissorMode(
			cast(i32)state.entity_screen_state.panel_mid.view.x,
			cast(i32)state.entity_screen_state.panel_mid.view.y,
			cast(i32)state.entity_screen_state.panel_mid.view.width,
			cast(i32)state.entity_screen_state.panel_mid.view.height,
		)
	} else {
		state.entity_screen_state.panel_mid.content_rec.width = panel_width
		draw_width = panel_width - (PANEL_PADDING * 2)
	}
	//Panel content
	{
		state.entity_screen_state.panel_mid.height_needed = 0

		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_x := state.cursor.x
		start_y := state.cursor.y

		text_align_left()

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Name:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.name_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Race:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.race_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Size:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.size_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Type:")
		state.cursor.x += draw_width / 2

		dropdown_cursor_x := state.cursor.x
		dropdown_cursor_y := state.cursor.y

		GuiDropdownControl(
			{dropdown_cursor_x, dropdown_cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.type_dropdown,
		)
		register_button(
			&state.entity_screen_state.btn_list,
			&state.entity_screen_state.type_dropdown,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "AC:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.AC_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "HP max:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.HP_max_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			"Current HP:",
		)
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.HP_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Temp HP:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.temp_HP_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Speed:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.speed_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_center()

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Ability")
		state.cursor.x += draw_width / 4
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Score")
		state.cursor.x += draw_width / 4
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Mod")
		state.cursor.x += draw_width / 4
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Save")
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "STR:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.STR_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod := get_modifier(to_i32(state.entity_screen_state.STR_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.STR_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "DEX:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.DEX_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod = get_modifier(to_i32(state.entity_screen_state.DEX_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.DEX_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "CON:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.CON_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod = get_modifier(to_i32(state.entity_screen_state.CON_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.CON_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "INT:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.INT_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod = get_modifier(to_i32(state.entity_screen_state.INT_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.INT_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "WIS:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.WIS_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod = get_modifier(to_i32(state.entity_screen_state.WIS_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.WIS_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		text_align_left()
		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT}, "CHA:")
		state.cursor.x += draw_width / 4
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.CHA_input,
		)
		state.cursor.x += draw_width / 4
		text_align_center()
		mod = get_modifier(to_i32(state.entity_screen_state.CHA_input.text))
		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			fmt.ctprintf("+%v" if mod >= 0 else "%v", mod),
		)
		state.cursor.x += draw_width / 4
		text_align_left()
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 4, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.CHA_save_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			"Vulnerabilities:",
		)
		state.cursor.x += draw_width / 2

		dropdown_cursor_x_vuln := state.cursor.x
		dropdown_cursor_y_vuln := state.cursor.y
		GuiDropdownSelectControl(
			{dropdown_cursor_x_vuln, dropdown_cursor_y_vuln, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.DMG_vulnerable_input,
		)
		register_button(
			&state.entity_screen_state.btn_list,
			&state.entity_screen_state.DMG_vulnerable_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		if (state.entity_screen_state.panel_mid.height_needed >
			   state.entity_screen_state.panel_mid.rec.height) {
			rl.BeginScissorMode(
				cast(i32)state.entity_screen_state.panel_mid.view.x,
				cast(i32)state.entity_screen_state.panel_mid.view.y,
				cast(i32)state.entity_screen_state.panel_mid.view.width,
				cast(i32)state.entity_screen_state.panel_mid.view.height,
			)
		}

		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			"Resistances:",
		)
		state.cursor.x += draw_width / 2

		dropdown_cursor_x_resist := state.cursor.x
		dropdown_cursor_y_resist := state.cursor.y

		GuiDropdownSelectControl(
			{
				dropdown_cursor_x_resist,
				dropdown_cursor_y_resist,
				draw_width / 2,
				TEXT_INPUT_HEIGHT,
			},
			&state.entity_screen_state.DMG_resist_input,
		)
		register_button(
			&state.entity_screen_state.btn_list,
			&state.entity_screen_state.DMG_resist_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		if (state.entity_screen_state.panel_mid.height_needed >
			   state.entity_screen_state.panel_mid.rec.height) {
			rl.BeginScissorMode(
				cast(i32)state.entity_screen_state.panel_mid.view.x,
				cast(i32)state.entity_screen_state.panel_mid.view.y,
				cast(i32)state.entity_screen_state.panel_mid.view.width,
				cast(i32)state.entity_screen_state.panel_mid.view.height,
			)
		}

		GuiLabel(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			"Immunities:",
		)
		state.cursor.x += draw_width / 2

		dropdown_cursor_x_immune := state.cursor.x
		dropdown_cursor_y_immune := state.cursor.y
		GuiDropdownSelectControl(
			{
				dropdown_cursor_x_immune,
				dropdown_cursor_y_immune,
				draw_width / 2,
				TEXT_INPUT_HEIGHT,
			},
			&state.entity_screen_state.DMG_immune_input,
		)
		register_button(
			&state.entity_screen_state.btn_list,
			&state.entity_screen_state.DMG_immune_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		if (state.entity_screen_state.panel_mid.height_needed >
			   state.entity_screen_state.panel_mid.rec.height) {
			rl.BeginScissorMode(
				cast(i32)state.entity_screen_state.panel_mid.view.x,
				cast(i32)state.entity_screen_state.panel_mid.view.y,
				cast(i32)state.entity_screen_state.panel_mid.view.width,
				cast(i32)state.entity_screen_state.panel_mid.view.height,
			)
		}

		GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Languages:")
		state.cursor.x += draw_width / 2
		GuiTextInput(
			{state.cursor.x, state.cursor.y, draw_width / 2, TEXT_INPUT_HEIGHT},
			&state.entity_screen_state.languages_input,
		)
		state.cursor.x = start_x
		state.cursor.y += TEXT_INPUT_HEIGHT + PANEL_PADDING

		state.entity_screen_state.panel_mid.height_needed =
			state.cursor.y + PANEL_PADDING - start_y
	}

	if (state.entity_screen_state.panel_mid.height_needed >
		   state.entity_screen_state.panel_mid.rec.height) {
		rl.EndScissorMode()
	} else {
		state.entity_screen_state.panel_mid.scroll.y = 0
	}
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y + panel_height + MENU_BUTTON_PADDING

	if GuiButton(
		{state.cursor.x, state.cursor.y, panel_width, MENU_BUTTON_HEIGHT},
		"Add" if (!state.entity_screen_state.entity_edit_mode) else "Save",
	) {
		entity_type: EntityType
		switch state.entity_screen_state.type_dropdown.labels[state.entity_screen_state.type_dropdown.selected] {
		case "Player":
			entity_type = .PLAYER
		case "NPC":
			entity_type = .NPC
		case "Monster":
			entity_type = .MONSTER
		}

		vulnerabilities: [dynamic]string
		defer delete(vulnerabilities)
		for check_box_state in state.entity_screen_state.DMG_vulnerable_input.check_box_states {
			if check_box_state.toggle^ {
				append(&vulnerabilities, str(check_box_state.text))
			}
		}

		resistances: [dynamic]string
		defer delete(resistances)
		for check_box_state in state.entity_screen_state.DMG_resist_input.check_box_states {
			if check_box_state.toggle^ {
				append(&resistances, str(check_box_state.text))
			}
		}

		immunities: [dynamic]string
		defer delete(immunities)
		for check_box_state in state.entity_screen_state.DMG_immune_input.check_box_states {
			if check_box_state.toggle^ {
				append(&immunities, str(check_box_state.text))
			}
		}

		_, icon_data := get_entity_icon_data(
			cstr(
				state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
			),
			cstr(
				state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
			),
		)

		new_entity := Entity {
			state.entity_screen_state.name_input.text,
			state.entity_screen_state.name_input.text,
			state.entity_screen_state.race_input.text,
			state.entity_screen_state.size_input.text,
			entity_type,
			0,
			to_i32(state.entity_screen_state.AC_input.text),
			to_i32(state.entity_screen_state.HP_max_input.text),
			to_i32(state.entity_screen_state.HP_input.text),
			to_i32(state.entity_screen_state.temp_HP_input.text),
			{},
			true,
			true,
			state.entity_screen_state.speed_input.text,
			to_i32(state.entity_screen_state.STR_input.text),
			get_modifier(to_i32(state.entity_screen_state.STR_input.text)),
			to_i32(state.entity_screen_state.STR_save_input.text),
			to_i32(state.entity_screen_state.DEX_input.text),
			get_modifier(to_i32(state.entity_screen_state.DEX_input.text)),
			to_i32(state.entity_screen_state.DEX_save_input.text),
			to_i32(state.entity_screen_state.CON_input.text),
			get_modifier(to_i32(state.entity_screen_state.CON_input.text)),
			to_i32(state.entity_screen_state.CON_save_input.text),
			to_i32(state.entity_screen_state.INT_input.text),
			get_modifier(to_i32(state.entity_screen_state.INT_input.text)),
			to_i32(state.entity_screen_state.INT_save_input.text),
			to_i32(state.entity_screen_state.WIS_input.text),
			get_modifier(to_i32(state.entity_screen_state.WIS_input.text)),
			to_i32(state.entity_screen_state.WIS_save_input.text),
			to_i32(state.entity_screen_state.CHA_input.text),
			get_modifier(to_i32(state.entity_screen_state.CHA_input.text)),
			to_i32(state.entity_screen_state.CHA_save_input.text),
			"",
			get_vulnerabilities_resistances_or_immunities(vulnerabilities[:]),
			{},
			get_vulnerabilities_resistances_or_immunities(resistances[:]),
			{},
			get_vulnerabilities_resistances_or_immunities(immunities[:]),
			{},
			get_conditions(strings.split(string(""), ", ")),
			"",
			state.entity_screen_state.languages_input.text,
			"",
			"",
			"",
			"",
			cstr(state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index]) if len(state.entity_screen_state.img_file_paths) > 0 else "",
			cstr(state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index]) if len(state.entity_screen_state.border_file_paths) > 0 else "",
			icon_data,
		}

		fmt.println(state.entity_screen_state.STR_input.text)
		fmt.println(to_i32(state.entity_screen_state.STR_input.text))

		if !state.entity_screen_state.entity_edit_mode {
			add_entity_to_file(new_entity, state.config.CUSTOM_ENTITY_FILE_PATH)
		} else {
			//Edit file. Re-write whole file with current entity being replaced.
			fmt.println("New STR:", new_entity.STR)
			state.custom_entities[state.entity_screen_state.entity_to_edit] = new_entity
			fmt.println(
				"In list:",
				state.custom_entities[state.entity_screen_state.entity_to_edit].STR,
			)
			for i in 0 ..< state.num_custom_entities {
				entity := state.custom_entities[i]
				fmt.println(entity.name, entity.STR)
				if i == 0 {
					add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH, wipe = true)
				} else {
					add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH)
				}
			}
		}
		reload_entities()
		state.entity_screen_state.entity_edit_mode = false
		set_input_values(draw_width / 2, draw_width / 4)
	}
	current_panel_x += panel_width + dynamic_x_padding
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.entity_screen_state.panel_right,
		"Icon Options:",
	)
	state.cursor.x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
	state.cursor.y += PANEL_PADDING

	reset_right_x := state.cursor.x
	reset_right_y := state.cursor.y

	defer if GuiButton(
		{
			reset_right_x,
			reset_right_y,
			LINE_HEIGHT - (PANEL_PADDING * 2),
			LINE_HEIGHT - (PANEL_PADDING * 2),
		},
		&state.entity_screen_state.reset_button_right,
		rl.GuiIconText(.ICON_RESTART, ""),
	) {
		reload_icons_and_borders()
		state.entity_screen_state.combined_image, _ = get_entity_icon_data(
			cstr(
				state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
			),
			cstr(
				state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
			),
		)
	}
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y + LINE_HEIGHT + state.entity_screen_state.panel_right.scroll.y
	//Panel contents
	{
		state.entity_screen_state.panel_right.height_needed = 0

		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_x := state.cursor.x
		start_y := state.cursor.y

		if len(state.entity_screen_state.icons) > 0 {
			if GuiButton(
				{state.cursor.x, state.cursor.y, PANEL_PADDING * 3, 128},
				rl.GuiIconText(.ICON_ARROW_LEFT_FILL, ""),
			) {
				if state.entity_screen_state.current_border_index >= 1 {
					state.entity_screen_state.current_border_index -= 1
				} else {
					state.entity_screen_state.current_border_index =
						cast(i32)len(state.entity_screen_state.borders) - 1
				}
				state.entity_screen_state.combined_image, _ = get_entity_icon_data(
					cstr(
						state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
					),
					cstr(
						state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
					),
				)
			}
			state.cursor.x = start_x - PANEL_PADDING + (panel_width / 2) - 64

			display_img := rl.LoadImageFromTexture(state.entity_screen_state.combined_image)
			rl.ImageResize(&display_img, 128, 128)
			draw_texture := rl.LoadTextureFromImage(display_img)
			rl.DrawTexture(
				draw_texture,
				cast(i32)state.cursor.x,
				cast(i32)state.cursor.y,
				rl.WHITE,
			)
			state.cursor.x = start_x + draw_width + PANEL_PADDING - (PANEL_PADDING * 3)

			rl.UnloadImage(display_img)

			if GuiButton(
				{state.cursor.x, state.cursor.y, PANEL_PADDING * 3, 128},
				rl.GuiIconText(.ICON_ARROW_RIGHT_FILL, ""),
			) {
				if state.entity_screen_state.current_border_index <
				   cast(i32)len(state.entity_screen_state.borders) - 1 {
					state.entity_screen_state.current_border_index += 1
				} else {
					state.entity_screen_state.current_border_index = 0
				}
				state.entity_screen_state.combined_image, _ = get_entity_icon_data(
					cstr(
						state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
					),
					cstr(
						state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
					),
				)
			}
			state.cursor.x = start_x
			state.cursor.y +=
				cast(f32)state.entity_screen_state.icons[state.entity_screen_state.current_icon_index].height +
				PANEL_PADDING

			if GuiButton({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Prev") {
				if state.entity_screen_state.current_icon_index >= 1 {
					state.entity_screen_state.current_icon_index -= 1
				} else {
					state.entity_screen_state.current_icon_index =
						cast(i32)len(state.entity_screen_state.icons) - 1
				}
				state.entity_screen_state.combined_image, _ = get_entity_icon_data(
					cstr(
						state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
					),
					cstr(
						state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
					),
				)
			}
			state.cursor.x += draw_width / 2 + PANEL_PADDING

			if GuiButton({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Next") {
				if state.entity_screen_state.current_icon_index <
				   cast(i32)len(state.entity_screen_state.icons) - 1 {
					state.entity_screen_state.current_icon_index += 1
				} else {
					state.entity_screen_state.current_icon_index = 0
				}
				state.entity_screen_state.combined_image, _ = get_entity_icon_data(
					cstr(
						state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
					),
					cstr(
						state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
					),
				)
			}
			state.cursor.x = start_x
			state.cursor.y += LINE_HEIGHT + PANEL_PADDING

			GuiLabel({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT / 1.5}, "Image Dir:")
			state.cursor.y += (LINE_HEIGHT / 1.5) + PANEL_PADDING
			GuiLabel(
				{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT / 1.5},
				cstr(state.config.CUSTOM_ENTITIES_DIR, "images", sep = ""),
			)
			state.cursor.y += (LINE_HEIGHT / 1.5) + PANEL_PADDING

			GuiLabel(
				{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT / 1.5},
				"Border Dir:",
			)
			state.cursor.y += (LINE_HEIGHT / 1.5) + PANEL_PADDING
			GuiLabel(
				{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT / 1.5},
				cstr(state.app_dir, FILE_SEPERATOR, "borders", sep = ""),
			)
		} else {
			GuiLabel({state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT}, "No images found")
		}
	}
}

@(private)
set_input_values :: proc(half_width: f32, quater_width: f32) {
	if state.entity_screen_state.entity_edit_mode {
		entity := state.custom_entities[state.entity_screen_state.entity_to_edit]
		set_text_input(&state.entity_screen_state.name_input, cstr(entity.name), half_width)
		set_text_input(&state.entity_screen_state.race_input, cstr(entity.race), half_width)
		set_text_input(&state.entity_screen_state.size_input, cstr(entity.size), half_width)

		switch entity.type {
		case .PLAYER:
			state.entity_screen_state.type_dropdown.selected = 0
		case .NPC:
			state.entity_screen_state.type_dropdown.selected = 1
		case .MONSTER:
			state.entity_screen_state.type_dropdown.selected = 2
		}

		set_text_input(&state.entity_screen_state.AC_input, cstr(entity.AC), half_width)
		set_text_input(&state.entity_screen_state.HP_max_input, cstr(entity.HP_max), half_width)
		set_text_input(&state.entity_screen_state.HP_input, cstr(entity.HP), half_width)
		set_text_input(&state.entity_screen_state.temp_HP_input, cstr(entity.temp_HP), half_width)

		set_text_input(&state.entity_screen_state.STR_input, cstr(entity.STR), quater_width)
		set_text_input(
			&state.entity_screen_state.STR_save_input,
			cstr(entity.STR_save),
			quater_width,
		)
		set_text_input(&state.entity_screen_state.DEX_input, cstr(entity.DEX), quater_width)
		set_text_input(
			&state.entity_screen_state.DEX_save_input,
			cstr(entity.DEX_save),
			quater_width,
		)
		set_text_input(&state.entity_screen_state.CON_input, cstr(entity.CON), quater_width)
		set_text_input(
			&state.entity_screen_state.CON_save_input,
			cstr(entity.CON_save),
			quater_width,
		)
		set_text_input(&state.entity_screen_state.INT_input, cstr(entity.INT), quater_width)
		set_text_input(
			&state.entity_screen_state.INT_save_input,
			cstr(entity.INT_save),
			quater_width,
		)
		set_text_input(&state.entity_screen_state.WIS_input, cstr(entity.WIS), quater_width)
		set_text_input(
			&state.entity_screen_state.WIS_save_input,
			cstr(entity.WIS_save),
			quater_width,
		)
		set_text_input(&state.entity_screen_state.CHA_input, cstr(entity.CHA), quater_width)
		set_text_input(
			&state.entity_screen_state.CHA_save_input,
			cstr(entity.CHA_save),
			quater_width,
		)

		for vulnerability in entity.dmg_vulnerabilities {
			switch vulnerability {
			case .ANY:
			case .SLASHING:
				state.entity_screen_state.DMG_vulnerable_input.selected[0] = true
			case .PIERCING:
				state.entity_screen_state.DMG_vulnerable_input.selected[1] = true
			case .BLUDGEONING:
				state.entity_screen_state.DMG_vulnerable_input.selected[2] = true
			case .NON_MAGICAL:
				state.entity_screen_state.DMG_vulnerable_input.selected[3] = true
			case .POISON:
				state.entity_screen_state.DMG_vulnerable_input.selected[4] = true
			case .ACID:
				state.entity_screen_state.DMG_vulnerable_input.selected[5] = true
			case .FIRE:
				state.entity_screen_state.DMG_vulnerable_input.selected[6] = true
			case .COLD:
				state.entity_screen_state.DMG_vulnerable_input.selected[7] = true
			case .RADIANT:
				state.entity_screen_state.DMG_vulnerable_input.selected[8] = true
			case .NECROTIC:
				state.entity_screen_state.DMG_vulnerable_input.selected[9] = true
			case .LIGHTNING:
				state.entity_screen_state.DMG_vulnerable_input.selected[10] = true
			case .THUNDER:
				state.entity_screen_state.DMG_vulnerable_input.selected[11] = true
			case .FORCE:
				state.entity_screen_state.DMG_vulnerable_input.selected[12] = true
			case .PSYCHIC:
				state.entity_screen_state.DMG_vulnerable_input.selected[13] = true
			}
		}

		for resistance in entity.dmg_vulnerabilities {
			switch resistance {
			case .ANY:
			case .SLASHING:
				state.entity_screen_state.DMG_resist_input.selected[0] = true
			case .PIERCING:
				state.entity_screen_state.DMG_resist_input.selected[1] = true
			case .BLUDGEONING:
				state.entity_screen_state.DMG_resist_input.selected[2] = true
			case .NON_MAGICAL:
				state.entity_screen_state.DMG_resist_input.selected[3] = true
			case .POISON:
				state.entity_screen_state.DMG_resist_input.selected[4] = true
			case .ACID:
				state.entity_screen_state.DMG_resist_input.selected[5] = true
			case .FIRE:
				state.entity_screen_state.DMG_resist_input.selected[6] = true
			case .COLD:
				state.entity_screen_state.DMG_resist_input.selected[7] = true
			case .RADIANT:
				state.entity_screen_state.DMG_resist_input.selected[8] = true
			case .NECROTIC:
				state.entity_screen_state.DMG_resist_input.selected[9] = true
			case .LIGHTNING:
				state.entity_screen_state.DMG_resist_input.selected[10] = true
			case .THUNDER:
				state.entity_screen_state.DMG_resist_input.selected[11] = true
			case .FORCE:
				state.entity_screen_state.DMG_resist_input.selected[12] = true
			case .PSYCHIC:
				state.entity_screen_state.DMG_resist_input.selected[13] = true
			}
		}

		for immunity in entity.dmg_vulnerabilities {
			switch immunity {
			case .ANY:
			case .SLASHING:
				state.entity_screen_state.DMG_immune_input.selected[0] = true
			case .PIERCING:
				state.entity_screen_state.DMG_immune_input.selected[1] = true
			case .BLUDGEONING:
				state.entity_screen_state.DMG_immune_input.selected[2] = true
			case .NON_MAGICAL:
				state.entity_screen_state.DMG_immune_input.selected[3] = true
			case .POISON:
				state.entity_screen_state.DMG_immune_input.selected[4] = true
			case .ACID:
				state.entity_screen_state.DMG_immune_input.selected[5] = true
			case .FIRE:
				state.entity_screen_state.DMG_immune_input.selected[6] = true
			case .COLD:
				state.entity_screen_state.DMG_immune_input.selected[7] = true
			case .RADIANT:
				state.entity_screen_state.DMG_immune_input.selected[8] = true
			case .NECROTIC:
				state.entity_screen_state.DMG_immune_input.selected[9] = true
			case .LIGHTNING:
				state.entity_screen_state.DMG_immune_input.selected[10] = true
			case .THUNDER:
				state.entity_screen_state.DMG_immune_input.selected[11] = true
			case .FORCE:
				state.entity_screen_state.DMG_immune_input.selected[12] = true
			case .PSYCHIC:
				state.entity_screen_state.DMG_immune_input.selected[13] = true
			}
		}

		set_text_input(
			&state.entity_screen_state.languages_input,
			cstr(entity.languages),
			half_width,
		)
		for file_path, i in state.entity_screen_state.img_file_paths {
			if cstr(file_path) == entity.img_url {
				state.entity_screen_state.current_icon_index = cast(i32)i
			}
		}
		for file_path, i in state.entity_screen_state.border_file_paths {
			if cstr(file_path) == entity.img_border {
				state.entity_screen_state.current_border_index = cast(i32)i
			}
		}
		state.entity_screen_state.combined_image, _ = get_entity_icon_data(
			cstr(
				state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
			),
			cstr(
				state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
			),
		)
	} else {
		//Set everything to default options. Will happen when some clear button is clicked.
		clear_text_input(&state.entity_screen_state.name_input)
		clear_text_input(&state.entity_screen_state.race_input)
		clear_text_input(&state.entity_screen_state.size_input)
		clear_text_input(&state.entity_screen_state.AC_input)
		clear_text_input(&state.entity_screen_state.HP_max_input)
		clear_text_input(&state.entity_screen_state.HP_input)
		clear_text_input(&state.entity_screen_state.temp_HP_input)
		clear_text_input(&state.entity_screen_state.STR_input)
		clear_text_input(&state.entity_screen_state.STR_save_input)
		clear_text_input(&state.entity_screen_state.DEX_input)
		clear_text_input(&state.entity_screen_state.DEX_save_input)
		clear_text_input(&state.entity_screen_state.CON_input)
		clear_text_input(&state.entity_screen_state.CON_save_input)
		clear_text_input(&state.entity_screen_state.INT_input)
		clear_text_input(&state.entity_screen_state.INT_save_input)
		clear_text_input(&state.entity_screen_state.WIS_input)
		clear_text_input(&state.entity_screen_state.WIS_save_input)
		clear_text_input(&state.entity_screen_state.CHA_input)
		clear_text_input(&state.entity_screen_state.CHA_save_input)
		clear_text_input(&state.entity_screen_state.languages_input)

		rl.UnloadTexture(state.entity_screen_state.combined_image)
		state.entity_screen_state.type_dropdown.selected = 0

		for _, i in state.entity_screen_state.DMG_vulnerable_input.selected {
			state.entity_screen_state.DMG_vulnerable_input.selected[i] = false
			state.entity_screen_state.DMG_resist_input.selected[i] = false
			state.entity_screen_state.DMG_immune_input.selected[i] = false
		}

		state.entity_screen_state.current_icon_index = 0
		state.entity_screen_state.current_border_index = 0
		state.entity_screen_state.combined_image, _ = get_entity_icon_data(
			cstr(
				state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
			),
			cstr(
				state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
			),
		)
	}
}

@(private)
delete_custom_entity :: proc(index: i32) {
	for i in cast(int)index ..< len(state.custom_entities) - 1 {
		state.custom_entities[i] = state.custom_entities[i + 1]
	}

	state.num_custom_entities -= 1

	for i in 0 ..< state.num_custom_entities {
		entity := state.custom_entities[i]
		if i == 0 {
			add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH, wipe = true)
		} else {
			add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH)
		}
	}
}

reload_icons_and_borders :: proc() {
	vmem.arena_free_all(&icons_arena)
	reload_icons()
	reload_borders()
}

reload_icons :: proc() {
	context.allocator = icons_alloc
	for texture in state.entity_screen_state.icons {
		rl.UnloadTexture(texture)
	}

	delete(state.entity_screen_state.icons)
	delete(state.entity_screen_state.img_file_paths)

	temp_path_list := [dynamic]string{}
	defer delete(temp_path_list)
	dir_handle, ok := os.open(
		fmt.tprint(state.config.CUSTOM_ENTITIES_DIR, "images", sep = FILE_SEPERATOR),
	)
	defer os.close(dir_handle)
	file_infos, err := os.read_dir(dir_handle, 0)
	defer delete(file_infos)

	for file in file_infos {
		if !file.is_dir {
			if strings.split(file.name, ".", allocator = frame_alloc)[1] == "png" {
				append(&temp_path_list, file.name)
			}
		}
	}
	state.entity_screen_state.img_file_paths = slice.clone(temp_path_list[:])

	temp_texture_list := [dynamic]rl.Texture{}
	defer delete(temp_texture_list)
	for img_path in state.entity_screen_state.img_file_paths {
		temp_img := rl.LoadImage(
			cstr(state.config.CUSTOM_ENTITIES_DIR, "images", img_path, sep = FILE_SEPERATOR),
		)

		if (temp_img.width != 128) || (temp_img.height != 128) {
			rl.ImageResize(&temp_img, 128, 128)
		}
		texture := rl.LoadTextureFromImage(temp_img)
		append(&temp_texture_list, texture)
		rl.UnloadImage(temp_img)
		rl.UnloadTexture(texture)
	}
	state.entity_screen_state.icons = slice.clone(temp_texture_list[:])

	state.entity_screen_state.current_icon_index = 0
	log.infof("Icons reloaded!")
	context.allocator = static_alloc
}

reload_borders :: proc() {
	context.allocator = icons_alloc
	for texture in state.entity_screen_state.borders {
		rl.UnloadTexture(texture)
	}

	delete(state.entity_screen_state.borders)
	delete(state.entity_screen_state.border_file_paths)

	temp_path_list := [dynamic]string{}
	defer delete(temp_path_list)
	dir_handle, ok := os.open(
		fmt.tprint(state.config.CUSTOM_ENTITIES_DIR, "..", "borders", sep = FILE_SEPERATOR),
	)
	defer os.close(dir_handle)
	file_infos, err := os.read_dir(dir_handle, 0)
	defer delete(file_infos)

	for file in file_infos {
		if !file.is_dir {
			if strings.split(file.name, ".", allocator = frame_alloc)[1] == "png" {
				append(&temp_path_list, file.name)
			}
		}
	}
	state.entity_screen_state.border_file_paths = slice.clone(temp_path_list[:])

	temp_texture_list := [dynamic]rl.Texture{}
	defer delete(temp_texture_list)
	for border_path in state.entity_screen_state.border_file_paths {
		temp_border := rl.LoadImage(
			cstr(state.config.CUSTOM_ENTITIES_DIR, "..", "borders", sep = FILE_SEPERATOR),
		)

		if (temp_border.width != 128) || (temp_border.height != 128) {
			rl.ImageResize(&temp_border, 128, 128)
		}
		texture := rl.LoadTextureFromImage(temp_border)
		append(&temp_texture_list, texture)
		rl.UnloadImage(temp_border)
		rl.UnloadTexture(texture)
	}
	state.entity_screen_state.borders = slice.clone(temp_texture_list[:])
	state.entity_screen_state.current_border_index = 0

	log.infof("Borders reloaded!")
	context.allocator = static_alloc
}
