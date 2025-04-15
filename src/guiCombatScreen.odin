#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"
import "core:time"
import rl "vendor:raylib"

frame := 0
popup := false

GuiDrawCombatScreen :: proc(combatState: ^CombatScreenState) {
  using state.gui_properties

  defer GuiMessageBoxQueue(&combatState.message_queue)

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  if (frame == 60) {
    combat_to_json(combatState^) 
    frame = 0
  }
  defer frame += 1
  
  initial_text_size := TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)
    
  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    state.current_screen_state = state.setup_screen_state
    combatState.first_load = true
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_ARROW_LEFT, ""))) {
    //Go back to previous turn
    if (combatState.current_entity_index == 0) {
      if (combatState.current_round > 1) {
        combatState.current_entity_index = cast(i32)len(combatState.entities) - 1
        combatState.current_round -= 1
        combatState.panel_left_top.scroll.y = -(combatState.panel_left_top.contentRec.height - combatState.panel_left_top.rec.height)
      }
    } else {
      combatState.current_entity_index -= 1
      if combatState.panel_left_top.scroll.y < 0 {
        combatState.panel_left_top.scroll.y += LINE_HEIGHT + PANEL_PADDING
      }
    }
    combatState.current_entity = &combatState.entities[combatState.current_entity_index]
    combatState.from_dropdown.selected = combatState.current_entity_index
    time.stopwatch_reset(&combatState.turn_timer)
    if (combatState.combat_timer.running) {
      time.stopwatch_start(&combatState.turn_timer)
    }
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
    
  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_ARROW_RIGHT, ""))) {
    //Go to next turn
    if (combatState.current_entity_index == cast(i32)len(combatState.entities) - 1) {
      combatState.current_entity_index = 0
      combatState.current_round += 1
      combatState.panel_left_top.scroll.y = 0
    } else {
      combatState.current_entity_index += 1
      if combatState.panel_left_top.scroll.y >= -(combatState.panel_left_top.contentRec.height - combatState.panel_left_top.rec.height) {
        combatState.panel_left_top.scroll.y -= LINE_HEIGHT + PANEL_PADDING
      }
    }
    combatState.current_entity = &combatState.entities[combatState.current_entity_index]
    combatState.from_dropdown.selected = combatState.current_entity_index
    time.stopwatch_reset(&combatState.turn_timer)
    if (combatState.combat_timer.running) {
      time.stopwatch_start(&combatState.turn_timer)
    }
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  TEXT_SIZE = TEXT_SIZE_TITLE
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)  

  available_title_width := state.window_width - cursor_x - PADDING_RIGHT - (MENU_BUTTON_WIDTH * 2) - (MENU_BUTTON_PADDING * 2)
  fit_text("Combat Control", available_title_width, &TEXT_SIZE)
  rl.GuiLabel({cursor_x, cursor_y, available_title_width, MENU_BUTTON_HEIGHT}, "Combat Control")
  cursor_x += available_title_width + MENU_BUTTON_PADDING
    
  TEXT_SIZE = initial_text_size
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_PLAY, "") if (!combatState.combat_timer.running) else rl.GuiIconText(.ICON_PLAYER_PAUSE, ""))) {
    if !combatState.combat_timer.running {
      time.stopwatch_start(&combatState.combat_timer)
      time.stopwatch_start(&combatState.turn_timer)
    } else {
      time.stopwatch_stop(&combatState.combat_timer)
      time.stopwatch_stop(&combatState.turn_timer)
    } 
  }

  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
    
  combat_time := fmt.ctprint(time.clock_from_stopwatch(combatState.combat_timer), sep=":")
  fit_text(combat_time, (state.window_height / 8), &TEXT_SIZE)
  rl.GuiLabel({(state.window_width * 0.975) - ((state.window_height / 8) * 2) -20, (state.window_height / 8) + 10, (state.window_height / 8), 40}, combat_time)
    
  if (GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_STOP, ""))) {
    //End the combat, do statistics, output files etc.
    //Display key details to the web client.
    initial_allocator := context.allocator
    context.allocator = context.temp_allocator

    temp_entities_list := load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH)
    defer delete_soa(temp_entities_list)
      
    player_count := 0
    for entity, i in combatState.entities {
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
    context.allocator = initial_allocator
    new_message := GuiMessageBoxState{}
    init_message_box(&new_message, "Notification!", fmt.caprintf("%v entities saved", player_count))
    addMessage(&combatState.message_queue, new_message)
    reload_entities()
  }
  cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING
  cursor_x = PADDING_LEFT
    
  add_button_x := cursor_x
  add_button_y := cursor_y

  defer if GuiButton({add_button_x, add_button_y, (state.window_width / 3.5) / 2, LINE_HEIGHT}, &combatState.add_entity_button) {
    combatState.remove_entity_mode = false
    combatState.remove_entity_button.text = "Remove"
    combatState.add_entity_mode = !combatState.add_entity_mode
    if combatState.add_entity_mode {
      combatState.add_entity_button.text = "Cancel"
    } else {
      combatState.add_entity_button.text = "Add"
    }
  }
  cursor_x += (state.window_width / 3.5) / 2
    
  remove_button_x := cursor_x
  remove_button_y := cursor_y
  defer if GuiButton({remove_button_x, remove_button_y, (state.window_width / 3.5) / 2, LINE_HEIGHT}, &combatState.remove_entity_button) {
    combatState.add_entity_mode = false
    combatState.add_entity_button.text = "Add"
    combatState.remove_entity_mode = !combatState.remove_entity_mode
    if combatState.remove_entity_mode {
      combatState.remove_entity_button.text = "Cancel"
    } else {
      combatState.remove_entity_button.text = "Remove"
    }
  }

  cursor_x = (state.window_width - PADDING_RIGHT) - ((MENU_BUTTON_WIDTH * 2) + MENU_BUTTON_PADDING)
    
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 20)
  rl.GuiLabel({cursor_x, cursor_y, (MENU_BUTTON_WIDTH * 2) + MENU_BUTTON_PADDING, LINE_HEIGHT}, cstr("IP:", state.ip_str, ":", state.config.PORT, sep=""))
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 30)
    
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING
  current_panel_x := cursor_x
  panel_y := cursor_y
 
  draw_width : f32 = state.window_width - PADDING_LEFT - PADDING_RIGHT
  draw_height : f32 = state.window_height - cursor_y - PADDING_BOTTOM
  
  panel_width := state.window_width / 3.5
  panel_height := draw_height
  dynamic_x_padding : f32 = (draw_width - (3 * panel_width)) / 2

  entity_select_button_height : f32 = 50

  clear(&combatState.entity_names)

  for entity in combatState.entities {
    append(&combatState.entity_names, entity.alias)
  }
    
  if combatState.first_load {
    combatState.first_load = false
    combatState.panel_left_top.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    combatState.panel_left_bottom.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    combatState.panelMid.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    combatState.panel_right_top.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    combatState.panel_right_bottom.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }

    InitDropdownState(&combatState.from_dropdown, "From:", combatState.entity_names[:], &combatState.btn_list)
    InitDropdownSelectState(&combatState.to_dropdown, "To:", combatState.entity_names[:], &combatState.btn_list)
  }

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height / 2,
    }, "Turn Order")

  combatState.panel_left_top.rec = {
    cursor_x,
    cursor_y + entity_select_button_height if (!combatState.add_entity_mode) else cursor_y + (LINE_HEIGHT * 2),
    panel_width,
    (panel_height / 2) - entity_select_button_height,
  }

  if !combatState.add_entity_mode {
    rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)entity_select_button_height, state.config.HEADER_COLOUR)
    turn_text := fmt.ctprintf("Round %v:", combatState.current_round)
    fit_text(turn_text, panel_width / 2, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, entity_select_button_height}, cstr(turn_text))
    cursor_x += panel_width * 0.5

    TEXT_SIZE = initial_text_size
 
    turn_time := fmt.ctprint(time.clock_from_stopwatch(combatState.turn_timer), sep=":")
    fit_text(turn_time, panel_width / 2, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width, entity_select_button_height}, turn_time)
    cursor_x = current_panel_x
    cursor_y += entity_select_button_height + combatState.panel_left_top.scroll.y
    TEXT_SIZE = initial_text_size

    combatState.panel_left_top.height_needed = cast(f32)len(combatState.entities) * (LINE_HEIGHT + PANEL_PADDING) + PANEL_PADDING

    if combatState.panel_left_top.height_needed > combatState.panel_left_top.rec.height {
      combatState.panel_left_top.contentRec.width = panel_width - 14
      combatState.panel_left_top.contentRec.height = combatState.panel_left_top.height_needed
      draw_width = panel_width - (PANEL_PADDING * 2) -14
      rl.GuiScrollPanel(combatState.panel_left_top.rec, nil, combatState.panel_left_top.contentRec, &combatState.panel_left_top.scroll, &combatState.panel_left_top.view)
  
      rl.BeginScissorMode(cast(i32)combatState.panel_left_top.view.x, cast(i32)combatState.panel_left_top.view.y, cast(i32)combatState.panel_left_top.view.width, cast(i32)combatState.panel_left_top.view.height)
    } else {
      combatState.panel_left_top.contentRec.width = panel_width
      draw_width = panel_width - (PANEL_PADDING * 2)
    }
    
    {
      cursor_x += PANEL_PADDING
      cursor_y += PANEL_PADDING

      for _, i in combatState.entities {
        if !combatState.remove_entity_mode {
          combatState.entity_button_states[i].index = cast(i32)i
          GuiEntityButton({cursor_x, cursor_y, draw_width, LINE_HEIGHT}, &combatState.entity_button_states[i])
          if (cast(i32)i == combatState.current_entity_index) {
            rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)draw_width, cast(i32)LINE_HEIGHT, rl.ColorAlpha(rl.BLUE, 0.2))
          }
        } else {
          default_highlight := state.config.BUTTON_HOVER_COLOUR
          state.config.BUTTON_HOVER_COLOUR = rl.RED
          defer state.config.BUTTON_HOVER_COLOUR = default_highlight
          combatState.entity_button_states[i].index = cast(i32)i
          if GuiEntityButtonClickable({cursor_x, cursor_y, draw_width, LINE_HEIGHT}, &combatState.entity_button_states[i]) {
            ordered_remove(&combatState.entities, i)
            if combatState.current_entity_index > cast(i32)i {
              combatState.current_entity_index -= 1
            }
              ordered_remove(&combatState.entity_button_states, i)
              combatState.current_entity = &combatState.entities[combatState.current_entity_index]
              clear(&combatState.entity_names)
              for entity in combatState.entities {
                append(&combatState.entity_names, entity.alias)
              }

              InitDropdownState(&combatState.from_dropdown, "From:", combatState.entity_names[:], &combatState.btn_list)
              InitDropdownSelectState(&combatState.to_dropdown, "To:", combatState.entity_names[:], &combatState.btn_list)
                        
              combatState.remove_entity_mode = false
              combatState.remove_entity_button.text = "Remove"
            }
          }
          cursor_y += entity_select_button_height + PANEL_PADDING
          TEXT_SIZE = 30
          rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
        }
      }

      if combatState.panel_left_top.height_needed > combatState.panel_left_top.rec.height {
        rl.EndScissorMode()
      } else {
        combatState.panel_left_top.scroll.y = 0
      }
    } else {
      switch GuiTabControl({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, &state.setup_screen_state.filter_tab) {
      case 0: state.setup_screen_state.entities_filtered = state.srd_entities
      case 1: state.setup_screen_state.entities_filtered = state.custom_entities
      }
      cursor_y += LINE_HEIGHT

      rl.GuiLabel({cursor_x, cursor_y, panel_width * 0.2, LINE_HEIGHT}, rl.GuiIconText(.ICON_LENS, ""))
      cursor_x += panel_width * 0.2

      GuiTextInput({cursor_x, cursor_y, panel_width * 0.8, LINE_HEIGHT}, &state.setup_screen_state.entity_search_state)
      cursor_x = current_panel_x
      cursor_y += LINE_HEIGHT + combatState.panel_left_top.scroll.y
    
      filterEntities(&state.setup_screen_state)
        
      combatState.panel_left_top.height_needed = cast(f32)len(state.setup_screen_state.entities_searched) * (LINE_HEIGHT + PANEL_PADDING) + PANEL_PADDING

      if (combatState.panel_left_top.height_needed > combatState.panel_left_top.rec.height) {
        combatState.panel_left_top.contentRec.width = panel_width - 14
        combatState.panel_left_top.contentRec.height = combatState.panel_left_top.height_needed
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        rl.GuiScrollPanel(combatState.panel_left_top.rec, nil, combatState.panel_left_top.contentRec, &combatState.panel_left_top.scroll, &combatState.panel_left_top.view)
        rl.BeginScissorMode(cast(i32)combatState.panel_left_top.view.x, cast(i32)combatState.panel_left_top.view.y, cast(i32)combatState.panel_left_top.view.width, cast(i32)combatState.panel_left_top.view.height)
      } else {
        combatState.panel_left_top.contentRec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
      }

      {
        cursor_x += PANEL_PADDING
        cursor_y += PANEL_PADDING
        for &entity in state.setup_screen_state.entities_searched {
          fit_text(entity.name, combatState.panel_left_top.contentRec.width, &state.gui_properties.TEXT_SIZE)
          if GuiButton({cursor_x, cursor_y, draw_width, LINE_HEIGHT}, entity.name) {
            match_count := 0
            for selected_entity in combatState.entities {
              if selected_entity.name == entity.name {
                match_count += 1
              }
            }
            if match_count > 0 {
              entity.alias = fmt.caprint(entity.name, match_count + 1)
            }
            append(&combatState.entities, entity)
            entity_button_state := EntityButtonState{}
            InitEntityButtonState(&entity_button_state, &combatState.entities, cast(i32)len(&combatState.entities)-1)
            append(&combatState.entity_button_states, entity_button_state)
            combatState.current_entity = &combatState.entities[combatState.current_entity_index]
            clear(&combatState.entity_names)
            for entity in combatState.entities {
              append(&combatState.entity_names, entity.alias)
            }

            InitDropdownState(&combatState.from_dropdown, "From:", combatState.entity_names[:], &combatState.btn_list)
            InitDropdownSelectState(&combatState.to_dropdown, "To:", combatState.entity_names[:], &combatState.btn_list)

            combatState.add_entity_mode = false
            combatState.add_entity_button.text = "Add"
          }
          cursor_y += LINE_HEIGHT + PANEL_PADDING
          TEXT_SIZE = initial_text_size
          rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
        }
      }
        
      if (combatState.panel_left_top.height_needed > combatState.panel_left_top.rec.height) {
        rl.EndScissorMode()
      } else {
        combatState.panel_left_top.scroll.y = 0
      }
    log.debugf("Sorted scissoring")
  }

  cursor_x = current_panel_x
  cursor_y = panel_y + (panel_height / 2)

  y_offset : f32 = 50

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height / 2,
    },
    "Selected entity info")

  combatState.panel_left_bottom.rec = {
    cursor_x,
    cursor_y + y_offset,
    panel_width,
    (panel_height / 2) - y_offset,
  }

  font_size: i32 = 25
  padding := rl.GuiGetStyle(.TEXTBOX, cast(i32)rl.GuiControlProperty.TEXT_PADDING)

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 25)

  switch GuiTabControl({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, &combatState.view_entity_tab_state) {
  case 0:
    combatState.panel_left_bottom_text = combatState.view_entity.traits
  case 1:
    combatState.panel_left_bottom_text = combatState.view_entity.actions
  case 2:
    combatState.panel_left_bottom_text = combatState.view_entity.legendary_actions
  }
  cursor_y += LINE_HEIGHT + combatState.panel_left_bottom.scroll.y

  if (combatState.panel_left_bottom.height_needed > combatState.panel_left_bottom.rec.height - y_offset) {
    combatState.panel_left_bottom.contentRec.width = panel_width - 14
    combatState.panel_left_bottom.contentRec.height = combatState.panel_left_bottom.height_needed
    draw_width = panel_width - (PANEL_PADDING * 2) - 14
    rl.GuiLine({combatState.panel_left_bottom.rec.x, combatState.panel_left_bottom.rec.y, combatState.panel_left_bottom.rec.width, 5}, "")
    rl.GuiScrollPanel(combatState.panel_left_bottom.rec, nil, combatState.panel_left_bottom.contentRec, &combatState.panel_left_bottom.scroll, &combatState.panel_left_bottom.view)
    rl.BeginScissorMode(cast(i32)combatState.panel_left_bottom.view.x, cast(i32)combatState.panel_left_bottom.view.y, cast(i32)combatState.panel_left_bottom.view.width, cast(i32)combatState.panel_left_bottom.view.height)
  } else {
    combatState.panel_left_bottom.contentRec.width = panel_width
    draw_width = panel_width - (PANEL_PADDING * 2)
  }

  {
    start_y := cursor_y
    
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_WORD)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_TOP)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_LINE_SPACING, 25)

    if combatState.panel_left_bottom_text != "" {
      lines_needed := getTextLinesNeeded(combatState.panel_left_bottom_text, combatState.panel_left_bottom.contentRec.width - (cast(f32)padding * 2), font_size)
      rl.GuiTextBox({cursor_x, cursor_y, combatState.panel_left_bottom.contentRec.width, cast(f32)lines_needed * 28}, combatState.panel_left_bottom_text, font_size, false)
      cursor_y += cast(f32)lines_needed * 28
    }
    combatState.panel_left_bottom.height_needed = (cursor_y - start_y)
  }
  
  if (combatState.panel_right_bottom.height_needed > combatState.panel_left_bottom.rec.height - y_offset) {
    rl.EndScissorMode()
  } else {
    combatState.panel_left_bottom.scroll.y = 0
  }
  
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE)
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE)


  current_panel_x += panel_width + dynamic_x_padding
  cursor_x = current_panel_x
  cursor_y = panel_y

  line_height_mid : f32 = 50

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    },
    "Combat Controls")
  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)50, state.config.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, 50}, "Combat Controls")
  cursor_y += 50

  cursor_x += PANEL_PADDING
  cursor_y += PANEL_PADDING

  draw_width = panel_width - (PANEL_PADDING * 2)
  draw_height = panel_height - line_height_mid - PANEL_PADDING - 50
        
  cursor_x_from_dropdown := cursor_x
  cursor_y_from_dropdown := cursor_y

  cursor_x += draw_width / 2
 
  cursor_x_to_dropdown := cursor_x
  cursor_y_to_dropdown := cursor_y

  cursor_x = current_panel_x + PANEL_PADDING
  cursor_y += line_height_mid + PANEL_PADDING 
    
  combatState.panelMid.rec = {
    cursor_x - PANEL_PADDING,
    cursor_y,
    panel_width,
    draw_height - PANEL_PADDING,
  }

  scroll_locked := false
  for _, btn in combatState.btn_list {
    if btn^ {
      scroll_locked = true
    }
  }
 
  if (combatState.panelMid.height_needed > draw_height) {
    combatState.panelMid.contentRec.width = panel_width - 14
    combatState.panelMid.contentRec.height = combatState.panelMid.height_needed
    draw_width = panel_width - (PANEL_PADDING * 2) - 14
    rl.GuiLine({combatState.panelMid.rec.x, combatState.panelMid.rec.y, combatState.panelMid.rec.width, 5}, "") 
    if !scroll_locked {
      rl.GuiScrollPanel(combatState.panelMid.rec, nil, combatState.panelMid.contentRec, &combatState.panelMid.scroll, &combatState.panelMid.view)
    }
    rl.BeginScissorMode(cast(i32)combatState.panelMid.view.x, cast(i32)combatState.panelMid.view.y, cast(i32)combatState.panelMid.view.width, cast(i32)combatState.panelMid.view.height)
  } else {
    combatState.panelMid.contentRec.width = panel_width
    draw_width = panel_width - (PANEL_PADDING * 2)
  }

  {
    combatState.panelMid.height_needed = 0

    cursor_y += PANEL_PADDING + combatState.panelMid.scroll.y
    combatState.panelMid.height_needed += PANEL_PADDING
    start_y := cursor_y
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Damage")
    cursor_x += draw_width / 2

    cursor_x_dmg_type := cursor_x
    cursor_y_dmg_type := cursor_y

    GuiDropdownControl({cursor_x_dmg_type, cursor_y_dmg_type, draw_width / 2, line_height_mid}, &combatState.dmg_type_dropdown)
    register_button(&combatState.btn_list, &combatState.dmg_type_dropdown)
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    if combatState.panelMid.height_needed > draw_height {
      rl.BeginScissorMode(cast(i32)combatState.panelMid.view.x, cast(i32)combatState.panelMid.view.y, cast(i32)combatState.panelMid.view.width, cast(i32)combatState.panelMid.view.height)
    }

    fit_text("Amount:", draw_width / 3, &TEXT_SIZE)
    TEXT_SIZE = initial_text_size
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
    cursor_x += draw_width / 3

    GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.dmg_input)
    cursor_x += draw_width / 3

    fit_text("Resolve", draw_width / 3, &TEXT_SIZE)
    TEXT_SIZE = initial_text_size
    if GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") && (!combatState.to_dropdown.active) {
      resolve_damage(combatState)
    }
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Healing")
    cursor_y += line_height_mid + PANEL_PADDING
        
    fit_text("Amount:", draw_width / 3, &state.gui_properties.TEXT_SIZE)
    TEXT_SIZE = initial_text_size
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
    cursor_x += draw_width / 3
 
    GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.heal_input)
    cursor_x += draw_width / 3
        
    fit_text("Resolve", draw_width / 3, &TEXT_SIZE)
    TEXT_SIZE = initial_text_size
    if GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") && (!combatState.to_dropdown.active) {
      resolve_healing(combatState)
    }
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width, line_height_mid}, "Temp HP")
    cursor_y += line_height_mid + PANEL_PADDING
        
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
    cursor_x += draw_width / 3
        
    GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.temp_HP_input)
    cursor_x += draw_width / 3
   
    if GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") {
      resolve_temp_HP(combatState)
    }
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width, line_height_mid}, "Conditions")
    cursor_y += line_height_mid + PANEL_PADDING
 
    cursor_x_conditions := cursor_x
    cursor_y_conditions := cursor_y

    GuiDropdownSelectControl({cursor_x_conditions, cursor_y_conditions, draw_width / 2, line_height_mid}, &combatState.condition_dropdown)
    register_button(&combatState.btn_list, &combatState.condition_dropdown)
    cursor_x += draw_width / 2

    if combatState.panelMid.height_needed > draw_height {
      rl.BeginScissorMode(cast(i32)combatState.panelMid.view.x, cast(i32)combatState.panelMid.view.y, cast(i32)combatState.panelMid.view.width, cast(i32)combatState.panelMid.view.height)
    }

    if GuiButton({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Apply") {
      resolve_conditions(combatState)
    }
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Temp")
    cursor_x += draw_width / 2
        
    rl.GuiToggleSlider({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Vulnerability;Resistance;Immunity", &combatState.toggle_active)
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING

    GuiDropdownSelectControl({cursor_x, cursor_y, draw_width / 2, line_height_mid}, &combatState.temp_resist_immunity_dropdown)
    register_button(&combatState.btn_list, &combatState.temp_resist_immunity_dropdown)
    cursor_x += draw_width / 2

    if combatState.panelMid.height_needed > draw_height {
      rl.BeginScissorMode(cast(i32)combatState.panelMid.view.x, cast(i32)combatState.panelMid.view.y, cast(i32)combatState.panelMid.view.width, cast(i32)combatState.panelMid.view.height)
    }

    if GuiButton({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Apply") {
      resolve_temp_resistance_or_immunity(combatState)
    }
    cursor_y += line_height_mid + PANEL_PADDING
    combatState.panelMid.height_needed = cursor_y - start_y + PANEL_PADDING
  }
  
  if (combatState.panelMid.height_needed > draw_height) {
    rl.EndScissorMode()
  } else {
    combatState.panelMid.scroll.y = 0
  }

  GuiDropdownControl({cursor_x_from_dropdown, cursor_y_from_dropdown, draw_width / 2, line_height_mid}, &combatState.from_dropdown)
  register_button(&combatState.btn_list, &combatState.from_dropdown)

  GuiDropdownSelectControl({cursor_x_to_dropdown, cursor_y_to_dropdown, draw_width / 2, line_height_mid}, &combatState.to_dropdown)
  register_button(&combatState.btn_list, &combatState.to_dropdown)
  //Stats and info for the currently selected entity.
  current_panel_x += panel_width + dynamic_x_padding
  cursor_x = current_panel_x
  cursor_y = panel_y

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height / 2,
    },
    "Entity Info")
 
  combatState.panel_right_top.rec = {
    cursor_x,
    cursor_y + y_offset,
    panel_width,
    (panel_height / 2) - y_offset,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, 50, state.config.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, 50}, "Entity Info")
  cursor_y += LINE_HEIGHT + combatState.panel_right_top.scroll.y
  state.cursor_y = cursor_y
    
  if (combatState.panel_right_top.height_needed > combatState.panel_right_top.rec.height - y_offset) {
    combatState.panel_right_top.contentRec.width = panel_width - 14
    combatState.panel_right_top.contentRec.height = combatState.panel_right_top.height_needed
    rl.GuiScrollPanel(combatState.panel_right_top.rec, nil, combatState.panel_right_top.contentRec, &combatState.panel_right_top.scroll, &combatState.panel_right_top.view)

    rl.BeginScissorMode(cast(i32)combatState.panel_right_top.view.x, cast(i32)combatState.panel_right_top.view.y, cast(i32)combatState.panel_right_top.view.width, cast(i32)combatState.panel_right_top.view.height)
  } else {
    combatState.panel_right_top.contentRec.width = panel_width
  }
    
  {
    cursor_x += PANEL_PADDING
    start_y := state.cursor_y
    GuiEntityStats({cursor_x, cursor_y, combatState.panel_right_top.contentRec.width - (PANEL_PADDING * 2), 0}, combatState.current_entity)
    combatState.panel_right_top.height_needed = state.cursor_y - start_y
  }

  if (combatState.panel_right_top.height_needed > combatState.panel_right_top.rec.height - y_offset) {
    rl.EndScissorMode()
  } else {
    combatState.panel_right_top.scroll.y = 0
  }

  cursor_x = current_panel_x
  cursor_y = panel_y + (panel_height / 2)

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height / 2,
    },
    "Entity abilities")
    
  combatState.panel_right_bottom.rec = {
    cursor_x,
    cursor_y + y_offset,
    panel_width,
    (panel_height / 2) - y_offset,
  }

  switch GuiTabControl({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, &state.entity_stats_tab_state) {
  case 0:
    combatState.panel_right_bottom_text = combatState.current_entity.traits
  case 1:
    combatState.panel_right_bottom_text = combatState.current_entity.actions
  case 2:
    combatState.panel_right_bottom_text = combatState.current_entity.legendary_actions
  }
  cursor_y += LINE_HEIGHT + combatState.panel_right_bottom.scroll.y
  state.cursor_y = cursor_y
    
  if (combatState.panel_right_bottom.height_needed > combatState.panel_right_bottom.rec.height - y_offset) {
    combatState.panel_right_bottom.contentRec.width = panel_width - 14
    combatState.panel_right_bottom.contentRec.height = combatState.panel_right_bottom.height_needed
    rl.GuiScrollPanel(combatState.panel_right_bottom.rec, nil, combatState.panel_right_bottom.contentRec, &combatState.panel_right_bottom.scroll, &combatState.panel_right_bottom.view)

    rl.BeginScissorMode(cast(i32)combatState.panel_right_bottom.view.x, cast(i32)combatState.panel_right_bottom.view.y, cast(i32)combatState.panel_right_bottom.view.width, cast(i32)combatState.panel_right_bottom.view.height)
  } else {
    combatState.panel_right_bottom.contentRec.width = panel_width
  }

  {
    start_y := cursor_y
    
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_WORD)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_TOP)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_LINE_SPACING, 25)

    if combatState.panel_right_bottom_text != "" {
      lines_needed := getTextLinesNeeded(combatState.panel_right_bottom_text, combatState.panel_right_bottom.contentRec.width - (cast(f32)padding * 2), font_size)
      rl.GuiTextBox({cursor_x, cursor_y, combatState.panel_right_bottom.contentRec.width, cast(f32)lines_needed * 28}, combatState.panel_right_bottom_text, font_size, false)
      cursor_y += cast(f32)lines_needed * 28
    }
    combatState.panel_right_bottom.height_needed = (cursor_y - start_y)
  }

  if (combatState.panel_right_bottom.height_needed > combatState.panel_right_bottom.rec.height - y_offset) {
    rl.EndScissorMode()
  } else {
    combatState.panel_right_bottom.scroll.y = 0
  }
  
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE)
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE)
}

