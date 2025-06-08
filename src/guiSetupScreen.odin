package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"
import "core:strconv"
import rl "vendor:raylib"

draw_setup_screen :: proc() {
    using state.gui_properties

    defer GuiMessageBoxQueue(&state.setup_screen_state.message_queue)

    state.cursor.x = PADDING_LEFT
    state.cursor.y = PADDING_TOP

    start_x := state.cursor.x

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    text_align_center()

    if GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back") {
        state.setup_screen_state.first_load = true
        state.current_screen_state = state.title_screen_state
        return
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    if GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_OPEN, "")) {
        state.current_screen_state = state.load_screen_state
        return
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_TITLE
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_TITLE)

    title_width := state.window_width - (MENU_BUTTON_WIDTH * 4) - (MENU_BUTTON_PADDING * 4) - PADDING_LEFT - PADDING_RIGHT
    GuiLabel({state.cursor.x, state.cursor.y, title_width, MENU_BUTTON_HEIGHT}, "Combat Setup")
    state.cursor.x += title_width + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    if GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_SAVE, "")) {
        new_message := MessageBoxState{}
        
        if save_combat_file(str(state.config.COMBAT_FILES_DIR, FILE_SEPERATOR, state.setup_screen_state.filename_input.text, ".combat",sep="")) {
            init_message_box(&new_message, "Notification!", fmt.caprint(state.setup_screen_state.filename_input.text, ".combat saved!", sep=""))
            add_message(&state.setup_screen_state.message_queue, new_message)
        } else {
            log.errorf("Error with file, path: %v", str(state.config.COMBAT_FILES_DIR, FILE_SEPERATOR, state.setup_screen_state.filename_input.text, ".combat", sep=""))
            init_message_box(&new_message, "Error!", "Failed to save file.")
            add_message(&state.setup_screen_state.message_queue, new_message)
        }
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    if GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_PLAY, "")) {
        if state.setup_screen_state.num_entities > 0 {
            for i in 0 ..< state.setup_screen_state.num_entities {
                if (state.setup_screen_state.entities_selected[i].initiative == 0) {
                    entity_roll_initiative(&state.setup_screen_state.entities_selected[i])
                }
            }
            copy(state.combat_screen_state.entities, state.setup_screen_state.entities_selected)
            
            state.combat_screen_state.num_entities = state.setup_screen_state.num_entities
            order_by_initiative(&state.combat_screen_state.entities, state.combat_screen_state.num_entities)
            state.combat_screen_state.current_entity_idx = 0
            state.combat_screen_state.current_entity = &state.combat_screen_state.entities[state.combat_screen_state.current_entity_idx]
            state.combat_screen_state.view_entity_idx = 0
            state.combat_screen_state.view_entity = &state.combat_screen_state.entities[state.combat_screen_state.view_entity_idx]

            for &entity_button, i in state.setup_screen_state.entity_button_states {
                entity_button_state := new(EntityButtonState)
                init_entity_button_state(entity_button_state, &state.combat_screen_state.entities[i], &state.combat_screen_state.entity_button_states, i)
                append(&state.combat_screen_state.entity_button_states, entity_button_state^)
            }
            state.current_screen_state = state.combat_screen_state
            return
        }else {
            new_message := MessageBoxState{}
            init_message_box(&new_message, "Warning!", "No combatants added.")
            add_message(&state.setup_screen_state.message_queue, new_message)
            return
        }
    }
    state.cursor.x = start_x
    state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

    GuiLabel({state.cursor.x, state.cursor.y, (MENU_BUTTON_WIDTH * 2), LINE_HEIGHT}, "Combat name:")
    state.cursor.x += (MENU_BUTTON_WIDTH * 2) + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, (MENU_BUTTON_WIDTH * 2), LINE_HEIGHT}, &state.setup_screen_state.filename_input)

    state.cursor.x = start_x
    state.cursor.y += LINE_HEIGHT + MENU_BUTTON_PADDING

    current_panel_x := state.cursor.x
    panel_y         := state.cursor.y
    
    draw_width : f32 = state.window_width - PADDING_LEFT - PADDING_RIGHT
    draw_heght : f32 = state.window_height - state.cursor.y - PADDING_BOTTOM

    panel_width  := state.window_width / 3.5
    panel_height := draw_heght
    dynamic_x_padding : f32 = (draw_width - (3 * panel_width)) / 2

    if state.setup_screen_state.first_load {
        state.setup_screen_state.first_load = false

        state.setup_screen_state.entities_filtered = state.srd_entities

        state.setup_screen_state.panel_left.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }
        state.setup_screen_state.panel_mid.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }
        state.setup_screen_state.panel_right.content_rec = {
            state.cursor.x,
            state.cursor.y,
            panel_width,
            0,
        }
    }

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height}, &state.setup_screen_state.panel_left, "Available entities")
    state.setup_screen_state.panel_left.rec.y      += LINE_HEIGHT
    state.setup_screen_state.panel_left.rec.height -= LINE_HEIGHT

    switch GuiTabControl({state.cursor.x, state.cursor.y, panel_width, LINE_HEIGHT}, &state.setup_screen_state.filter_tab) {
    case 0: state.setup_screen_state.entities_filtered = state.srd_entities
    case 1: state.setup_screen_state.entities_filtered = state.custom_entities
    }
    state.cursor.y += LINE_HEIGHT

    GuiLabel({state.cursor.x, state.cursor.y, panel_width * 0.2, LINE_HEIGHT}, rl.GuiIconText(.ICON_LENS, ""))
    state.cursor.x += panel_width * 0.2
    GuiTextInput({state.cursor.x, state.cursor.y, panel_width * 0.8, LINE_HEIGHT}, &state.setup_screen_state.entity_search_state)
    state.cursor.x = current_panel_x
    state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_left.scroll.y

    filter_entities()

    state.setup_screen_state.panel_left.height_needed = ((LINE_HEIGHT + PANEL_PADDING) * cast(f32)len(state.setup_screen_state.entities_searched)) + PANEL_PADDING

    if (state.setup_screen_state.panel_left.height_needed > state.setup_screen_state.panel_left.rec.height) {
        state.setup_screen_state.panel_left.content_rec.width = panel_width - 14
        state.setup_screen_state.panel_left.content_rec.height = state.setup_screen_state.panel_left.height_needed
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        rl.GuiScrollPanel(state.setup_screen_state.panel_left.rec, nil, state.setup_screen_state.panel_left.content_rec, &state.setup_screen_state.panel_left.scroll, &state.setup_screen_state.panel_left.view)
        rl.BeginScissorMode(cast(i32)state.setup_screen_state.panel_left.view.x, cast(i32)state.setup_screen_state.panel_left.view.y, cast(i32)state.setup_screen_state.panel_left.view.width, cast(i32)state.setup_screen_state.panel_left.view.height)
    } else {
        state.setup_screen_state.panel_left.content_rec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
    }

    {
        state.cursor.x += PANEL_PADDING
        state.cursor.y += PANEL_PADDING

        for entity in state.setup_screen_state.entities_searched {
            if rl.CheckCollisionRecs({state.setup_screen_state.panel_left.rec.x, state.setup_screen_state.panel_left.rec.y, state.setup_screen_state.panel_left.rec.width, state.setup_screen_state.panel_left.rec.height}, {state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}) {
                if GuiButton({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, entity.name) {
                    new_entity := new(Entity)
                    new_entity^ = entity
                    match_count := 0
                    for i in 0 ..< state.setup_screen_state.num_entities {
                        selected_entity := state.setup_screen_state.entities_selected[i]
                        if selected_entity.name == entity.name {
                            match_count += 1
                            }
                    }
                    if match_count > 0 {
                        new_entity.alias = fmt.caprint(entity.name, match_count + 1)
                    }
                    state.setup_screen_state.entities_selected[state.setup_screen_state.num_entities] = new_entity^
                    entity_button_state := new(EntityButtonState)

                    idx := state.setup_screen_state.num_entities
                    init_entity_button_state(entity_button_state, &state.setup_screen_state.entities_selected[idx], &state.setup_screen_state.entity_button_states, idx)
                    append(&state.setup_screen_state.entity_button_states, entity_button_state^)
                    state.setup_screen_state.num_entities += 1
                }
            }
            state.cursor.y += LINE_HEIGHT + PANEL_PADDING
        }
    }

    if (state.setup_screen_state.panel_left.height_needed > state.setup_screen_state.panel_left.rec.height) {
        rl.EndScissorMode()
    } else {
        state.setup_screen_state.panel_left.scroll.y = 0
    }
    current_panel_x += panel_width + dynamic_x_padding
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height}, &state.setup_screen_state.panel_mid, "Entities in combat")
    state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_mid.scroll.y

    state.setup_screen_state.panel_mid.height_needed = ((LINE_HEIGHT + PANEL_PADDING) * cast(f32)state.setup_screen_state.num_entities-1) + PANEL_PADDING

    if (state.setup_screen_state.panel_mid.height_needed > state.setup_screen_state.panel_mid.rec.height) {
        state.setup_screen_state.panel_mid.content_rec.width = panel_width - 14
        state.setup_screen_state.panel_mid.content_rec.height = state.setup_screen_state.panel_mid.height_needed
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        rl.GuiScrollPanel(state.setup_screen_state.panel_mid.rec, nil, state.setup_screen_state.panel_mid.content_rec, &state.setup_screen_state.panel_mid.scroll, &state.setup_screen_state.panel_mid.view)
        rl.BeginScissorMode(cast(i32)state.setup_screen_state.panel_mid.view.x, cast(i32)state.setup_screen_state.panel_mid.view.y, cast(i32)state.setup_screen_state.panel_mid.view.width, cast(i32)state.setup_screen_state.panel_mid.view.height)
    } else {
        state.setup_screen_state.panel_mid.content_rec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
    }

    {
        state.cursor.x += PANEL_PADDING
        state.cursor.y += PANEL_PADDING

        start_x := state.cursor.x
        start_y := state.cursor.y

        for i in 0 ..< state.setup_screen_state.num_entities {
            if rl.CheckCollisionRecs({state.cursor.x, state.cursor.y, draw_width, LINE_HEIGHT}, {state.setup_screen_state.panel_mid.rec.x, state.setup_screen_state.panel_mid.rec.y, state.setup_screen_state.panel_mid.rec.width, state.setup_screen_state.panel_mid.rec.height}) {
                state.setup_screen_state.entity_button_states[i].index = i
                if GuiEntityButtonClickable({state.cursor.x, state.cursor.y, draw_width - LINE_HEIGHT, LINE_HEIGHT}, &state.setup_screen_state.entity_button_states[i]) {
                    state.setup_screen_state.selected_entity = &state.setup_screen_state.entities_selected[i]
                    state.setup_screen_state.selected_entity_idx = i
                    state.setup_screen_state.initiative_input.text = cstr(state.setup_screen_state.entities_selected[i].initiative)
                }
                state.cursor.x += draw_width - LINE_HEIGHT

                if GuiButton({state.cursor.x, state.cursor.y, LINE_HEIGHT, LINE_HEIGHT}, rl.GuiIconText(.ICON_CROSS, "")) {
                    ordered_remove(&state.setup_screen_state.entity_button_states, i)
                    state.setup_screen_state.num_entities -= 1

                    if (&state.setup_screen_state.entities_selected[i] == state.setup_screen_state.selected_entity) {
                        state.setup_screen_state.selected_entity     = nil
                        state.setup_screen_state.selected_entity_idx = 0
                    } else if (i < state.setup_screen_state.selected_entity_idx) {
                        state.setup_screen_state.selected_entity_idx -= 1
                        state.setup_screen_state.selected_entity = &state.setup_screen_state.entities_selected[state.setup_screen_state.selected_entity_idx]
                    }

                    for j in i ..< state.setup_screen_state.num_entities {
                        if j < state.setup_screen_state.num_entities {
                            state.setup_screen_state.entities_selected[j] = state.setup_screen_state.entities_selected[j+1]
                            state.setup_screen_state.entity_button_states[j].entity = &state.setup_screen_state.entities_selected[j]
                        }
                        state.setup_screen_state.entity_button_states[j].index -= 1
                    }
                }
            }
            state.cursor.x = start_x
            state.cursor.y += LINE_HEIGHT + PANEL_PADDING
        }
    }

    if (state.setup_screen_state.panel_mid.height_needed > state.setup_screen_state.panel_mid.rec.height) {
        rl.EndScissorMode()
    } else {
        state.setup_screen_state.panel_mid.scroll.y = 0
    }
    current_panel_x += panel_width + dynamic_x_padding
    state.cursor.x = current_panel_x
    state.cursor.y = panel_y

    GuiPanel({state.cursor.x, state.cursor.y, panel_width, panel_height}, &state.setup_screen_state.panel_right, "Entity Info")
    state.cursor.y += LINE_HEIGHT + state.setup_screen_state.panel_right.scroll.y

    if (state.setup_screen_state.panel_right.height_needed > state.setup_screen_state.panel_right.rec.height) {
        state.setup_screen_state.panel_right.content_rec.width = panel_width - 14
        state.setup_screen_state.panel_right.content_rec.height = state.setup_screen_state.panel_right.height_needed
        rl.GuiScrollPanel(state.setup_screen_state.panel_right.rec, nil, state.setup_screen_state.panel_right.content_rec, &state.setup_screen_state.panel_right.scroll, &state.setup_screen_state.panel_right.view)
        rl.BeginScissorMode(cast(i32)state.setup_screen_state.panel_right.view.x, cast(i32)state.setup_screen_state.panel_right.view.y, cast(i32)state.setup_screen_state.panel_right.view.width, cast(i32)state.setup_screen_state.panel_right.view.height)
    } else {
        state.setup_screen_state.panel_right.content_rec.width = panel_width
    }

    {
        state.cursor.x += PANEL_PADDING
        state.cursor.y += PANEL_PADDING

        start_y := state.cursor.y
        
        GuiEntityStats({state.cursor.x, state.cursor.y, state.setup_screen_state.panel_right.content_rec.width - (PANEL_PADDING * 2), 0}, state.setup_screen_state.selected_entity, &state.setup_screen_state.initiative_input)
        state.setup_screen_state.panel_right.height_needed = state.cursor.y - start_y
    }

    if (state.setup_screen_state.panel_right.height_needed > state.setup_screen_state.panel_right.rec.height) {
        rl.EndScissorMode()
    } else {
        state.setup_screen_state.panel_right.scroll.y = 0
    }
}

filter_entities :: proc() {
    delete_soa(state.setup_screen_state.entities_searched)
    state.setup_screen_state.entities_searched = make_soa_dynamic_array(#soa[dynamic]Entity)

    if len(str(state.setup_screen_state.entity_search_state.text)) > 0 {
        search_str := strings.to_lower(str(state.setup_screen_state.entity_search_state.text), allocator=frame_alloc)
        for entity, i in state.setup_screen_state.entities_filtered {
            names_split := strings.split(strings.to_lower(str(entity.name), allocator=frame_alloc), " ", allocator=frame_alloc)
            for name, j in names_split {
                name_to_test := name
                for k in j+1..<len(names_split) {
                    name_to_test = strings.join([]string{name_to_test, names_split[k]}, " ", allocator=frame_alloc)
                }
                if len(search_str) <= len(name_to_test) {
                    if name_to_test[:len(search_str)] == search_str {
                        append_soa(&state.setup_screen_state.entities_searched, entity)
                    }
                }
            }
        }
    } else {
        state.setup_screen_state.entities_searched = state.setup_screen_state.entities_filtered
    }
}

