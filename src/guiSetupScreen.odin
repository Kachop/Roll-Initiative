package main

import "core:fmt"
import "core:log"
import "core:os/os2"
import "core:strings"
import "core:thread"
import rl "vendor:raylib"

draw_setup_screen :: proc() {
	using state.gui_properties

	defer GuiMessageBoxQueue(&state.setup_screen_state.message_queue)

	state.cursor.x = PADDING_LEFT
	state.cursor.y = PADDING_TOP

	start_x := state.cursor.x

	if (FRAME == 59) && state.server_state.running {
		party_to_json()
	}

	set_text_size(TEXT_SIZE_DEFAULT)
	text_align_center()

	defer if state.setup_screen_state.popup_toggled {
		popup_bounds := rl.Rectangle {
			(state.window_width / 2) - (POPUP_WIDTH / 2),
			(state.window_height / 2) - (POPUP_HEIGHT / 2),
			POPUP_WIDTH,
			POPUP_HEIGHT,
		}

		switch GuiPopup(popup_bounds, &state.setup_screen_state.long_rest_popup) {
		case 0:
			state.setup_screen_state.popup_toggled = false
		case 1:
			long_rest()
			state.setup_screen_state.popup_toggled = false
		}
	}

	if GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back") {
		state.setup_screen_state.first_load = true
		state.current_screen_state = state.title_screen_state
		return
	}
	state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

	if GuiButton(
		{state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT},
		"",
		rl.GuiIconName.ICON_FILE_OPEN,
	) {
		state.current_screen_state = state.load_screen_state
		return
	}
	state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

	set_text_size(TEXT_SIZE_TITLE)

	title_width :=
		state.window_width -
		(MENU_BUTTON_WIDTH * 4) -
		(MENU_BUTTON_PADDING * 4) -
		PADDING_LEFT -
		PADDING_RIGHT
	GuiLabel({state.cursor.x, state.cursor.y, title_width, MENU_BUTTON_HEIGHT}, "Camp Fire")
	state.cursor.x += title_width + MENU_BUTTON_PADDING

	set_text_size(TEXT_SIZE_DEFAULT)

	if GuiButton(
		{state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT},
		"",
		rl.GuiIconName.ICON_FILE_SAVE,
	) {
		new_message := MessageBoxState{}

		if save_combat_file(
			str(
				state.config.COMBAT_FILES_DIR,
				FILE_SEPERATOR,
				state.setup_screen_state.filename_input.text,
				".combat",
				sep = "",
			),
		) {
			init_message_box(
				&new_message,
				"Notification",
				fmt.caprint(
					state.setup_screen_state.filename_input.text,
					".combat saved!",
					sep = "",
				),
			)
			add_message(&state.setup_screen_state.message_queue, new_message)
		} else {
			log.errorf(
				"Error with file, path: %v",
				str(
					state.config.COMBAT_FILES_DIR,
					FILE_SEPERATOR,
					state.setup_screen_state.filename_input.text,
					".combat",
					sep = "",
				),
			)
			init_message_box(&new_message, "Error!", "Failed to save file.")
			add_message(&state.setup_screen_state.message_queue, new_message)
		}
	}
	state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

	if GuiButton(
		{state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT},
		"",
		rl.GuiIconName.ICON_PLAYER_PLAY,
	) {
		if state.setup_screen_state.num_party > 0 && state.setup_screen_state.num_enemies > 0 {
			for i in 0 ..< state.setup_screen_state.num_party {
				entity := &state.setup_screen_state.party_selected[i]
				if (entity.initiative == 0) {
					entity_roll_initiative(entity)
				}
				state.combat_screen_state.entities[i] = entity^
			}

			for i in 0 ..< state.setup_screen_state.num_enemies {
				entity := &state.setup_screen_state.enemies_selected[i]
				if (entity.initiative == 0) {
					entity_roll_initiative(entity)
				}
				state.combat_screen_state.entities[state.setup_screen_state.num_party + i] =
				entity^
			}
			state.combat_screen_state.num_entities =
				state.setup_screen_state.num_party + state.setup_screen_state.num_enemies
			order_by_initiative(
				&state.combat_screen_state.entities,
				state.combat_screen_state.num_entities,
			)

			state.combat_screen_state.current_entity_idx = 0
			state.combat_screen_state.current_entity =
			&state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]
			state.combat_screen_state.view_entity_idx = 0
			state.combat_screen_state.view_entity =
			&state.combat_screen_state.entities[state.combat_screen_state.view_entity_idx]

			for i in 0 ..< state.combat_screen_state.num_entities {
				entity_button_state := new(EntityButtonState)
				init_entity_button_state(
					entity_button_state,
					&state.combat_screen_state.entities[i],
					&state.combat_screen_state.entity_button_states,
					i,
				)
				append(&state.combat_screen_state.entity_button_states, entity_button_state^)
			}
			state.current_screen_state = state.combat_screen_state
		} else {
			new_message := MessageBoxState{}

			if state.setup_screen_state.num_party == 0 &&
			   state.setup_screen_state.num_enemies == 0 {
				init_message_box(&new_message, "Warning!", "No combatants added")
			} else if state.setup_screen_state.num_party == 0 {
				init_message_box(&new_message, "Warning!", "Party is empty")
			} else if state.setup_screen_state.num_enemies == 0 {
				init_message_box(&new_message, "Warning!", "Add some enemies")
			}
			add_message(&state.setup_screen_state.message_queue, new_message)
		}
	}
	state.cursor.x = start_x
	state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

	panel_width := (state.window_width - (PADDING_LEFT * 2) - (PADDING_RIGHT * 2)) / 3
	draw_width := panel_width
	dynamic_x_padding :=
		(state.window_width - PADDING_LEFT - PADDING_RIGHT - (3 * panel_width)) / 2

	GuiLabel({state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT}, "Combat name:")
	state.cursor.x += panel_width / 2
	GuiTextInput(
		{state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT},
		&state.setup_screen_state.filename_input,
	)
	state.cursor.x += (panel_width / 2) + dynamic_x_padding

	if GuiButton({state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT}, "Short Rest") {}
	state.cursor.x += panel_width / 2

	if GuiButton({state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT}, "Long Rest") {
		//Loop over all entities in the party and heal them all to full and remove any conditions, temp vulnerabilities, etc.
		state.setup_screen_state.popup_toggled = true
		options := make([]cstring, 2)
		options[0] = "No"
		options[1] = "Yes"
		init_popup(
			&state.setup_screen_state.long_rest_popup,
			"Are you sure you want to long rest?",
			options,
		)
		return
	}
	state.cursor.x += (panel_width / 2) + dynamic_x_padding

	if GuiButton(
		{state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT},
		"Launch player-view",
	) {
		if !state.server_state.running {
			log.infof("Started webserver @: http://%v:%v", state.ip_str, state.config.PORT)
			server_thread = thread.create_and_start(run_combat_server)
			state.server_state.running = true
		}

		new_message := MessageBoxState{}

		web_addr := fmt.tprintf("http://%v:%v", state.ip_str, state.config.PORT)

		p, err := os2.process_start({command = {BROWSER_COMMAND, web_addr}})

		if err != nil {
			init_message_box(&new_message, "Error!", fmt.caprintf("Error launching player-view"))
			add_message(&state.setup_screen_state.message_queue, new_message)
		}

		_, err = os2.process_wait(p)

		if err != nil {
			init_message_box(
				&new_message,
				"Error!",
				fmt.caprintf("Error launching player-view\nGo to: %v", web_addr),
			)
			add_message(&state.setup_screen_state.message_queue, new_message)
		}

		log.debugf("Error launching browser: %v", err)
	}

	state.cursor.x = start_x
	state.cursor.y += LINE_HEIGHT + PANEL_PADDING

	current_panel_x := state.cursor.x
	panel_y := state.cursor.y

	panel_height := state.window_height - state.cursor.y - PADDING_BOTTOM
	draw_height := panel_height

	if state.setup_screen_state.first_load {
		state.setup_screen_state.first_load = false
	}

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.setup_screen_state.panel_left,
		"Available combatants",
	)
	state.setup_screen_state.panel_left.rec.y += LINE_HEIGHT
	state.setup_screen_state.panel_left.rec.height -= LINE_HEIGHT

	switch GuiTabControl(
		{state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT},
		&state.setup_screen_state.search_tab,
	) {
	case 0:
		state.setup_screen_state.entities_filtered = state.custom_entities
		state.setup_screen_state.num_entities_filtered = state.num_custom_entities
	case 1:
		state.setup_screen_state.entities_filtered = state.srd_entities
		state.setup_screen_state.num_entities_filtered = state.num_srd_entities
	}
	state.cursor.y += LINE_HEIGHT

	GuiLabel(
		{state.cursor.x, state.cursor.y, panel_width * 0.2, LINE_HEIGHT},
		rl.GuiIconText(.ICON_LENS, ""),
	)
	state.cursor.x += panel_width * 0.2

	GuiTextInput(
		{state.cursor.x, state.cursor.y, panel_width * 0.8, LINE_HEIGHT},
		&state.setup_screen_state.entity_search_state,
	)
	state.cursor.x = current_panel_x
	state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_left.scroll.y

	filter_entities()

	state.setup_screen_state.panel_left.height_needed =
		((LINE_HEIGHT + PANEL_PADDING) * cast(f32)state.setup_screen_state.num_entities_searched) +
		PANEL_PADDING

	if scissor_start(&state.setup_screen_state.panel_left, panel_width) {
		draw_width = panel_width - (PANEL_PADDING * 2) - 14
	} else {
		draw_width = panel_width - (PANEL_PADDING * 2)
	}

	{
		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_x = state.cursor.x

		for i in 0 ..< state.setup_screen_state.num_entities_searched {
			entity := state.setup_screen_state.entities_searched[i]
			if rl.CheckCollisionRecs(
				{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT},
				state.setup_screen_state.panel_left.rec,
			) {
				if GuiButton(
					{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT},
					entity.name,
				) {
					match_count := 0

					new_entity := new(Entity)
					new_entity^ = entity

					if state.setup_screen_state.view_tab.selected == 0 {
						for i in 0 ..< state.setup_screen_state.num_party {
							selected_entity := state.setup_screen_state.party_selected[i]
							if selected_entity.name == entity.name {
								match_count += 1
							}
						}
						if (match_count > 0) {
							new_entity.alias = fmt.caprint(entity.name, match_count + 1)
						}
						new_entity.team = .PARTY
						state.setup_screen_state.party_selected[state.setup_screen_state.num_party] =
						new_entity^

						entity_button_state := new(EntityButtonState)
						idx := state.setup_screen_state.num_party
						init_entity_button_state(
							entity_button_state,
							&state.setup_screen_state.party_selected[idx],
							&state.setup_screen_state.party_button_states,
							idx,
						)
						append(&state.setup_screen_state.party_button_states, entity_button_state^)
						state.setup_screen_state.num_party += 1
					} else {
						for i in 0 ..< state.setup_screen_state.num_enemies {
							selected_entity := state.setup_screen_state.enemies_selected[i]
							if selected_entity.name == entity.name {
								match_count += 1
							}
						}
						if (match_count > 0) {
							new_entity.alias = fmt.caprint(entity.name, match_count + 1)
						}
						new_entity.team = .ENEMIES
						state.setup_screen_state.enemies_selected[state.setup_screen_state.num_enemies] =
						new_entity^

						entity_button_state := new(EntityButtonState)
						idx := state.setup_screen_state.num_enemies
						init_entity_button_state(
							entity_button_state,
							&state.setup_screen_state.enemies_selected[idx],
							&state.setup_screen_state.enemy_button_states,
							idx,
						)
						append(&state.setup_screen_state.enemy_button_states, entity_button_state^)
						state.setup_screen_state.num_enemies += 1
					}
				}
			}
			state.cursor.y += LINE_HEIGHT + PANEL_PADDING
		}
	}

	scissor_stop(&state.setup_screen_state.panel_left)

	current_panel_x += panel_width + dynamic_x_padding
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.setup_screen_state.panel_mid,
		"Entities in combat",
	)

	@(static) view_selected: int = 0
	switch GuiTabControl(
		{state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT},
		&state.setup_screen_state.view_tab,
	) {
	case 0:
		state.setup_screen_state.panel_mid.height_needed =
			((LINE_HEIGHT + PANEL_PADDING) * cast(f32)state.setup_screen_state.num_party) +
			PANEL_PADDING
		if view_selected == 1 {
			view_selected = 0
			state.setup_screen_state.selected_entity = nil
			state.setup_screen_state.selected_entity_idx = -1
		}
	case 1:
		state.setup_screen_state.panel_mid.height_needed =
			((LINE_HEIGHT + PANEL_PADDING) * cast(f32)state.setup_screen_state.num_enemies) +
			PANEL_PADDING
		if view_selected == 0 {
			view_selected = 1
			state.setup_screen_state.selected_entity = nil
			state.setup_screen_state.selected_entity_idx = -1
		}
	}
	state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_mid.scroll.y

	if scissor_start(&state.setup_screen_state.panel_mid, panel_width) {
		draw_width = panel_width - (PANEL_PADDING * 2) - 14
	} else {
		draw_width = panel_width - (PANEL_PADDING * 2)
	}

	{
		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_x := state.cursor.x
		start_y := state.cursor.y

		if state.setup_screen_state.view_tab.selected == 0 {
			for i in 0 ..< state.setup_screen_state.num_party {
				if rl.CheckCollisionRecs(
					{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT},
					state.setup_screen_state.panel_mid.rec,
				) {
					state.setup_screen_state.party_button_states[i].index = i
					if GuiEntityButtonClickable(
						{
							state.cursor.x,
							state.cursor.y,
							draw_width - LINE_HEIGHT - PANEL_PADDING,
							LINE_HEIGHT,
						},
						&state.setup_screen_state.party_button_states[i],
					) {
						state.setup_screen_state.selected_entity =
						&state.setup_screen_state.party_selected[i]
						state.setup_screen_state.selected_entity_idx = i
						set_text_input(
							&state.setup_screen_state.initiative_input,
							cstr(state.setup_screen_state.party_selected[i].initiative),
							draw_width / 2,
						)
					}
					if (state.setup_screen_state.selected_entity_idx == i) {
						rl.DrawRectangle(
							cast(i32)state.cursor.x,
							cast(i32)state.cursor.y,
							cast(i32)(draw_width - LINE_HEIGHT - PANEL_PADDING),
							cast(i32)LINE_HEIGHT,
							BUTTON_ACTIVE_COLOUR,
						)
					}
					state.cursor.x += draw_width - LINE_HEIGHT

					if GuiButton(
						{state.cursor.x, state.cursor.y, LINE_HEIGHT, LINE_HEIGHT},
						"",
						rl.GuiIconName.ICON_CROSS,
					) {
						ordered_remove(&state.setup_screen_state.party_button_states, i)
						state.setup_screen_state.num_party -= 1

						for j in i ..< state.setup_screen_state.num_party {
							state.setup_screen_state.party_selected[j] =
								state.setup_screen_state.party_selected[j + 1]
							state.setup_screen_state.party_button_states[j].entity =
							&state.setup_screen_state.party_selected[j]
							state.setup_screen_state.party_button_states[j].index -= 1
						}

						if (state.setup_screen_state.selected_entity_idx == i) {
							state.setup_screen_state.selected_entity = nil
							state.setup_screen_state.selected_entity_idx = -1
						} else if (i < state.setup_screen_state.selected_entity_idx) {
							state.setup_screen_state.selected_entity_idx -= 1
							state.setup_screen_state.selected_entity =
							&state.setup_screen_state.party_selected[state.setup_screen_state.selected_entity_idx]
						}
					}
				}
				state.cursor.x = start_x
				state.cursor.y += LINE_HEIGHT + PANEL_PADDING
			}
		} else {
			for i in 0 ..< state.setup_screen_state.num_enemies {
				if rl.CheckCollisionRecs(
					{state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT},
					state.setup_screen_state.panel_mid.rec,
				) {
					state.setup_screen_state.enemy_button_states[i].index = i
					if GuiEntityButtonClickable(
						{
							state.cursor.x,
							state.cursor.y,
							draw_width - LINE_HEIGHT - PANEL_PADDING,
							LINE_HEIGHT,
						},
						&state.setup_screen_state.enemy_button_states[i],
					) {
						state.setup_screen_state.selected_entity =
						&state.setup_screen_state.enemies_selected[i]
						state.setup_screen_state.selected_entity_idx = i
						set_text_input(
							&state.setup_screen_state.initiative_input,
							cstr(state.setup_screen_state.enemies_selected[i].initiative),
							draw_width / 2,
						)
					}
					if (state.setup_screen_state.selected_entity_idx == i) {
						rl.DrawRectangle(
							cast(i32)state.cursor.x,
							cast(i32)state.cursor.y,
							cast(i32)(draw_width - LINE_HEIGHT),
							cast(i32)LINE_HEIGHT,
							BUTTON_ACTIVE_COLOUR,
						)
					}
					state.cursor.x += draw_width - LINE_HEIGHT

					if GuiButton(
						{state.cursor.x, state.cursor.y, LINE_HEIGHT, LINE_HEIGHT},
						"",
						rl.GuiIconName.ICON_CROSS,
					) {
						ordered_remove(&state.setup_screen_state.enemy_button_states, i)
						state.setup_screen_state.num_enemies -= 1

						for j in i ..< state.setup_screen_state.num_enemies {
							state.setup_screen_state.enemies_selected[j] =
								state.setup_screen_state.enemies_selected[j + 1]
							state.setup_screen_state.enemy_button_states[j].entity =
							&state.setup_screen_state.enemies_selected[j]
							state.setup_screen_state.enemy_button_states[j].index -= 1
						}

						if (state.setup_screen_state.selected_entity_idx == i) {
							state.setup_screen_state.selected_entity = nil
							state.setup_screen_state.selected_entity_idx = -1
						} else if (i < state.setup_screen_state.selected_entity_idx) {
							state.setup_screen_state.selected_entity_idx -= 1
							state.setup_screen_state.selected_entity =
							&state.setup_screen_state.enemies_selected[state.setup_screen_state.selected_entity_idx]
						}
					}
				}
				state.cursor.x = start_x
				state.cursor.y += LINE_HEIGHT + PANEL_PADDING
			}

		}
	}

	scissor_stop(&state.setup_screen_state.panel_mid)

	current_panel_x += panel_width + dynamic_x_padding
	state.cursor.x = current_panel_x
	state.cursor.y = panel_y

	GuiPanel(
		{state.cursor.x, state.cursor.y, panel_width, panel_height},
		&state.setup_screen_state.panel_right,
		"Entity Info",
	)
	state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_right.scroll.y

	if state.setup_screen_state.selected_entity == nil {
		state.setup_screen_state.panel_right.height_needed = 0
	}

	if scissor_start(&state.setup_screen_state.panel_right, panel_width) {
		draw_width = panel_width - (PANEL_PADDING * 2) - 14
	} else {
		draw_width = panel_width - (PANEL_PADDING * 2)
	}

	{
		state.cursor.x += PANEL_PADDING
		state.cursor.y += PANEL_PADDING

		start_y := state.cursor.y

		GuiEntityStats(
			{state.cursor.x, state.cursor.y, draw_width, 0},
			state.setup_screen_state.selected_entity,
			&state.setup_screen_state.initiative_input,
		)
		state.setup_screen_state.panel_right.height_needed = state.cursor.y - start_y
	}

	scissor_stop(&state.setup_screen_state.panel_right)

}

