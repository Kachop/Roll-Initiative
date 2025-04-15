#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import rl "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"
import "core:strconv"

GuiDrawSetupScreen :: proc(setupState: ^SetupScreenState, combatState: ^CombatScreenState) {
  using state.gui_properties

  defer GuiMessageBoxQueue(&setupState.message_queue)
  
  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  start_x : f32 = cursor_x

  initial_text_size := TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    setupState.first_load = true
    state.current_screen_state = state.title_screen_state
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_OPEN, ""))) {
    state.current_screen_state = state.load_screen_state
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_TITLE)

  available_title_width := state.window_width - cursor_x - (MENU_BUTTON_WIDTH * 2) - (MENU_BUTTON_PADDING * 2) - PADDING_RIGHT
  fit_text("Combat Setup", available_title_width, &TEXT_SIZE)
  rl.GuiLabel({cursor_x, cursor_y, available_title_width, MENU_BUTTON_HEIGHT}, "Combat Setup")
  cursor_x += available_title_width + MENU_BUTTON_PADDING

  TEXT_SIZE = initial_text_size
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_SAVE, ""))) {
    new_message := GuiMessageBoxState{}
    if write_combat_file(str(state.config.COMBAT_FILES_PATH, FILE_SEPERATOR, setupState.filename_input.text, ".combat", sep="")) {
      init_message_box(&new_message, "Notification!", fmt.caprint(setupState.filename_input.text, ".combat saved!", sep=""))
      addMessage(&setupState.message_queue, new_message)
    } else {
      log.debugf("File path: %v", str(state.config.COMBAT_FILES_PATH, FILE_SEPERATOR, setupState.filename_input.text, ".combat", sep=""))
      init_message_box(&new_message, "Error!", "Failed to save file.")
      addMessage(&setupState.message_queue, new_message)
    }
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_PLAY, ""))) {
    if len(setupState.entities_selected) > 0 {
      for &entity in setupState.entities_selected {
        if (entity.initiative == 0) {
          entity_roll_initiative(&entity)
        }
      }
      combatState.entities = setupState.entities_selected
      order_by_initiative(&combatState.entities)
      combatState.current_entity_index = 0
      combatState.current_entity = &combatState.entities[combatState.current_entity_index]
      combatState.view_entity_index = 0
      combatState.view_entity = &combatState.entities[combatState.view_entity_index]
      
      for entity, i in setupState.entity_button_states {
        entity_button_state := EntityButtonState{}
        InitEntityButtonState(&entity_button_state, &combatState.entities, cast(i32)i)
        append(&combatState.entity_button_states, entity_button_state)
      }

      state.current_screen_state = state.combat_screen_state
    } else {
      new_message := GuiMessageBoxState{}
      init_message_box(&new_message, "Warning!", "No combatants added.")
      addMessage(&setupState.message_queue, new_message)
    }
  }
  cursor_x = start_x
  cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

  text_width := cast(f32)getTextWidth("Combat name: ", state.gui_properties.TEXT_SIZE)
  rl.GuiLabel({cursor_x, cursor_y, text_width, LINE_HEIGHT}, "Combat name: ")
  cursor_x += text_width + PANEL_PADDING
  GuiTextInput({cursor_x, cursor_y, 400, LINE_HEIGHT}, &setupState.filename_input)
  cursor_x = start_x
  cursor_y += LINE_HEIGHT + MENU_BUTTON_PADDING
  current_panel_x := cursor_x
  panel_y := cursor_y
  draw_width : f32 = state.window_width - PADDING_LEFT - PADDING_RIGHT
  draw_height : f32 = state.window_height - cursor_y - PADDING_BOTTOM

  panel_width := state.window_width / 3.5
  panel_height := draw_height
  dynamic_x_padding : f32 = (draw_width - (3 * panel_width)) / 2
  
  if setupState.first_load {
    setupState.first_load = false

    setupState.entities_filtered = state.srd_entities
    
    setupState.panelLeft.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    setupState.panelMid.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    setupState.panelRight.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
  }

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    }, "Available entities")

  setupState.panelLeft.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT * 2,
    panel_width,
    panel_height - LINE_HEIGHT * 2,
  }

  {
    switch GuiTabControl({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, &setupState.filter_tab) {
    case 0: setupState.entities_filtered = state.srd_entities
    case 1: setupState.entities_filtered = state.custom_entities
    }
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, panel_width * 0.2, LINE_HEIGHT}, rl.GuiIconText(.ICON_LENS, ""))
    cursor_x += panel_width * 0.2

    GuiTextInput({cursor_x, cursor_y, panel_width * 0.8, LINE_HEIGHT}, &setupState.entity_search_state)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT + setupState.panelLeft.scroll.y
    
    filterEntities(setupState)

    setupState.panelLeft.height_needed = ((LINE_HEIGHT + PANEL_PADDING) * cast(f32)len(setupState.entities_searched)) + PANEL_PADDING

    if (setupState.panelLeft.height_needed > setupState.panelLeft.rec.height) {
      setupState.panelLeft.contentRec.width = panel_width - 14
      setupState.panelLeft.contentRec.height = setupState.panelLeft.height_needed
      draw_width = panel_width - (PANEL_PADDING * 2) - 14
      rl.GuiScrollPanel(setupState.panelLeft.rec, nil, setupState.panelLeft.contentRec, &setupState.panelLeft.scroll, &setupState.panelLeft.view)
      rl.BeginScissorMode(cast(i32)setupState.panelLeft.view.x, cast(i32)setupState.panelLeft.view.y, cast(i32)setupState.panelLeft.view.width, cast(i32)setupState.panelLeft.view.height)
    } else {
      setupState.panelLeft.contentRec.width = panel_width
      draw_width = panel_width - (PANEL_PADDING * 2)
    }

    {
      cursor_x += PANEL_PADDING
      cursor_y += PANEL_PADDING

      for &entity in setupState.entities_searched {
        //Check text width needed and reduce size if needed.
        fit_text(entity.name, setupState.panelLeft.contentRec.width, &state.gui_properties.TEXT_SIZE)
        if GuiButton({cursor_x, cursor_y, draw_width, LINE_HEIGHT}, entity.name) {
          match_count := 0
          for selected_entity in setupState.entities_selected {
            if selected_entity.name == entity.name {
              match_count += 1
            }
          }
          if match_count > 0 {
            entity.alias = fmt.caprint(entity.name, match_count + 1)
          }
          append(&setupState.entities_selected, entity)
          entity_button_state := EntityButtonState{}
          InitEntityButtonState(&entity_button_state, &setupState.entities_selected, cast(i32)len(setupState.entities_selected)-1)
          append(&setupState.entity_button_states, entity_button_state)
        }
        cursor_y += LINE_HEIGHT + PANEL_PADDING
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
      }
    }

    if (setupState.panelLeft.height_needed > setupState.panelLeft.rec.height) {
      rl.EndScissorMode()
    } else {
      setupState.panelLeft.scroll.y = 0
    }
  }

  current_panel_x += panel_width + dynamic_x_padding
  cursor_x = current_panel_x
  cursor_y = panel_y

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    }, "Entities in combat")
  
  setupState.panelMid.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, state.config.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "In Combat")
  cursor_y += LINE_HEIGHT + setupState.panelMid.scroll.y

    setupState.panelMid.height_needed = ((LINE_HEIGHT + PANEL_PADDING) * cast(f32)len(setupState.entities_selected)-1) + PANEL_PADDING 
    
  if (setupState.panelMid.height_needed > setupState.panelMid.rec.height) {
    setupState.panelMid.contentRec.width = panel_width - 14
    setupState.panelMid.contentRec.height = setupState.panelMid.height_needed
    draw_width = panel_width - (PANEL_PADDING * 2) - 14
    rl.GuiScrollPanel(setupState.panelMid.rec, nil, setupState.panelMid.contentRec, &setupState.panelMid.scroll, &setupState.panelMid.view)
    rl.BeginScissorMode(cast(i32)setupState.panelMid.view.x, cast(i32)setupState.panelMid.view.y, cast(i32)setupState.panelMid.view.width, cast(i32)setupState.panelMid.view.height)
    //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
  } else {
    setupState.panelMid.contentRec.width = panel_width
    draw_width = panel_width - (PANEL_PADDING * 2)
  }
  
  {
    cursor_x += PANEL_PADDING
    start_x := cursor_x
    cursor_y += PANEL_PADDING
    start_y := cursor_y

    for _, i in setupState.entities_selected {
      setupState.entity_button_states[i].index = cast(i32)i
      if GuiEntityButtonClickable({cursor_x, cursor_y, draw_width - LINE_HEIGHT, LINE_HEIGHT}, &setupState.entity_button_states[i]) {
            setupState.selected_entity = &setupState.entities_selected[i]
            setupState.selected_entity_index = i
            setupState.initiative_input.text = cstr(setupState.entities_selected[i].initiative)
        }

      cursor_x += draw_width - LINE_HEIGHT

      if rl.GuiButton(
        {
          cursor_x,
          cursor_y,
          LINE_HEIGHT,
          LINE_HEIGHT,
        },
        rl.GuiIconText(.ICON_CROSS, ""),
      ) {
        if (&setupState.entities_selected[i] == setupState.selected_entity) {
          setupState.selected_entity = nil
          setupState.selected_entity_index = 0
        } else if (i < setupState.selected_entity_index) {
          setupState.selected_entity_index -= 1
          setupState.selected_entity = &setupState.entities_selected[setupState.selected_entity_index]
        }
        ordered_remove(&setupState.entities_selected, i)
      }
      cursor_x = start_x
      cursor_y += LINE_HEIGHT + PANEL_PADDING
      TEXT_SIZE = initial_text_size
      rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
  }
  
  if (setupState.panelMid.height_needed > setupState.panelMid.rec.height) {
    rl.EndScissorMode()
  } else {
    setupState.panelMid.scroll.y = 0
  }

  current_panel_x += panel_width + dynamic_x_padding
  cursor_x = current_panel_x
  cursor_y = panel_y

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    },
    "Entity Info")
  
  setupState.panelRight.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, state.config.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Entity Info")
  cursor_y += LINE_HEIGHT + setupState.panelRight.scroll.y

  state.cursor_y = cursor_y

  if (setupState.panelRight.height_needed > setupState.panelRight.rec.height) {
    setupState.panelRight.contentRec.width = panel_width - 14
    setupState.panelRight.contentRec.height = setupState.panelRight.height_needed
    rl.GuiScrollPanel(setupState.panelRight.rec, nil, setupState.panelRight.contentRec, &setupState.panelRight.scroll, &setupState.panelRight.view)
    
    rl.BeginScissorMode(cast(i32)setupState.panelRight.view.x, cast(i32)setupState.panelRight.view.y, cast(i32)setupState.panelRight.view.width, cast(i32)setupState.panelRight.view.height)
  } else {
    setupState.panelRight.contentRec.width = panel_width
  }

  {
    cursor_x += PANEL_PADDING
    start_y := state.cursor_y
    GuiEntityStats({cursor_x, cursor_y, setupState.panelRight.contentRec.width - (PANEL_PADDING * 2), 0}, setupState.selected_entity, &setupState.initiative_input)
    setupState.panelRight.height_needed = state.cursor_y - start_y
  }

  if (setupState.panelRight.height_needed > setupState.panelRight.rec.height) {
    rl.EndScissorMode()
  } else {
    setupState.panelRight.scroll.y = 0
  }
}

filterEntities :: proc(setupState: ^SetupScreenState) {
  initial_allocator := context.allocator
  context.allocator = context.temp_allocator
  clear_soa(&setupState.entities_searched)
  setupState.entities_searched = make_soa_dynamic_array(#soa[dynamic]Entity)

  if len(fmt.tprint(setupState.entity_search_state.text)) > 0 {
    search_str := strings.to_lower(str(setupState.entity_search_state.text))
    for entity, i in setupState.entities_filtered {
      names_split := strings.split(strings.to_lower(str(entity.name)), " ")
      for name, j in names_split {
        name_to_test := name
        for k in j+1..<len(names_split) {
          name_to_test = strings.join([]string{name_to_test, names_split[k]}, " ")
        }
        if len(search_str) <= len(name_to_test) {
          if name_to_test[:len(search_str)] == search_str {
            append_soa(&setupState.entities_searched, entity)
          }
        }
      }
    }
  } else {
    setupState.entities_searched = setupState.entities_filtered
  }
  context.allocator = initial_allocator
}