dropdownRec: rl.Rectangle
dropdownContentRec: rl.Rectangle
dropdownView: rl.Rectangle
dropdownScroll: rl.Vector2

resolve_damage :: proc(combatState: ^CombatScreenState) {
  dmg_amount : i32 = to_i32(combatState.dmg_input.text)

  switch combatState.dmg_type_dropdown.labels[combatState.dmg_type_dropdown.selected] {
  case "Any": combatState.dmg_type_selected = .ANY
  case "Slashing": combatState.dmg_type_selected = .SLASHING
  case "Piercing": combatState.dmg_type_selected = .PIERCING
  case "Bludgeoning": combatState.dmg_type_selected = .BLUDGEONING
  case "Non-magical": combatState.dmg_type_selected = .NON_MAGICAL
  case "Poison": combatState.dmg_type_selected = .POISON
  case "Acid": combatState.dmg_type_selected = .ACID
  case "Fire": combatState.dmg_type_selected = .FIRE
  case "Cold": combatState.dmg_type_selected = .COLD
  case "Radiant": combatState.dmg_type_selected = .RADIANT
  case "Necrotic": combatState.dmg_type_selected = .NECROTIC
  case "Lightning": combatState.dmg_type_selected = .LIGHTNING
  case "Thunder": combatState.dmg_type_selected = .THUNDER
  case "Force": combatState.dmg_type_selected = .FORCE
  case "Psychic": combatState.dmg_type_selected = .PSYCHIC
  }
    
  for &entity, i in combatState.entities {
    if (combatState.to_dropdown.selected[i]) {
      if combatState.dmg_type_selected not_in entity.dmg_immunities && combatState.dmg_type_selected not_in entity.temp_dmg_immunities {
        if combatState.dmg_type_selected in entity.dmg_resistances {
          dmg_amount /= 2
        } else if combatState.dmg_type_selected in entity.dmg_vulnerabilities || combatState.dmg_type_selected in entity.temp_dmg_vulnerabilities {
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
    combatState.to_dropdown.selected[i] = false
  }
}

resolve_healing :: proc(combatState: ^CombatScreenState) {
  heal_amount : i32 = to_i32(combatState.heal_input.text)
    
  for &entity, i in combatState.entities {
    if (combatState.to_dropdown.selected[i]) {
      entity.HP += heal_amount
      is_entity_over_max(&entity)
    }
    combatState.to_dropdown.selected[i] = false
  }
}

resolve_temp_HP :: proc(combatState: ^CombatScreenState) {
  HP_amount : i32 = to_i32(combatState.temp_HP_input.text)

  for &entity, i in combatState.entities {
    if (combatState.to_dropdown.selected[i]) {
      entity.temp_HP = HP_amount if (HP_amount > entity.temp_HP) else entity.temp_HP
    }
    combatState.to_dropdown.selected[i] = false
  }
}

resolve_conditions :: proc(combatState: ^CombatScreenState) {
  for &entity, i in combatState.entities {
    if combatState.to_dropdown.selected[i] {
      entity.conditions = ConditionSet{}
      for condition, j in combatState.condition_dropdown.labels {
        if combatState.condition_dropdown.selected[j] {
          switch strings.to_lower(str(condition)) {
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
          combatState.condition_dropdown.selected[j] = false
        }
      }
    }
    combatState.to_dropdown.selected[i] = false
  }
}

resolve_temp_resistance_or_immunity :: proc(combatState: ^CombatScreenState) {
  if combatState.toggle_active == 0 {
    for &entity, i in combatState.entities {
      if combatState.to_dropdown.selected[i] {
        entity.temp_dmg_resistances = DamageSet{}
        for dmg_type, j in combatState.temp_resist_immunity_dropdown.labels {
          if combatState.temp_resist_immunity_dropdown.selected[j] {
            log.debugf("Found one: %v, %v", dmg_type, j)
            switch strings.to_lower(str(dmg_type)) {
            case "slashing": entity.temp_dmg_vulnerabilities |= {.SLASHING}
            case "piercing": entity.temp_dmg_vulnerabilities |= {.PIERCING}
            case "bludgeoning": entity.temp_dmg_vulnerabilities |= {.BLUDGEONING}
            case "non-magical": entity.temp_dmg_vulnerabilities |= {.NON_MAGICAL}
            case "poison": entity.temp_dmg_vulnerabilities |= {.POISON}
            case "acid": entity.temp_dmg_vulnerabilities |= {.ACID}
            case "fire": entity.temp_dmg_vulnerabilities |= {.FIRE}
            case "cold": entity.temp_dmg_vulnerabilities |= {.COLD}
            case "radiant": entity.temp_dmg_vulnerabilities |= {.RADIANT}
            case "necrotic": entity.temp_dmg_vulnerabilities |= {.NECROTIC}
            case "lightning": entity.temp_dmg_vulnerabilities |= {.LIGHTNING}
            case "thunder": entity.temp_dmg_vulnerabilities |= {.THUNDER}
            case "force": entity.temp_dmg_vulnerabilities |= {.FORCE}
            case "psychic": entity.temp_dmg_vulnerabilities |= {.PSYCHIC}
            }
            log.debugf("Removing one: %v", j)
            combatState.temp_resist_immunity_dropdown.selected[j] = false
          }
        }
      }
      combatState.to_dropdown.selected[i] = false
    }
  } else if combatState.toggle_active == 1 {
    for &entity, i in combatState.entities {
      if combatState.to_dropdown.selected[i] {
        entity.temp_dmg_resistances = DamageSet{}
        for dmg_type, j in combatState.temp_resist_immunity_dropdown.labels {
          if combatState.temp_resist_immunity_dropdown.selected[j] {
            log.debugf("Found one: %v, %v", dmg_type, j)
            switch strings.to_lower(str(dmg_type)) {
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
            combatState.temp_resist_immunity_dropdown.selected[j] = false
          }
        }
      }
      combatState.to_dropdown.selected[i] = false
    }
  } else if combatState.toggle_active == 2 {
    for &entity, i in combatState.entities {
      if combatState.to_dropdown.selected[i] {
        entity.temp_dmg_immunities = DamageSet{}
        for dmg_type, j in combatState.temp_resist_immunity_dropdown.labels {
          if combatState.temp_resist_immunity_dropdown.selected[j] {
            log.debugf("Found one: %v, %v", dmg_type, j)
            switch strings.to_lower(str(dmg_type)) {
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
            combatState.temp_resist_immunity_dropdown.selected[j] = false
          }
        }
      }
      combatState.to_dropdown.selected[i] = false
      log.debugf("Entity: %v, new resistances: %v", entity.name, entity.dmg_resistances)
    }
  }
}
