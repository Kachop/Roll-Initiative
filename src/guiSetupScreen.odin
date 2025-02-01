#+feature dynamic-literals

package main

import "core:fmt"
import rl "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"

/*
TODO:
- Finish displaying all of the selected entity details.
- Add ability to write in initiative scores for all selected entities.
*/

SetupState :: struct {
  first_load: bool,
  entities_all: #soa[dynamic]Entity,
  entities_filtered: #soa[dynamic]Entity,
  entities_selected: [dynamic]Entity,
  selected_entity: ^Entity,
  selected_entity_index: int,
  filter_dropdown: DropdownState,
  panelRecLeft: rl.Rectangle,
  panelContentRecLeft: rl.Rectangle,
  panelViewLeft: rl.Rectangle,
  panelScrollLeft: rl.Vector2,
  panelRecMid: rl.Rectangle,
  panelContentRecMid: rl.Rectangle,
  panelViewMid: rl.Rectangle,
  panelScrollMid: rl.Vector2,
  panelRecRight: rl.Rectangle,
  panelContentRecRight: rl.Rectangle,
  panelViewRight: rl.Rectangle,
  panelScrollRight: rl.Vector2,
  filename_input: TextInputState,
  initiative_input: TextInputState,
  stats_lines_needed: f32,
}

InitSetupState :: proc(setupState: ^SetupState) {
  setupState.first_load = true
  setupState.entities_all = state.srd_entities
  setupState.entities_filtered = state.srd_entities
  setupState.entities_selected = [dynamic]Entity{}
  setupState.selected_entity = nil
  setupState.selected_entity_index = 0
  entity_types := [dynamic]cstring{"Monster", "Character"}
  InitDropdownState(&setupState.filter_dropdown, "Entity type:", entity_types[:])
  setupState.panelRecLeft = {0, 0, 0, 0}
  setupState.panelContentRecLeft = {}
  setupState.panelViewLeft = {0, 0, 0, 0}
  setupState.panelScrollLeft = {0, 0}
  setupState.panelRecMid = {0, 0, 0, 0}
  setupState.panelContentRecMid = {}
  setupState.panelViewMid = {0, 0, 0, 0}
  setupState.panelScrollMid = {0, 0}
  setupState.panelRecRight = {0, 0, 0, 0}
  setupState.panelContentRecRight = {}
  setupState.panelViewRight = {0, 0, 0, 0}
  setupState.panelScrollRight = {0, 0}
  InitTextInputState(&setupState.filename_input)
  InitTextInputState(&setupState.initiative_input)
  setupState.stats_lines_needed = 0
}