filter_entities :: proc() {
	@(static) last_search: cstring = ""
	if len(str(state.setup_screen_state.entity_search_state.text)) > 0 {
		if last_search != state.setup_screen_state.entity_search_state.text {
			for i in 0 ..< len(state.setup_screen_state.entities_searched) {
				state.setup_screen_state.entities_searched[i] = Entity{}
			}
			idx := 0
			state.setup_screen_state.num_entities_searched = 0

			search_str := strings.to_lower(
				str(state.setup_screen_state.entity_search_state.text),
				allocator = frame_alloc,
			)
			for i in 0 ..< state.setup_screen_state.num_entities_filtered {
				entity := state.setup_screen_state.entities_filtered[i]
				names_split := strings.split(
					strings.to_lower(str(entity.name), allocator = frame_alloc),
					" ",
					allocator = frame_alloc,
				)
				for name, j in names_split {
					name_to_test := name
					for k in j + 1 ..< len(names_split) {
						name_to_test = strings.join(
							[]string{name_to_test, names_split[k]},
							" ",
							allocator = frame_alloc,
						)
					}
					if len(search_str) <= len(name_to_test) {
						if name_to_test[:len(search_str)] == search_str {
							state.setup_screen_state.entities_searched[idx] = entity
							idx += 1
							state.setup_screen_state.num_entities_searched += 1
						}
					}
				}
			}
			last_search = fmt.caprint(state.setup_screen_state.entity_search_state.text)
		}
	} else {
		for i in 0 ..< len(state.setup_screen_state.entities_filtered) {
			state.setup_screen_state.entities_searched[i] =
				state.setup_screen_state.entities_filtered[i]
		}
		state.setup_screen_state.num_entities_searched =
			state.setup_screen_state.num_entities_filtered
	}
}

