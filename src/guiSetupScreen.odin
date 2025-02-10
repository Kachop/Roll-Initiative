#+feature dynamic-literals

package main

import "core:fmt"
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
    filename_parts := []cstring{setupState.filename_input.text, ".combat"}
    filename := rl.TextJoin(raw_data(filename_parts), 2, "")
    combat := CombatFile{setupState.filename_input.text, setupState.entities_selected}
    writeCombatFile(string(filename), combat)
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
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  {
    switch GuiTabControl({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, &setupState.filter_tab) {
    case 0: setupState.entities_filtered = state.srd_entities
    case 1: setupState.entities_filtered = state.custom_entities
    }
    cursor_y += LINE_HEIGHT + setupState.panelLeft.scroll.y

    setupState.panelLeft.height_needed = ((LINE_HEIGHT + PANEL_PADDING) * cast(f32)len(setupState.entities_filtered)) + PANEL_PADDING

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

      for entity in setupState.entities_filtered {
        //Check text width needed and reduce size if needed.
        fit_text(entity.name, setupState.panelLeft.contentRec.width, &state.gui_properties.TEXT_SIZE)
        if rl.GuiButton({cursor_x, cursor_y, draw_width, LINE_HEIGHT}, entity.name) {
          append(&setupState.entities_selected, entity)
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
      if GuiEntityButtonClickable({cursor_x, cursor_y, draw_width - LINE_HEIGHT, LINE_HEIGHT}, &setupState.entities_selected, cast(i32)i) {
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

  line_height : f32 = 50

  if (setupState.stats_lines_needed * line_height > setupState.panelRight.rec.height) {
    setupState.panelRight.contentRec.width = panel_width - 14
    setupState.panelRight.contentRec.height = setupState.stats_lines_needed * line_height
    rl.GuiScrollPanel(setupState.panelRight.rec, nil, setupState.panelRight.contentRec, &setupState.panelRight.scroll, &setupState.panelRight.view)
    
    rl.BeginScissorMode(cast(i32)setupState.panelRight.view.x, cast(i32)setupState.panelRight.view.y, cast(i32)setupState.panelRight.view.width, cast(i32)setupState.panelRight.view.height)
  } else {
    setupState.panelRight.contentRec.width = panel_width
  }

  if (setupState.selected_entity != nil) {
    //Display info for selected entity.
    setupState.stats_lines_needed = 0
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width, line_height}, setupState.selected_entity.name)
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, "Initiative: ")
    cursor_x += setupState.panelRight.contentRec.width / 2
    GuiTextInput({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, &setupState.initiative_input)
    setupState.selected_entity.initiative = to_i32(setupState.initiative_input.text)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, setupState.selected_entity.size)
    cursor_x += setupState.panelRight.contentRec.height / 2
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, setupState.selected_entity.race)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, rl.GuiIconText(.ICON_SHIELD, cstr(setupState.selected_entity.AC)))
    cursor_x += setupState.panelRight.contentRec.width / 2
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 2, line_height}, rl.GuiIconText(.ICON_HEART, cstr(setupState.selected_entity.HP)))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width, line_height}, setupState.selected_entity.speed)
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
    
    fit_text("Stat", setupState.panelRight.contentRec.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "Stat")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelRight.contentRec.width / 4
    fit_text("Score", setupState.panelRight.contentRec.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "Score")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelRight.contentRec.width / 4
    fit_text("Modifier", setupState.panelRight.contentRec.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "Modifier")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelRight.contentRec.width / 4
    fit_text("Save", setupState.panelRight.contentRec.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "Save")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "STR: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.STR))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.STR_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.STR_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "DEX: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.DEX))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.DEX_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.DEX_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "CON: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.CON))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.CON_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.CON_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "INT: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.INT))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.INT_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.INT_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "WIS: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.WIS))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.WIS_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.WIS_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, "CHA: ")
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.CHA))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.CHA_mod))
    cursor_x += setupState.panelRight.contentRec.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 4, line_height}, cstr(setupState.selected_entity.STR_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
    
    fit_text("Vulnerabilities:", setupState.panelRight.contentRec.width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, LINE_HEIGHT}, "Vulnerabilities:")
    cursor_x += setupState.panelRight.contentRec.width / 3
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Resistances:", setupState.panelRight.contentRec.width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, line_height}, "Resistances:")
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Immunities:", setupState.panelRight.contentRec.width / 3, &TEXT_SIZE)
    cursor_x += setupState.panelRight.contentRec.width / 3
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, line_height}, "Immunities:")
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    
    vulnerabilities : []string = gen_vulnerability_resistance_or_immunity_string(setupState.selected_entity.dmg_vulnerabilities)
    resistances : []string = gen_vulnerability_resistance_or_immunity_string(setupState.selected_entity.dmg_resistances)
    immunities : []string = gen_vulnerability_resistance_or_immunity_string(setupState.selected_entity.dmg_immunities)

    vulnerability_y, resistance_y, immunity_y: f32
    prev_y := cursor_y

    for vulnerability in vulnerabilities {
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, LINE_HEIGHT}, cstr(vulnerability))
      cursor_y += LINE_HEIGHT
    }
    vulnerability_y = cursor_y
    cursor_x += setupState.panelRight.contentRec.width / 3
    cursor_y = prev_y
    
    for resistance in resistances {
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, LINE_HEIGHT}, cstr(resistance))
      cursor_y += LINE_HEIGHT
    }
    resistance_y = cursor_y
    cursor_x += setupState.panelRight.contentRec.width / 3
    cursor_y = prev_y

    for immunity in immunities {
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelRight.contentRec.width / 3, LINE_HEIGHT}, cstr(immunity))
      cursor_y += LINE_HEIGHT
    }
    immunity_y = cursor_y
    cursor_x = current_panel_x
    
    if ((len(resistances) >= len(immunities)) && (len(resistances) >= len(vulnerabilities))) {
      cursor_y = resistance_y
    } else if ((len(immunities) >= len(resistances)) && (len(immunities) >= len(vulnerabilities))) {
      cursor_y = immunity_y
    } else {
      cursor_y = vulnerability_y
    }

    setupState.stats_lines_needed += cast(f32)i32((cursor_y - prev_y) / LINE_HEIGHT)

    rl.GuiLabel({cursor_x, cursor_y, panel_width, line_height}, "Skills:")
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
    skills := strings.split(cast(string)setupState.selected_entity.skills, ", ")
    for skill in skills {
      rl.GuiLabel({cursor_x, cursor_y, panel_width, line_height}, cstr(skill))
      cursor_y += LINE_HEIGHT
      setupState.stats_lines_needed += 1
    }
    rl.GuiLabel({cursor_x, cursor_y, panel_width, line_height}, setupState.selected_entity.CR)
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
  }

  if (setupState.stats_lines_needed * line_height > setupState.panelRight.rec.height) {
    rl.EndScissorMode()
  } else {
    setupState.panelRight.scroll.y = 0
  }
}

//Filter entities list for display list. Should reconstruct the full list based on the option selected in the dropdown button.
filterEntities :: proc(setupState: ^SetupScreenState) {
  //switch setupState.dropdown_active {
  //case 0: setupState.entities_filtered = setupState.entities_all
  //case 1: setupState.entities_filtered = state.srd_entities
  //case 2: setupState.entities_filtered = state.custom_entities
  //}
}