GuiDrawSetupScreen :: proc(setupState: ^SetupState, combatState: ^CombatState) {
  using state.gui_properties
  
  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  start_x : f32 = cursor_x

  initial_text_size := TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    setupState.first_load = true
    state.current_view_index -= 1
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_OPEN, ""))) {
    inject_at(&state.views_list, state.current_view_index+1, View.LOAD_SCREEN)
    state.current_view_index += 1
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

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_FILE_SAVE, ""))) {
    filename_parts := []cstring{setupState.filename_input.text, ".combat"}
    filename := rl.TextJoin(raw_data(filename_parts), 2, "")
    combat := CombatFile{setupState.filename_input.text, setupState.entities_selected}
    writeCombatFile(string(filename), combat)
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_PLAY, ""))) {
    for &entity in setupState.entities_selected {
      if (entity.initiative == 0) {
        entity_roll_initiative(&entity)
      }
    }
    combatState.entities = setupState.entities_selected
    order_by_initiative(&combatState.entities)
    combatState.current_entity_index = 0
    combatState.current_entity = &combatState.entities[combatState.current_entity_index]
    inject_at(&state.views_list, state.current_view_index+1, View.COMBAT_SCREEN)
    state.current_view_index += 1
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

    setupState.entities_all = state.srd_entities
    setupState.entities_filtered = state.srd_entities
    
    setupState.panelContentRecLeft = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    setupState.panelContentRecMid = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
    setupState.panelContentRecRight = {
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

  setupState.panelRecLeft = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  num_rows_needed := len(setupState.entities_filtered)
  num_rows_max := setupState.panelRecLeft.height / LINE_HEIGHT

  {
    dropdown_x := cursor_x
    dropdown_y := cursor_y

    defer GuiDropdownControl({dropdown_x, dropdown_y, panel_width, LINE_HEIGHT}, &setupState.filter_dropdown)
    if setupState.filter_dropdown.selected == 0 {
      setupState.entities_filtered = state.srd_entities
    } else if setupState.filter_dropdown.selected == 1 {
      setupState.entities_filtered = state.custom_entities
    }

    rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, rl.GRAY)
    rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Available entities")
    cursor_y += LINE_HEIGHT + setupState.panelScrollLeft.y
  
   if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
      setupState.panelContentRecLeft.width = panel_width - 14
      setupState.panelContentRecLeft.height = (cast(f32)num_rows_needed * LINE_HEIGHT)
      rl.GuiScrollPanel(setupState.panelRecLeft, nil, setupState.panelContentRecLeft, &setupState.panelScrollLeft, &setupState.panelViewLeft)
  
      rl.BeginScissorMode(cast(i32)setupState.panelViewLeft.x, cast(i32)setupState.panelViewLeft.y, cast(i32)setupState.panelViewLeft.width, cast(i32)setupState.panelViewLeft.height)
      //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
    } else {
      setupState.panelContentRecLeft.width = panel_width
    }

    for entity in setupState.entities_filtered {
      //Check text width needed and reduce size if needed.
      fit_text(entity.name, setupState.panelContentRecLeft.width, &state.gui_properties.TEXT_SIZE)
      if rl.GuiButton({cursor_x, cursor_y, setupState.panelContentRecLeft.width, LINE_HEIGHT}, entity.name) && (!setupState.filter_dropdown.active) {
        append(&setupState.entities_selected, entity)
      }
      cursor_y += LINE_HEIGHT
      TEXT_SIZE = initial_text_size
      rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
      rl.EndScissorMode()
    } else {
      setupState.panelScrollLeft.y = 0
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
  
  setupState.panelRecMid = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, CONFIG.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "In Combat")
  cursor_y += LINE_HEIGHT + setupState.panelScrollMid.y
   
  num_rows_needed = len(setupState.entities_selected)
  num_rows_max = setupState.panelRecMid.height / LINE_HEIGHT
    
  if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
    setupState.panelContentRecMid.width = panel_width - 14
    setupState.panelContentRecMid.height = (cast(f32)num_rows_needed * LINE_HEIGHT)
    rl.GuiScrollPanel(setupState.panelRecMid, nil, setupState.panelContentRecMid, &setupState.panelScrollMid, &setupState.panelViewMid)
    
    rl.BeginScissorMode(cast(i32)setupState.panelViewMid.x, cast(i32)setupState.panelViewMid.y, cast(i32)setupState.panelViewMid.width, cast(i32)setupState.panelViewMid.height)
    //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
  } else {
    setupState.panelContentRecMid.width = panel_width
  }

  for _, i in setupState.entities_selected {
    if GuiEntityButtonClickable({cursor_x, cursor_y, setupState.panelContentRecMid.width - LINE_HEIGHT, LINE_HEIGHT}, &setupState.entities_selected, cast(i32)i) {
          setupState.selected_entity = &setupState.entities_selected[i]
          setupState.selected_entity_index = i
          setupState.initiative_input.text = cstr(setupState.entities_selected[i].initiative)
      }

    cursor_x += setupState.panelContentRecMid.width - LINE_HEIGHT

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
      //ordered_remove(&setupState.initiatives, i)
    }
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  }
  
  if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
    rl.EndScissorMode()
  } else {
    setupState.panelScrollMid.y = 0
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
  
  setupState.panelRecRight = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, CONFIG.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Entity Info")
  cursor_y += LINE_HEIGHT + setupState.panelScrollRight.y

  line_height : f32 = 50

  if (setupState.stats_lines_needed * line_height > setupState.panelRecRight.height) {
    setupState.panelContentRecRight.width = panel_width - 14
    setupState.panelContentRecRight.height = setupState.stats_lines_needed * line_height
    rl.GuiScrollPanel(setupState.panelRecRight, nil, setupState.panelContentRecRight, &setupState.panelScrollRight, &setupState.panelViewRight)
    
    rl.BeginScissorMode(cast(i32)setupState.panelViewRight.x, cast(i32)setupState.panelViewRight.y, cast(i32)setupState.panelViewRight.width, cast(i32)setupState.panelViewRight.height)
    //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
  } else {
    setupState.panelContentRecRight.width = panel_width
  }

  if (setupState.selected_entity != nil) {
    //Display info for selected entity.
    setupState.stats_lines_needed = 0
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width, line_height}, setupState.selected_entity.name)
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, "Initiative: ")
    cursor_x += setupState.panelContentRecRight.width / 2
    GuiTextInput({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, &setupState.initiative_input)
    setupState.selected_entity.initiative = str_to_int(cast(string)setupState.initiative_input.text)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, setupState.selected_entity.size)
    cursor_x += setupState.panelContentRecRight.height / 2
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, setupState.selected_entity.race)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, rl.GuiIconText(.ICON_SHIELD, int_to_str(setupState.selected_entity.AC)))
    cursor_x += setupState.panelContentRecRight.width / 2
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 2, line_height}, rl.GuiIconText(.ICON_HEART, int_to_str(setupState.selected_entity.HP)))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width, line_height}, setupState.selected_entity.speed)
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
    
    fit_text("Stat", setupState.panelContentRecRight.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "Stat")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelContentRecRight.width / 4
    fit_text("Score", setupState.panelContentRecRight.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "Score")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelContentRecRight.width / 4
    fit_text("Modifier", setupState.panelContentRecRight.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "Modifier")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += setupState.panelContentRecRight.width / 4
    fit_text("Save", setupState.panelContentRecRight.width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "Save")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "STR: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.STR))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.STR_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.STR_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "DEX: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.DEX))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.DEX_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.DEX_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "CON: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.CON))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.CON_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.CON_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "INT: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.INT))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.INT_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.INT_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "WIS: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.WIS))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.WIS_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.WIS_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, "CHA: ")
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.CHA))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.CHA_mod))
    cursor_x += setupState.panelContentRecRight.width / 4
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 4, line_height}, cstr(setupState.selected_entity.STR_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    setupState.stats_lines_needed += 1
    
    fit_text("Vulnerabilities:", setupState.panelContentRecRight.width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, LINE_HEIGHT}, "Vulnerabilities:")
    cursor_x += setupState.panelContentRecRight.width / 3
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Resistances:", setupState.panelContentRecRight.width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, line_height}, "Resistances:")
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Immunities:", setupState.panelContentRecRight.width / 3, &TEXT_SIZE)
    cursor_x += setupState.panelContentRecRight.width / 3
    rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, line_height}, "Immunities:")
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
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, LINE_HEIGHT}, cstr(vulnerability))
      cursor_y += LINE_HEIGHT
    }
    vulnerability_y = cursor_y
    cursor_x += setupState.panelContentRecRight.width / 3
    cursor_y = prev_y
    
    for resistance in resistances {
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, LINE_HEIGHT}, cstr(resistance))
      cursor_y += LINE_HEIGHT
    }
    resistance_y = cursor_y
    cursor_x += setupState.panelContentRecRight.width / 3
    cursor_y = prev_y

    for immunity in immunities {
      rl.GuiLabel({cursor_x, cursor_y, setupState.panelContentRecRight.width / 3, LINE_HEIGHT}, cstr(immunity))
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

  if (setupState.stats_lines_needed * line_height > setupState.panelRecRight.height) {
    rl.EndScissorMode()
  } else {
    setupState.panelScrollRight.y = 0
  }
}

//Filter entities list for display list. Should reconstruct the full list based on the option selected in the dropdown button.
filterEntities :: proc(setupState: ^SetupState) {
  //switch setupState.dropdown_active {
  //case 0: setupState.entities_filtered = setupState.entities_all
  //case 1: setupState.entities_filtered = state.srd_entities
  //case 2: setupState.entities_filtered = state.custom_entities
  //}
}