long_rest :: proc() {
	if state.setup_screen_state.selected_entity != nil {
		selected_entity := state.setup_screen_state.selected_entity
		selected_entity.initiative = 0
	}

	for i in 0 ..< state.setup_screen_state.num_party {
		entity := &state.setup_screen_state.party_selected[i]

		entity.initiative = 0
		entity.HP = entity.HP_max
		entity.temp_HP = 0
		entity.temp_dmg_vulnerabilities = DamageSet{}
		entity.temp_dmg_resistances = DamageSet{}
		entity.temp_dmg_immunities = DamageSet{}
		entity.conditions = ConditionSet{}
	}

	temp_entities_list := make([]Entity, 256, allocator = frame_alloc)
	num_temp_entities := load_entities_from_file(
		state.config.CUSTOM_ENTITY_FILE_PATH,
		&temp_entities_list,
	)

	for i in 0 ..< state.setup_screen_state.num_party {
		entity := state.setup_screen_state.party_selected[i]
		if (entity.type == .PLAYER || entity.type == .NPC) {
			for j in 0 ..< num_temp_entities {
				temp_entity := temp_entities_list[j]
				if entity.name == temp_entity.name {
					temp_entities_list[j] = entity
				}
			}
		}
	}

	for i in 0 ..< num_temp_entities {
		entity := temp_entities_list[i]
		if i == 0 {
			add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH, wipe = true)
		} else {
			add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH)
		}

		state.custom_entities[i] = entity
	}
	state.num_custom_entities = num_temp_entities
}
