package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"
import "core:time"
import rl "vendor:raylib"

draw_combat_screen :: proc() {
    using state.gui_properties

    defer GuiMessageBoxQueue(&state.combat_screen_state.message_queue)

    state.cursor.x = PADDING_LEFT
    state.cursor.y = PADDING_TOP

    if (FRAME == 59) {
        combat_to_json()
    }

    back_button_x := state.cursor.x
    back_button_y := state.cursor.y
    defer if GuiButton({back_button_x, back_button_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, &state.combat_screen_state.back_button, "Back") {
        state.current_screen_state = state.setup_screen_state
        state.combat_screen_state.first_load = true
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    decrement_button_x := state.cursor.x
    decrement_button_y := state.cursor.y
    defer if GuiButton({decrement_button_x, decrement_button_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, &state.combat_screen_state.decrement_button, rl.GuiIconText(.ICON_ARROW_LEFT, "")) {
        if (state.combat_screen_state.current_entity_idx == 0) {
            if (state.combat_screen_state.current_round > 1) {
                state.combat_screen_state.current_entity_idx = cast(i32)state.combat_screen_state.num_entities - 1
                state.combat_screen_state.current_round -= 1
                state.combat_screen_state.panel_left_top.scroll.y = -(state.combat_screen_state.panel_left_top.content_rec.height - state.combat_screen_state.panel_left_top.rec.height)
            }
        } else {
            state.combat_screen_state.current_entity_idx -= 1
            if (state.combat_screen_state.panel_left_top.scroll.y < 0) {
                state.combat_screen_state.panel_left_top.scroll.y += LINE_HEIGHT + PANEL_PADDING
            }
        }
        state.combat_screen_state.current_entity = &state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]
        state.combat_screen_state.from_dropdown.selected = state.combat_screen_state.current_entity_idx
        time.stopwatch_reset(&state.combat_screen_state.turn_timer)
        if state.combat_screen_state.combat_timer.running {
            time.stopwatch_start(&state.combat_screen_state.turn_timer)
        }
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    increment_button_x := state.cursor.x
    increment_button_y := state.cursor.y
    defer if GuiButton({increment_button_x, increment_button_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, &state.combat_screen_state.increment_button, rl.GuiIconText(.ICON_ARROW_RIGHT, "")) {
        if (state.combat_screen_state.current_entity_idx == cast(i32)state.combat_screen_state.num_entities - 1) {
            state.combat_screen_state.current_entity_idx = 0
            state.combat_screen_state.current_round += 1
            state.combat_screen_state.panel_left_top.scroll.y = 0
        } else {
            state.combat_screen_state.current_entity_idx += 1
            if (state.combat_screen_state.panel_left_top.scroll.y >= -(state.combat_screen_state.panel_left_top.content_rec.height)) {
                state.combat_screen_state.panel_left_top.scroll.y -= LINE_HEIGHT + PANEL_PADDING
            }
        }
        state.combat_screen_state.current_entity = &state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]
        state.combat_screen_state.from_dropdown.selected = state.combat_screen_state.current_entity_idx
        time.stopwatch_reset(&state.combat_screen_state.turn_timer)
        if state.combat_screen_state.combat_timer.running {
            time.stopwatch_start(&state.combat_screen_state.turn_timer)
        }
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_TITLE
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    text_align_center()

    title_width := state.window_width - state.cursor.x - PADDING_RIGHT - (MENU_BUTTON_WIDTH * 2) - (MENU_BUTTON_PADDING * 2)
    GuiLabel({state.cursor.x, state.cursor.y, title_width, MENU_BUTTON_HEIGHT}, "Combat Control")
    state.cursor.x += title_width + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    combat_time := cstr(time.clock_from_stopwatch(state.combat_screen_state.combat_timer), sep=":")
    start_button_x := state.cursor.x
    start_button_y := state.cursor.y
    defer if GuiButton({start_button_x, start_button_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, &state.combat_screen_state.start_button, combat_time, rl.GuiIconName.ICON_PLAYER_PLAY if (!state.combat_screen_state.combat_timer.running) else rl.GuiIconName.ICON_PLAYER_PAUSE) {
        if !state.combat_screen_state.combat_timer.running {
            time.stopwatch_start(&state.combat_screen_state.combat_timer)
            time.stopwatch_start(&state.combat_screen_state.turn_timer)
        } else {
            time.stopwatch_stop(&state.combat_screen_state.combat_timer)
            time.stopwatch_stop(&state.combat_screen_state.turn_timer)
        }
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    stop_button_x := state.cursor.x
    stop_button_y := state.cursor.y
    defer if GuiButton({stop_button_x, stop_button_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, &state.combat_screen_state.stop_button, rl.GuiIconText(.ICON_PLAYER_STOP, "")) {
        temp_entities_list: #soa[dynamic]Entity
        load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH, &temp_entities_list)
        defer delete_soa(temp_entities_list)

        player_count := 0
        for i in 0 ..< state.combat_screen_state.num_entities {
            entity := state.combat_screen_state.entities[i]
            if entity.type == .PLAYER {
                for temp_entity, j in temp_entities_list {
                    if entity.name == temp_entity.name {
                        temp_entities_list[j] = entity
                    }
                }
                player_count += 1
            }
        }

        for entity, i in temp_entities_list {
            if entity.type == .PLAYER {
                if i == 0 {
                    add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH, wipe=true)
                } else {
                    add_entity_to_file(entity, state.config.CUSTOM_ENTITY_FILE_PATH)
                }
            }
        }

        new_message := MessageBoxState{}
        if (player_count > 0) {
            init_message_box(&new_message, "Notification!", fmt.caprintf("%v entities saved.", player_count))
            add_message(&state.combat_screen_state.message_queue, new_message)
        } else {
            init_message_box(&new_message, "Notification!", fmt.caprintf("No PC's to save."))
        }
        reload_entities()
    }
    state.cursor.x = PADDING_LEFT
    state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

    current_panel_x := state.cursor.x
    panel_y         := state.cursor.y

    draw_width  := state.window_width - PANEL_PADDING - PADDING_RIGHT
    draw_height := state.window_height - state.cursor.y - PADDING_BOTTOM

    panel_width  := state.window_width / 3.5
    panel_height := draw_height
    
    dynamic_x_padding := (draw_width - (3 * panel_width)) / 2

    add_button_x := state.cursor.x
    add_button_y := state.cursor.y

    defer if GuiButton({add_button_x, add_button_y, panel_width / 2, LINE_HEIGHT}, &state.combat_screen_state.add_entity_button, "Cancel" if (state.combat_screen_state.add_entity_mode) else "Add") {
        state.combat_screen_state.remove_entity_mode = false
        state.combat_screen_state.add_entity_mode = !state.combat_screen_state.add_entity_mode
        clear_hover_stack()
    }
    state.cursor.x += panel_width / 2

    remove_button_x := state.cursor.x
    remove_button_y := state.cursor.y

    defer if GuiButton({remove_button_x, remove_button_y, panel_width / 2, LINE_HEIGHT}, &state.combat_screen_state.remove_entity_button, "Cancel" if (state.combat_screen_state.remove_entity_mode) else "Remove") {
        state.combat_screen_state.add_entity_mode = false
        state.combat_screen_state.remove_entity_mode = !state.combat_screen_state.remove_entity_mode
    }
    state.cursor.x = current_panel_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING
    //IP LABEL

    if state.combat_screen_state.first_load {
        state.combat_screen_state.first_load = false

        state.combat_screen_state.panel_left_top.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }

        state.combat_screen_state.panel_left_bottom.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }

        state.combat_screen_state.panel_mid.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }

        state.combat_screen_state.panel_right_top.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }

        state.combat_screen_state.panel_right_bottom.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }

        //clear(&state.combat_screen_state.entity_names)
        for i in 0 ..< state.combat_screen_state.num_entities {
            append(&state.combat_screen_state.entity_names, state.combat_screen_state.entities[i].alias)
        }

        init_dropdown_state(&state.combat_screen_state.from_dropdown, "From:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)
        init_dropdown_select_state(&state.combat_screen_state.to_dropdown, "To:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)
    }

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, (panel_height / 2) - LINE_HEIGHT}, &state.combat_screen_state.panel_left_top, "Turn Order")
    if state.combat_screen_state.add_entity_mode {
        state.combat_screen_state.panel_left_top.rec.y      += LINE_HEIGHT
        state.combat_screen_state.panel_left_top.rec.height -= LINE_HEIGHT
    }

    if !state.combat_screen_state.add_entity_mode {
        rl.DrawRectangle(cast(i32)state.cursor.x, cast(i32)state.cursor.y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, HEADER_COLOUR)
        turn_text := cstr("Round ", state.combat_screen_state.current_round, ":", sep="")
        GuiLabel({state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT}, turn_text)
        state.cursor.x += panel_width / 2

        turn_time := cstr(time.clock_from_stopwatch(state.combat_screen_state.turn_timer), sep=":")
        GuiLabel({state.cursor.x, state.cursor.y, panel_width / 2, LINE_HEIGHT}, turn_time)
        state.cursor.x = current_panel_x
        state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_left_top.scroll.y

        state.combat_screen_state.panel_left_top.height_needed = (cast(f32)state.combat_screen_state.num_entities * (LINE_HEIGHT + PANEL_PADDING)) + (PANEL_PADDING * 2)

        if state.combat_screen_state.panel_left_top.height_needed > state.combat_screen_state.panel_left_top.rec.height {
            state.combat_screen_state.panel_left_top.content_rec.width = panel_width - 14
            state.combat_screen_state.panel_left_top.content_rec.height = state.combat_screen_state.panel_left_top.height_needed
            draw_width = panel_width - (PANEL_PADDING * 2) - 14
            rl.GuiScrollPanel(state.combat_screen_state.panel_left_top.rec, nil, state.combat_screen_state.panel_left_top.content_rec, &state.combat_screen_state.panel_left_top.scroll, &state.combat_screen_state.panel_left_top.view)

            rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_left_top.view.x, cast(i32)state.combat_screen_state.panel_left_top.view.y, cast(i32)state.combat_screen_state.panel_left_top.view.width, cast(i32)state.combat_screen_state.panel_left_top.view.height)
        } else {
            state.combat_screen_state.panel_left_top.content_rec.width = panel_width
            draw_width = panel_width - (PANEL_PADDING * 2)
        }

        {
            state.cursor.x += PANEL_PADDING
            state.cursor.y += PANEL_PADDING

            for i in 0 ..< state.combat_screen_state.num_entities {
                if !state.combat_screen_state.remove_entity_mode {
                    if rl.CheckCollisionRecs({state.combat_screen_state.panel_left_top.rec.x, state.combat_screen_state.panel_left_top.rec.y, state.combat_screen_state.panel_left_top.rec.width, state.combat_screen_state.panel_left_top.rec.height}, {state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}) {
                        state.combat_screen_state.entity_button_states[i].index = i
                        if GuiEntityButtonClickable({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, &state.combat_screen_state.entity_button_states[i]) {
                            state.combat_screen_state.view_entity_idx = cast(i32)i
                            state.combat_screen_state.view_entity = &state.combat_screen_state.entities[state.combat_screen_state.view_entity_idx]
                        }
                        if (cast(i32)i == state.combat_screen_state.current_entity_idx) {
                            rl.DrawRectangle(cast(i32)state.cursor.x, cast(i32)state.cursor.y, cast(i32)draw_width, cast(i32)LINE_HEIGHT, rl.ColorAlpha(rl.BLUE, 0.2))
                        }
                    }
                } else {
                    default_highlight := BUTTON_HOVER_COLOUR
                    BUTTON_HOVER_COLOUR = rl.RED
                    defer BUTTON_HOVER_COLOUR = default_highlight

                    state.combat_screen_state.entity_button_states[i].index = i
                    if GuiEntityButtonClickable({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, &state.combat_screen_state.entity_button_states[i]) {
                        for j in i ..< state.combat_screen_state.num_entities {
                            if j < state.combat_screen_state.num_entities - 1 {
                                state.combat_screen_state.entities[j] = state.combat_screen_state.entities[j+1]
                            } else {
                                state.combat_screen_state.entities[j] = Entity{}
                            }
                        }
                        state.combat_screen_state.num_entities -= 1
                        if state.combat_screen_state.current_entity_idx > cast(i32)i {
                            state.combat_screen_state.current_entity_idx -= 1
                        }
                        ordered_remove(&state.combat_screen_state.entity_button_states, i)
                        state.combat_screen_state.current_entity = &state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]

                        clear(&state.combat_screen_state.entity_names)
                        //state.combat_screen_state.entity_names = make([dynamic]cstring)
                        for i in 0 ..< state.combat_screen_state.num_entities {
                            append(&state.combat_screen_state.entity_names, state.combat_screen_state.entities[i].alias)
                        }

                        init_dropdown_state(&state.combat_screen_state.from_dropdown, "From:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)
                        init_dropdown_select_state(&state.combat_screen_state.to_dropdown, "To:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)
                        state.combat_screen_state.remove_entity_mode = false
                    }
                }
                state.cursor.y += LINE_HEIGHT + PANEL_PADDING
            }
        }

        if state.combat_screen_state.panel_left_top.height_needed > state.combat_screen_state.panel_left_top.rec.height {
            rl.EndScissorMode()
        } else {
            state.combat_screen_state.panel_left_top.scroll.y = 0
        }
    } else {
        switch GuiTabControl({state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT}, &state.setup_screen_state.filter_tab) {
        case 0: state.setup_screen_state.entities_filtered = state.srd_entities
        case 1: state.setup_screen_state.entities_filtered = state.custom_entities
        }
        state.cursor.y += LINE_HEIGHT

        GuiLabel({state.cursor.x, state.cursor.y, panel_width * 0.2, LINE_HEIGHT}, rl.GuiIconText(.ICON_LENS, ""))
        state.cursor.x += panel_width * 0.2

        GuiTextInput({state.cursor.x, state.cursor.y, panel_width * 0.8, LINE_HEIGHT}, &state.setup_screen_state.entity_search_state)
        state.cursor.x = current_panel_x
        state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_left_top.scroll.y

        filter_entities()

        state.combat_screen_state.panel_left_top.height_needed = (cast(f32)len(state.setup_screen_state.entities_searched) * (LINE_HEIGHT + PANEL_PADDING)) + (PANEL_PADDING * 2)

        if state.combat_screen_state.panel_left_top.height_needed > state.combat_screen_state.panel_left_top.rec.height {
            state.combat_screen_state.panel_left_top.content_rec.width = panel_width - 14
            state.combat_screen_state.panel_left_top.content_rec.height = state.combat_screen_state.panel_left_top.height_needed
            draw_width = panel_width - (PANEL_PADDING * 2) - 14
            rl.GuiScrollPanel(state.combat_screen_state.panel_left_top.rec, nil, state.combat_screen_state.panel_left_top.content_rec, &state.combat_screen_state.panel_left_top.scroll, &state.combat_screen_state.panel_left_top.view)

            rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_left_top.view.x, cast(i32)state.combat_screen_state.panel_left_top.view.y, cast(i32)state.combat_screen_state.panel_left_top.view.width, cast(i32)state.combat_screen_state.panel_left_top.view.height)
        } else {
            state.combat_screen_state.panel_left_top.content_rec.width = panel_width
            draw_width = panel_width - (PANEL_PADDING * 2)
        }

        {
            state.cursor.x += PANEL_PADDING
            state.cursor.y += PANEL_PADDING

            for entity in state.setup_screen_state.entities_searched {
                if GuiButton({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, entity.name) {
                    new_entity := new(Entity)
                    new_entity^ = entity
                    match_count := 0
                    for i in 0 ..< state.combat_screen_state.num_entities {
                        selected_entity := state.combat_screen_state.entities[i]
                        if selected_entity.name == entity.name {
                            match_count += 1
                        }
                    }
                    if match_count > 0 {
                        new_entity.alias = fmt.caprint(entity.name, match_count + 1)
                    }
                    idx := state.combat_screen_state.num_entities
                    state.combat_screen_state.entities[idx] = new_entity^

                    entity_button_state := new(EntityButtonState)
                    init_entity_button_state(entity_button_state, &state.combat_screen_state.entities[idx], &state.combat_screen_state.entity_button_states, idx)
                    append(&state.combat_screen_state.entity_button_states, entity_button_state^)
                    state.combat_screen_state.num_entities += 1

                    state.combat_screen_state.current_entity = &state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]

                    clear(&state.combat_screen_state.entity_names)
                    //state.combat_screen_state.entity_names = make([dynamic]cstring)

                    for i in 0 ..< state.combat_screen_state.num_entities {
                        append(&state.combat_screen_state.entity_names, state.combat_screen_state.entities[i].alias)
                    }

                    init_dropdown_state(&state.combat_screen_state.from_dropdown, "From:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)
                    init_dropdown_select_state(&state.combat_screen_state.to_dropdown, "To:", state.combat_screen_state.entity_names[:], &state.combat_screen_state.btn_list)

                    state.combat_screen_state.add_entity_mode = false
                }
                state.cursor.y += LINE_HEIGHT + PANEL_PADDING
            }
        }

        if (state.combat_screen_state.panel_left_top.height_needed > state.combat_screen_state.panel_left_top.rec.height) {
            rl.EndScissorMode()
        } else {
            state.combat_screen_state.panel_left_top.scroll.y = 0
        }
    }
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y + (panel_height / 2)

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height / 2}, &state.combat_screen_state.panel_left_bottom, "Selected entity info")
    
    switch GuiTabControl({state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT}, &state.combat_screen_state.view_entity_tab_state) {
    case 0: state.combat_screen_state.panel_left_bottom_text = "stats"
    case 1: state.combat_screen_state.panel_left_bottom_text = state.combat_screen_state.view_entity.traits
    case 2: state.combat_screen_state.panel_left_bottom_text = state.combat_screen_state.view_entity.actions
    case 3: state.combat_screen_state.panel_left_bottom_text = state.combat_screen_state.view_entity.legendary_actions
    }
    state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_left_bottom.scroll.y

    if (state.combat_screen_state.panel_left_bottom.height_needed > state.combat_screen_state.panel_left_bottom.rec.height) {
        state.combat_screen_state.panel_left_bottom.content_rec.width = panel_width - 14
        state.combat_screen_state.panel_left_bottom.content_rec.height = state.combat_screen_state.panel_left_bottom.height_needed
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        
        rl.GuiScrollPanel(state.combat_screen_state.panel_left_bottom.rec, nil, state.combat_screen_state.panel_left_bottom.content_rec, &state.combat_screen_state.panel_left_bottom.scroll, &state.combat_screen_state.panel_left_bottom.view)
        rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_left_bottom.view.x, cast(i32)state.combat_screen_state.panel_left_bottom.view.y, cast(i32)state.combat_screen_state.panel_left_bottom.view.width, cast(i32)state.combat_screen_state.panel_left_bottom.view.height)
    } else {
        state.combat_screen_state.panel_left_bottom.content_rec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
    }

    {
        start_y := state.cursor.y

        if (state.combat_screen_state.panel_left_bottom_text == "stats") {
            state.cursor.x += PANEL_PADDING
            GuiEntityStats({state.cursor.x, state.cursor.y, state.combat_screen_state.panel_left_bottom.content_rec.width - (PANEL_PADDING * 2), 0}, state.combat_screen_state.view_entity)
            state.combat_screen_state.panel_left_bottom.height_needed = state.cursor.y - start_y
        } else if (state.combat_screen_state.panel_left_bottom_text != "") {
            rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_WORD)
            rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_TOP)
            rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_LINE_SPACING, 25)
            
            lines_needed := get_text_lines_needed(state.combat_screen_state.panel_left_bottom_text, state.combat_screen_state.panel_left_bottom.content_rec.width - (PANEL_PADDING * 2), TEXT_SIZE)
            rl.GuiTextBox({state.cursor.x, state.cursor.y, state.combat_screen_state.panel_left_bottom.content_rec.width, cast(f32)lines_needed * 27}, state.combat_screen_state.panel_left_bottom_text, TEXT_SIZE, false)
            state.cursor.y += cast(f32)lines_needed * 27
            state.combat_screen_state.panel_left_bottom.height_needed = state.cursor.y - start_y
        }
    }

    if (state.combat_screen_state.panel_left_bottom.height_needed > state.combat_screen_state.panel_left_bottom.rec.height) {
        rl.EndScissorMode()
    } else {
        state.combat_screen_state.panel_left_bottom.scroll.y = 0
    }

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE)

    current_panel_x += panel_width + dynamic_x_padding
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height}, &state.combat_screen_state.panel_mid, "Combat Controls")
    state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_mid.scroll.y

    draw_width  = panel_width - (PANEL_PADDING * 2)
    draw_height = panel_height - LINE_HEIGHT - (PANEL_PADDING * 2)

    scroll_locked := false
    for _, btn in state.combat_screen_state.btn_list {
        if btn^ {
            scroll_locked = true
        }
    }

    if (state.combat_screen_state.panel_mid.height_needed > state.combat_screen_state.panel_mid.rec.height) {
        state.combat_screen_state.panel_mid.content_rec.width = panel_width - 14
        state.combat_screen_state.panel_mid.content_rec.height = state.combat_screen_state.panel_mid.height_needed
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        rl.GuiLine({state.combat_screen_state.panel_mid.rec.x, state.combat_screen_state.panel_mid.rec.y, state.combat_screen_state.panel_mid.rec.width, 5}, "")
        if !scroll_locked {
            rl.GuiScrollPanel(state.combat_screen_state.panel_mid.rec, nil, state.combat_screen_state.panel_mid.content_rec, &state.combat_screen_state.panel_mid.scroll, &state.combat_screen_state.panel_mid.view)
        }
        rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_mid.view.x, cast(i32)state.combat_screen_state.panel_mid.view.y, cast(i32)state.combat_screen_state.panel_mid.view.width, cast(i32)state.combat_screen_state.panel_mid.view.height)
    } else {
        state.combat_screen_state.panel_mid.content_rec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
    }
    
    {   
        start_y := state.cursor.y
        state.cursor.x += PANEL_PADDING
        state.cursor.y += PANEL_PADDING

        from_dropdown_x := state.cursor.x
        from_dropdown_y := state.cursor.y
        state.cursor.x += draw_width / 2

        to_dropdown_x := state.cursor.x
        to_dropdown_y := state.cursor.y
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Damage")
        state.cursor.x += draw_width / 2
        
        dmg_type_x := state.cursor.x
        dmg_type_y := state.cursor.y

        GuiDropdownControl({dmg_type_x, dmg_type_y, draw_width / 2, LINE_HEIGHT}, &state.combat_screen_state.dmg_type_dropdown)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.dmg_type_dropdown)
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        if (state.combat_screen_state.panel_mid.height_needed > state.combat_screen_state.panel_mid.rec.height) {
            rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_mid.view.x, cast(i32)state.combat_screen_state.panel_mid.view.y, cast(i32)state.combat_screen_state.panel_mid.view.width, cast(i32)state.combat_screen_state.panel_mid.view.height)
        }

        GuiLabel({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Amount:")
        state.cursor.x += draw_width / 3
        GuiTextInput({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, &state.combat_screen_state.dmg_input)
        state.cursor.x += draw_width / 3
        if (GuiButton({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Resolve") && !state.combat_screen_state.to_dropdown.active) {
            resolve_damage()
        }
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiLabel({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, "Healing")
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING
        GuiLabel({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Amount:")
        state.cursor.x += draw_width / 3
        GuiTextInput({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, &state.combat_screen_state.heal_input)
        state.cursor.x += draw_width / 3
        if (GuiButton({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Resolve") && !state.combat_screen_state.to_dropdown.active) {
            resolve_healing()
        }
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiLabel({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, "Temp HP")
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING
        GuiLabel({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Amount:")
        state.cursor.x += draw_width / 3
        GuiTextInput({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, &state.combat_screen_state.temp_HP_input)
        state.cursor.x += draw_width / 3
        if GuiButton({state.cursor.x, state.cursor.y, draw_width / 3, LINE_HEIGHT}, "Resolve") {
            resolve_temp_HP()
        }
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiLabel({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, "Conditions")
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        conditions_x := state.cursor.x
        conditions_y := state.cursor.y

        GuiDropdownSelectControl({conditions_x, conditions_y, draw_width / 2, LINE_HEIGHT}, &state.combat_screen_state.condition_dropdown)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.condition_dropdown)
        state.cursor.x += draw_width / 2
        
        if (state.combat_screen_state.panel_mid.height_needed > state.combat_screen_state.panel_mid.rec.height) {
            rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_mid.view.x, cast(i32)state.combat_screen_state.panel_mid.view.y, cast(i32)state.combat_screen_state.panel_mid.view.width, cast(i32)state.combat_screen_state.panel_mid.view.height)
        }

        if GuiButton({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Apply") {
            resolve_conditions()
        }
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiLabel({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Temp")
        state.cursor.x += draw_width / 2

        rl.GuiToggleSlider({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Vulnerability;Resistance;Immunity", &state.combat_screen_state.toggle_active)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.temp_resist_immunity_dropdown)
        state.cursor.x = current_panel_x + PANEL_PADDING
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiDropdownSelectControl({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, &state.combat_screen_state.temp_resist_immunity_dropdown)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.temp_resist_immunity_dropdown)
        state.cursor.x += draw_width / 2

        if (state.combat_screen_state.panel_mid.height_needed > state.combat_screen_state.panel_mid.rec.height) {
            rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_mid.view.x, cast(i32)state.combat_screen_state.panel_mid.view.y, cast(i32)state.combat_screen_state.panel_mid.view.width, cast(i32)state.combat_screen_state.panel_mid.view.height)
        }

        if GuiButton({state.cursor.x, state.cursor.y, draw_width / 2, LINE_HEIGHT}, "Apply") {
            resolve_temp_resistance_or_immunity()
        }
        state.cursor.y += LINE_HEIGHT + PANEL_PADDING

        GuiDropdownControl({from_dropdown_x, from_dropdown_y, draw_width / 2, LINE_HEIGHT}, &state.combat_screen_state.from_dropdown)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.from_dropdown)

        GuiDropdownSelectControl({to_dropdown_x, to_dropdown_y, draw_width / 2, LINE_HEIGHT}, &state.combat_screen_state.to_dropdown)
        register_button(&state.combat_screen_state.btn_list, &state.combat_screen_state.to_dropdown)
        state.combat_screen_state.panel_mid.height_needed = state.cursor.y - start_y + PANEL_PADDING
    }

    if (state.combat_screen_state.panel_mid.height_needed > state.combat_screen_state.panel_mid.rec.height) {
        rl.EndScissorMode()
    } else {
        state.combat_screen_state.panel_mid.scroll.y = 0
    }

    current_panel_x += panel_width + dynamic_x_padding
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height / 2}, &state.combat_screen_state.panel_right_top, "Entity Info")
    state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_right_top.scroll.y

    if (state.combat_screen_state.panel_right_top.height_needed > state.combat_screen_state.panel_right_top.rec.height) {
        state.combat_screen_state.panel_right_top.content_rec.width = panel_width - 14
        state.combat_screen_state.panel_right_top.content_rec.height = state.combat_screen_state.panel_right_top.height_needed
        rl.GuiScrollPanel(state.combat_screen_state.panel_right_top.rec, nil, state.combat_screen_state.panel_right_top.content_rec, &state.combat_screen_state.panel_right_top.scroll, &state.combat_screen_state.panel_right_top.view)

        rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_right_top.view.x, cast(i32)state.combat_screen_state.panel_right_top.view.y, cast(i32)state.combat_screen_state.panel_right_top.view.width, cast(i32)state.combat_screen_state.panel_right_top.view.height)
    } else {
        state.combat_screen_state.panel_right_top.content_rec.width = panel_width
    }

    {
        state.cursor.x += PANEL_PADDING
        start_y := state.cursor.y
        GuiEntityStats({state.cursor.x, state.cursor.y, state.combat_screen_state.panel_right_top.content_rec.width - (PANEL_PADDING * 2), 0}, state.combat_screen_state.current_entity)
        state.combat_screen_state.panel_right_top.height_needed = state.cursor.y - start_y
    }

    if (state.combat_screen_state.panel_right_top.height_needed > state.combat_screen_state.panel_right_top.rec.height) {
        rl.EndScissorMode()
    } else {
        state.combat_screen_state.panel_right_top.scroll.y = 0
    }
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y + (panel_height / 2)

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height / 2}, &state.combat_screen_state.panel_right_bottom, "Entity Abilities")

    switch GuiTabControl({state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT}, &state.combat_screen_state.current_entity_tab_state) {
    case 0:
        state.combat_screen_state.panel_right_bottom_text = state.combat_screen_state.current_entity.traits
    case 1:
        state.combat_screen_state.panel_right_bottom_text = state.combat_screen_state.current_entity.actions
    case 2:
        state.combat_screen_state.panel_right_bottom_text = state.combat_screen_state.current_entity.legendary_actions
    }
    state.cursor.y += LINE_HEIGHT + state.combat_screen_state.panel_right_bottom.scroll.y
    state.cursor.y = state.cursor.y
    
    if (state.combat_screen_state.panel_right_bottom.height_needed > state.combat_screen_state.panel_right_bottom.rec.height) {
        state.combat_screen_state.panel_right_bottom.content_rec.width = panel_width - 14
        state.combat_screen_state.panel_right_bottom.content_rec.height = state.combat_screen_state.panel_right_bottom.height_needed
        rl.GuiScrollPanel(state.combat_screen_state.panel_right_bottom.rec, nil, state.combat_screen_state.panel_right_bottom.content_rec, &state.combat_screen_state.panel_right_bottom.scroll, &state.combat_screen_state.panel_right_bottom.view)

        rl.BeginScissorMode(cast(i32)state.combat_screen_state.panel_right_bottom.view.x, cast(i32)state.combat_screen_state.panel_right_bottom.view.y, cast(i32)state.combat_screen_state.panel_right_bottom.view.width, cast(i32)state.combat_screen_state.panel_right_bottom.view.height)
    } else {
        state.combat_screen_state.panel_right_bottom.content_rec.width = panel_width
    }

    {
        start_y := state.cursor.y
    
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_WORD)
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_TOP)
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_LINE_SPACING, 25)

        if state.combat_screen_state.panel_right_bottom_text != "" {
            lines_needed := get_text_lines_needed(state.combat_screen_state.panel_right_bottom_text, state.combat_screen_state.panel_right_bottom.content_rec.width - (PANEL_PADDING * 2), TEXT_SIZE)
            rl.GuiTextBox({state.cursor.x, state.cursor.y, state.combat_screen_state.panel_right_bottom.content_rec.width, cast(f32)lines_needed * 28}, state.combat_screen_state.panel_right_bottom_text, TEXT_SIZE, false)
            state.cursor.y += cast(f32)lines_needed * 28
        }
        state.combat_screen_state.panel_right_bottom.height_needed = (state.cursor.y - start_y)
    }

    if (state.combat_screen_state.panel_right_bottom.height_needed > state.combat_screen_state.panel_right_bottom.rec.height) {
        rl.EndScissorMode()
    } else {
        state.combat_screen_state.panel_right_bottom.scroll.y = 0
    }
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE)
}

resolve_damage :: proc() {
    dmg_amount : i32 = to_i32(state.combat_screen_state.dmg_input.text)

    switch state.combat_screen_state.dmg_type_dropdown.labels[state.combat_screen_state.dmg_type_dropdown.selected] {
    case "Any"        : state.combat_screen_state.dmg_type_selected = .ANY
    case "Slashing"   : state.combat_screen_state.dmg_type_selected = .SLASHING
    case "Piercing"   : state.combat_screen_state.dmg_type_selected = .PIERCING
    case "Bludgeoning": state.combat_screen_state.dmg_type_selected = .BLUDGEONING
    case "Non-magical": state.combat_screen_state.dmg_type_selected = .NON_MAGICAL
    case "Poison"     : state.combat_screen_state.dmg_type_selected = .POISON
    case "Acid"       : state.combat_screen_state.dmg_type_selected = .ACID
    case "Fire"       : state.combat_screen_state.dmg_type_selected = .FIRE
    case "Cold"       : state.combat_screen_state.dmg_type_selected = .COLD
    case "Radiant"    : state.combat_screen_state.dmg_type_selected = .RADIANT
    case "Necrotic"   : state.combat_screen_state.dmg_type_selected = .NECROTIC
    case "Lightning"  : state.combat_screen_state.dmg_type_selected = .LIGHTNING
    case "Thunder"    : state.combat_screen_state.dmg_type_selected = .THUNDER
    case "Force"      : state.combat_screen_state.dmg_type_selected = .FORCE
    case "Psychic"    : state.combat_screen_state.dmg_type_selected = .PSYCHIC
    }
    
    for i in 0 ..< state.combat_screen_state.num_entities {
        entity := state.combat_screen_state.entities[i]
        if (state.combat_screen_state.to_dropdown.selected[i]) {
            if state.combat_screen_state.dmg_type_selected not_in entity.dmg_immunities && state.combat_screen_state.dmg_type_selected not_in entity.temp_dmg_immunities {
                if state.combat_screen_state.dmg_type_selected in entity.dmg_resistances {
                    dmg_amount /= 2
                } else if state.combat_screen_state.dmg_type_selected in entity.dmg_vulnerabilities || state.combat_screen_state.dmg_type_selected in entity.temp_dmg_vulnerabilities {
                    dmg_amount *= 2
                }
                dmg_amount -= entity.temp_HP
                if dmg_amount >= 0 {
                    entity.temp_HP = 0
                    entity.HP -= dmg_amount
                    is_entity_dead(&entity)
                } else {
                    entity.temp_HP = -dmg_amount
                }
            }
        }
        state.combat_screen_state.to_dropdown.selected[i] = false
    }
}

resolve_healing :: proc() {
    heal_amount : i32 = to_i32(state.combat_screen_state.heal_input.text)
    
    for i in 0 ..< state.combat_screen_state.num_entities {
        entity := state.combat_screen_state.entities[i]
        if (state.combat_screen_state.to_dropdown.selected[i]) {
            entity.HP += heal_amount
            is_entity_over_max(&entity)
        }
        state.combat_screen_state.to_dropdown.selected[i] = false
    }
}

resolve_temp_HP :: proc() {
    HP_amount : i32 = to_i32(state.combat_screen_state.temp_HP_input.text)

    for i in 0 ..< state.combat_screen_state.num_entities {
        entity := state.combat_screen_state.entities[i]
        if (state.combat_screen_state.to_dropdown.selected[i]) {
            entity.temp_HP = HP_amount if (HP_amount > entity.temp_HP) else entity.temp_HP
        }
        state.combat_screen_state.to_dropdown.selected[i] = false
    }
}

resolve_conditions :: proc() {
    for i in 0 ..< state.combat_screen_state.num_entities {
        entity := state.combat_screen_state.entities[i]
        if state.combat_screen_state.to_dropdown.selected[i] {
            entity.conditions = ConditionSet{}
            for check_box, j in state.combat_screen_state.condition_dropdown.check_box_states {
                condition := check_box.text
                if state.combat_screen_state.condition_dropdown.selected[j] {
                    switch strings.to_lower(str(condition), allocator=frame_alloc) {
                    case "blinded":
                        if .BLINDED not_in entity.condition_immunities {
                            entity.conditions |= {.BLINDED}
                        }
                    case "charmed":
                        if .CHARMED not_in entity.condition_immunities {
                            entity.conditions |= {.CHARMED}
                        }
                    case "deafened": 
                        if .DEAFENED not_in entity.condition_immunities {
                            entity.conditions |= {.DEAFENED}
                        }
                    case "frightened":
                        if .FRIGHTENED not_in entity.condition_immunities {
                            entity.conditions |= {.FRIGHTENED}
                        }
                    case "grappled":
                        if .GRAPPLED not_in entity.condition_immunities{
                            entity.conditions |= {.GRAPPLED}
                        }
                    case "incapacitated": 
                        if .INCAPACITATED not_in entity.condition_immunities {
                            entity.conditions |= {.INCAPACITATED}
                        }
                    case "invisible":
                        if .INVISIBLE not_in entity.condition_immunities {
                            entity.conditions |= {.INVISIBLE}
                        }
                    case "paralyzed":
                        if  .PARALYZED not_in entity.condition_immunities {
                            entity.conditions |= {.PARALYZED}
                        }
                    case "petrified":
                        if .PETRIFIED not_in entity.condition_immunities {
                            entity.conditions |= {.PETRIFIED}
                        }
                    case "poisoned":
                        if .POISONED not_in entity.condition_immunities {
                            entity.conditions |= {.POISONED}
                        }
                    case "prone":
                        if .PRONE not_in entity.condition_immunities {
                            entity.conditions |= {.PRONE}
                        }
                    case "restrained":
                        if .RESTRAINED not_in entity.condition_immunities {
                            entity.conditions |= {.RESTRAINED}
                        }
                    case "stunned":
                        if .STUNNED not_in entity.condition_immunities {
                            entity.conditions |= {.STUNNED}
                        }
                    case "unconscious":
                        if .UNCONSCIOUS not_in entity.condition_immunities {
                            entity.conditions |= {.UNCONSCIOUS}
                        }
                    case "exhaustion":
                        if .EXHAUSTION not_in entity.condition_immunities {
                            entity.conditions |= {.EXHAUSTION}
                        }
                    }
                    state.combat_screen_state.condition_dropdown.selected[j] = false
                }
            }
        }
        state.combat_screen_state.to_dropdown.selected[i] = false
    }
}

resolve_temp_resistance_or_immunity :: proc() {
    if state.combat_screen_state.toggle_active == 0 {
        for i in 0 ..< state.combat_screen_state.num_entities {
            entity := state.combat_screen_state.entities[i]
            if state.combat_screen_state.to_dropdown.selected[i] {
                entity.temp_dmg_resistances = DamageSet{}
                for check_box, j in state.combat_screen_state.temp_resist_immunity_dropdown.check_box_states {
                    dmg_type := check_box.text
                    if state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] {
                        log.debugf("Found one: %v, %v", dmg_type, j)
                        switch strings.to_lower(str(dmg_type), allocator=frame_alloc) {
                        case "slashing"   : entity.temp_dmg_vulnerabilities |= {.SLASHING}
                        case "piercing"   : entity.temp_dmg_vulnerabilities |= {.PIERCING}
                        case "bludgeoning": entity.temp_dmg_vulnerabilities |= {.BLUDGEONING}
                        case "non-magical": entity.temp_dmg_vulnerabilities |= {.NON_MAGICAL}
                        case "poison"     : entity.temp_dmg_vulnerabilities |= {.POISON}
                        case "acid"       : entity.temp_dmg_vulnerabilities |= {.ACID}
                        case "fire"       : entity.temp_dmg_vulnerabilities |= {.FIRE}
                        case "cold"       : entity.temp_dmg_vulnerabilities |= {.COLD}
                        case "radiant"    : entity.temp_dmg_vulnerabilities |= {.RADIANT}
                        case "necrotic"   : entity.temp_dmg_vulnerabilities |= {.NECROTIC}
                        case "lightning"  : entity.temp_dmg_vulnerabilities |= {.LIGHTNING}
                        case "thunder"    : entity.temp_dmg_vulnerabilities |= {.THUNDER}
                        case "force"      : entity.temp_dmg_vulnerabilities |= {.FORCE}
                        case "psychic"    : entity.temp_dmg_vulnerabilities |= {.PSYCHIC}
                        }
                        log.debugf("Removing one: %v", j)
                        state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] = false
                    }
                }
            }
            state.combat_screen_state.to_dropdown.selected[i] = false
        }
    } else if state.combat_screen_state.toggle_active == 1 {
        for i in 0 ..< state.combat_screen_state.num_entities {
            entity := state.combat_screen_state.entities[i]
            if state.combat_screen_state.to_dropdown.selected[i] {
                entity.temp_dmg_resistances = DamageSet{}
                for check_box, j in state.combat_screen_state.temp_resist_immunity_dropdown.check_box_states {
                    dmg_type := check_box.text
                    if state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] {
                        log.debugf("Found one: %v, %v", dmg_type, j)
                        switch strings.to_lower(str(dmg_type), allocator=frame_alloc) {
                        case "slashing": entity.temp_dmg_resistances |= {.SLASHING}
                        case "piercing": entity.temp_dmg_resistances |= {.PIERCING}
                        case "bludgeoning": entity.temp_dmg_resistances |= {.BLUDGEONING}
                        case "non-magical": entity.temp_dmg_resistances |= {.NON_MAGICAL}
                        case "poison": entity.temp_dmg_resistances |= {.POISON}
                        case "acid": entity.temp_dmg_resistances |= {.ACID}
                        case "fire": entity.temp_dmg_resistances |= {.FIRE}
                        case "cold": entity.temp_dmg_resistances |= {.COLD}
                        case "radiant": entity.temp_dmg_resistances |= {.RADIANT}
                        case "necrotic": entity.temp_dmg_resistances |= {.NECROTIC}
                        case "lightning": entity.temp_dmg_resistances |= {.LIGHTNING}
                        case "thunder": entity.temp_dmg_resistances |= {.THUNDER}
                        case "force": entity.temp_dmg_resistances |= {.FORCE}
                        case "psychic": entity.temp_dmg_resistances |= {.PSYCHIC}
                        }
                        log.debugf("Removing one: %v", j)
                        state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] = false
                    }
                }
            }
            state.combat_screen_state.to_dropdown.selected[i] = false
        }
    } else if state.combat_screen_state.toggle_active == 2 {
        for i in 0 ..< state.combat_screen_state.num_entities {
            entity := state.combat_screen_state.entities[i]
            if state.combat_screen_state.to_dropdown.selected[i] {
                entity.temp_dmg_immunities = DamageSet{}
                for check_box, j in state.combat_screen_state.temp_resist_immunity_dropdown.check_box_states {
                    dmg_type := check_box.text
                    if state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] {
                        log.debugf("Found one: %v, %v", dmg_type, j)
                        switch strings.to_lower(str(dmg_type), allocator=frame_alloc) {
                        case "slashing": entity.temp_dmg_immunities |= {.SLASHING}
                        case "piercing": entity.temp_dmg_immunities |= {.PIERCING}
                        case "bludgeoning": entity.temp_dmg_immunities |= {.BLUDGEONING}
                        case "non-magical": entity.temp_dmg_immunities |= {.NON_MAGICAL}
                        case "poison": entity.temp_dmg_immunities |= {.POISON}
                        case "acid": entity.temp_dmg_immunities |= {.ACID}
                        case "fire": entity.temp_dmg_immunities |= {.FIRE}
                        case "cold": entity.temp_dmg_immunities |= {.COLD}
                        case "radiant": entity.temp_dmg_immunities |= {.RADIANT}
                        case "necrotic": entity.temp_dmg_immunities |= {.NECROTIC}
                        case "lightning": entity.temp_dmg_immunities |= {.LIGHTNING}
                        case "thunder": entity.temp_dmg_immunities |= {.THUNDER}
                        case "force": entity.temp_dmg_immunities |= {.FORCE}
                        case "psychic": entity.temp_dmg_immunities |= {.PSYCHIC}
                        }
                        state.combat_screen_state.temp_resist_immunity_dropdown.selected[j] = false
                    }
                }
            }
            state.combat_screen_state.to_dropdown.selected[i] = false
            log.debugf("Entity: %v, new resistances: %v", entity.name, entity.dmg_resistances)
        }
    }
}
