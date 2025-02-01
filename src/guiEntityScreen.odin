#+feature dynamic-literals

package main

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

EntityScreenState :: struct {
  first_load: bool,
  entity_edit_mode: bool,
  entity_to_edit: i32,
  height_needed: f32,
  panelLeft: PanelState,
  panelMid: PanelState,
  panelRight: PanelState,
  img_file_paths: []string,
  border_file_paths: []string,
  icons: []rl.Texture,
  borders: []rl.Texture,
  current_icon_index: i32,
  current_border_index: i32,
  name_input: TextInputState,
  race_input: TextInputState,
  size_input: TextInputState,
  type_dropdown: DropdownState,
  AC_input: TextInputState,
  HP_input: TextInputState,
  HP_max_input: TextInputState,
  temp_HP_input: TextInputState,
  speed_input: TextInputState,
  STR_input: TextInputState,
  DEX_input: TextInputState,
  CON_input: TextInputState,
  INT_input: TextInputState,
  WIS_input: TextInputState,
  CHA_input: TextInputState,
  STR_save_input: TextInputState,
  DEX_save_input: TextInputState,
  CON_save_input: TextInputState,
  INT_save_input: TextInputState,
  WIS_save_input: TextInputState,
  CHA_save_input: TextInputState,
  DMG_vulnerable_input: TextInputState,
  DMG_resist_input: TextInputState,
  DMG_immune_input: TextInputState,
  languages_input: TextInputState,
}

InitEntityScreenState :: proc(entityScreenState: ^EntityScreenState) {
  InitPanelState(&entityScreenState.panelLeft)
  InitPanelState(&entityScreenState.panelMid)
  InitPanelState(&entityScreenState.panelRight)

  temp_path_list := [dynamic]string{}
  dir_handle, ok := os.open(fmt.tprint(CONFIG.CUSTOM_ENTITY_PATH, "images", sep=FILE_SEPERATOR))
  file_infos, err := os.read_dir(dir_handle, 0)

  reload_icons(entityScreenState)
  reload_borders(entityScreenState)

  type_options := [dynamic]cstring{"player", "NPC", "monster"}
  InitTextInputState(&entityScreenState.name_input)
  InitTextInputState(&entityScreenState.race_input)
  InitTextInputState(&entityScreenState.size_input)
  InitDropdownState(&entityScreenState.type_dropdown, "", type_options[:])
  InitTextInputState(&entityScreenState.AC_input)
  InitTextInputState(&entityScreenState.HP_input)
  InitTextInputState(&entityScreenState.HP_max_input)
  InitTextInputState(&entityScreenState.temp_HP_input)
  InitTextInputState(&entityScreenState.speed_input)
  InitTextInputState(&entityScreenState.STR_input)
  InitTextInputState(&entityScreenState.DEX_input)
  InitTextInputState(&entityScreenState.CON_input)
  InitTextInputState(&entityScreenState.INT_input)
  InitTextInputState(&entityScreenState.WIS_input)
  InitTextInputState(&entityScreenState.CHA_input)
  InitTextInputState(&entityScreenState.STR_save_input)
  InitTextInputState(&entityScreenState.DEX_save_input)
  InitTextInputState(&entityScreenState.CON_save_input)
  InitTextInputState(&entityScreenState.INT_save_input)
  InitTextInputState(&entityScreenState.WIS_save_input)
  InitTextInputState(&entityScreenState.CHA_save_input)
  InitTextInputState(&entityScreenState.DMG_vulnerable_input)
  InitTextInputState(&entityScreenState.DMG_resist_input)
  InitTextInputState(&entityScreenState.DMG_immune_input)
  InitTextInputState(&entityScreenState.languages_input)
  entityScreenState.first_load = true
}

GuiDrawEntityScreen :: proc(entityScreenState: ^EntityScreenState) {
  using state.gui_properties

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  initial_text_size := TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size)

  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
 
  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    entityScreenState.first_load = true
    state.current_view_index -= 1
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_TITLE)
  
  available_title_width := state.window_width - cursor_x - PADDING_RIGHT - MENU_BUTTON_WIDTH - MENU_BUTTON_PADDING
  fit_text("Add Entity", available_title_width, &TEXT_SIZE)
  title_width := getTextWidth("Add Entity", TEXT_SIZE)
  rl.GuiLabel({0, cursor_y, state.window_width, MENU_BUTTON_HEIGHT}, "Add Entity")
  cursor_x += available_title_width + MENU_BUTTON_PADDING

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)  

  cursor_x = PADDING_LEFT
  cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING
  current_panel_x := cursor_x
  panel_y := cursor_y

  panel_width := state.window_width / 3.5
  panel_height := state.window_height - cursor_y - PADDING_BOTTOM - MENU_BUTTON_HEIGHT - MENU_BUTTON_PADDING
  dynamic_x_padding : f32 = ((state.window_width - PADDING_LEFT - PADDING_RIGHT) - (3 * panel_width)) / 2

  if (entityScreenState.first_load) {
    //Do stuff
    fmt.println("Doing first load")
    entityScreenState.first_load = false
    entityScreenState.panelLeft.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }

    entityScreenState.panelMid.contentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0,
    }
  }

  draw_width := panel_width - (PANEL_PADDING * 2)

  rl.GuiPanel(
    {
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    }, "Edit:")

  entityScreenState.panelLeft.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, CONFIG.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Edit:")
  cursor_x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
  cursor_y += PANEL_PADDING

  if rl.GuiButton({cursor_x, cursor_y, LINE_HEIGHT - (PANEL_PADDING * 2), LINE_HEIGHT - (PANEL_PADDING * 2)}, rl.GuiIconText(.ICON_RESTART, "")) {
    reload_entities()
    set_input_values(entityScreenState)
  }
  cursor_x = current_panel_x
  cursor_y += LINE_HEIGHT + entityScreenState.panelLeft.scroll.y

  if (entityScreenState.panelLeft.height_needed > entityScreenState.panelLeft.rec.height) {
    entityScreenState.panelLeft.contentRec.width = panel_width - 14
    entityScreenState.panelLeft.contentRec.height = entityScreenState.panelLeft.height_needed
    draw_width = panel_width - (PANEL_PADDING * 2) - 14
    rl.GuiScrollPanel(entityScreenState.panelLeft.rec, nil, entityScreenState.panelLeft.contentRec, &entityScreenState.panelLeft.scroll, &entityScreenState.panelLeft.view)

    rl.BeginScissorMode(cast(i32)entityScreenState.panelLeft.view.x, cast(i32)entityScreenState.panelLeft.view.y, cast(i32)entityScreenState.panelLeft.view.width, cast(i32)entityScreenState.panelLeft.view.height)
  } else {
    entityScreenState.panelLeft.contentRec.width = panel_width
    draw_width = panel_width - (PANEL_PADDING * 2)
  }

  {
    entityScreenState.panelLeft.height_needed = 0

    cursor_x += PANEL_PADDING
    start_x := cursor_x
    cursor_y += PANEL_PADDING
    start_y := cursor_y
    entityScreenState.panelLeft.height_needed += PANEL_PADDING

    for entity, i in state.custom_entities {
      if rl.GuiButton({cursor_x, cursor_y, draw_width * 0.8, LINE_HEIGHT}, entity.name) {
        entityScreenState.entity_to_edit = cast(i32)i
        entityScreenState.entity_edit_mode = true
        set_input_values(entityScreenState)
      }
      cursor_x += draw_width * 0.8
      if rl.GuiButton({cursor_x, cursor_y, draw_width / 5, LINE_HEIGHT}, rl.GuiIconText(.ICON_BIN, "")) {
        delete_custom_entity(cast(i32)i)
      }
      cursor_x = start_x
      cursor_y += LINE_HEIGHT + PANEL_PADDING
    }
    entityScreenState.panelLeft.height_needed += cursor_y + PANEL_PADDING - start_y
  }

  if (entityScreenState.panelLeft.height_needed > entityScreenState.panelLeft.rec.height) {
    rl.EndScissorMode()
  } else {
    entityScreenState.panelLeft.scroll.y = 0
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
    }, "Entity Options")

  entityScreenState.panelMid.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  draw_width = panel_width - (PANEL_PADDING * 2)

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, CONFIG.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Entity Options")
  cursor_x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
  cursor_y += PANEL_PADDING

  if rl.GuiButton({cursor_x, cursor_y, LINE_HEIGHT - (PANEL_PADDING * 2), LINE_HEIGHT - (PANEL_PADDING * 2)}, rl.GuiIconText(.ICON_RESTART, "")) {
    entityScreenState.entity_edit_mode = false
    set_input_values(entityScreenState)
  }
  cursor_x = current_panel_x
  cursor_y += LINE_HEIGHT + entityScreenState.panelMid.scroll.y

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

  if (entityScreenState.panelMid.height_needed > entityScreenState.panelMid.rec.height) {
    entityScreenState.panelMid.contentRec.width = panel_width - 14
    entityScreenState.panelMid.contentRec.height = entityScreenState.panelMid.height_needed
    draw_width = panel_width - (PANEL_PADDING * 2) - 14
    rl.GuiScrollPanel(entityScreenState.panelMid.rec, nil, entityScreenState.panelMid.contentRec, &entityScreenState.panelMid.scroll, &entityScreenState.panelMid.view)

    rl.BeginScissorMode(cast(i32)entityScreenState.panelMid.view.x, cast(i32)entityScreenState.panelMid.view.y, cast(i32)entityScreenState.panelMid.view.width, cast(i32)entityScreenState.panelMid.view.height)
  } else {
    entityScreenState.panelMid.contentRec.width = panel_width
    draw_width = panel_width - (PANEL_PADDING * 2)
  }

  {
    entityScreenState.panelMid.height_needed = 0
    cursor_x += PANEL_PADDING
    cursor_y += PANEL_PADDING
    entityScreenState.panelMid.height_needed += PANEL_PADDING

    start_x := cursor_x
    start_y := cursor_y
  
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Name:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.name_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Race:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.race_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING
  
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Size:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.size_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Type:")
    cursor_x += draw_width / 2

    dropdown_cursor_x := cursor_x
    dropdown_cursor_y := cursor_y
    
    entityScreenState.type_dropdown.title = entityScreenState.type_dropdown.labels[entityScreenState.type_dropdown.selected]

    defer GuiDropdownControl({dropdown_cursor_x, dropdown_cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.type_dropdown)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "AC:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.AC_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "HP max:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.HP_max_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Current HP:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.HP_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Speed:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.speed_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Ability")
    cursor_x += draw_width / 4
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Score")
    cursor_x += draw_width / 4
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Mod")
    cursor_x += draw_width / 4
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "Save")
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "STR:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.STR_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod := get_modifier(str_to_int(entityScreenState.STR_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.STR_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "DEX:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.DEX_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod = get_modifier(str_to_int(entityScreenState.DEX_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.DEX_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "CON:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.CON_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod = get_modifier(str_to_int(entityScreenState.CON_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.CON_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "INT:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.INT_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod = get_modifier(str_to_int(entityScreenState.INT_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.INT_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "WIS:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.WIS_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod = get_modifier(str_to_int(entityScreenState.WIS_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.WIS_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, "CHA:")
    cursor_x += draw_width / 4
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.CHA_input)
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    mod = get_modifier(str_to_int(entityScreenState.CHA_input.text))
    rl.GuiLabel({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, fmt.ctprintf("+%v" if mod >= 0 else "%v", mod))
    cursor_x += draw_width / 4
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
    GuiTextInput({cursor_x, cursor_y, draw_width / 4, TEXT_INPUT_HEIGHT}, &entityScreenState.CHA_save_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Vulnerabilities:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.DMG_vulnerable_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Resistances:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.DMG_resist_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Immunities:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.DMG_immune_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING

    rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, "Languages:")
    cursor_x += draw_width / 2
    GuiTextInput({cursor_x, cursor_y, draw_width / 2, TEXT_INPUT_HEIGHT}, &entityScreenState.languages_input)
    cursor_x = start_x
    cursor_y += TEXT_INPUT_HEIGHT + PANEL_PADDING
  
    entityScreenState.panelMid.height_needed = cursor_y + PANEL_PADDING - start_y
  }

  if (entityScreenState.panelMid.height_needed > panel_height) {
    rl.EndScissorMode()
  } else {
    entityScreenState.panelMid.scroll.y = 0
  }
  cursor_x = current_panel_x
  cursor_y = panel_y + panel_height + MENU_BUTTON_PADDING
  
  rl.GuiSetStyle(.BUTTON, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)

  if (rl.GuiButton({cursor_x, cursor_y, panel_width, MENU_BUTTON_HEIGHT}, "Add" if !entityScreenState.entity_edit_mode else "Save")) {
      entity_type: EntityType
      switch entityScreenState.type_dropdown.labels[entityScreenState.type_dropdown.selected] {
      case "player": entity_type = .PLAYER
      case "NPC": entity_type = .NPC
      case "monster": entity_type = .MONSTER
      }
      new_entitiy := Entity{
          entityScreenState.name_input.text,
          entityScreenState.race_input.text,
          entityScreenState.size_input.text,
          entity_type,
          0,
          str_to_int(string(entityScreenState.AC_input.text)),
          str_to_int(string(entityScreenState.HP_max_input.text)),
          str_to_int(string(entityScreenState.HP_input.text)),
          str_to_int(string(entityScreenState.temp_HP_input.text)),
          true,
          true,
          entityScreenState.speed_input.text,
          str_to_int(string(entityScreenState.STR_input.text)),
          get_modifier(str_to_int(entityScreenState.STR_input.text)),
          str_to_int(string(entityScreenState.STR_save_input.text)),
          str_to_int(string(entityScreenState.DEX_input.text)),
          get_modifier(str_to_int(entityScreenState.DEX_input.text)),
          str_to_int(string(entityScreenState.DEX_save_input.text)),
          str_to_int(string(entityScreenState.CON_input.text)),
          get_modifier(str_to_int(entityScreenState.CON_input.text)),
          str_to_int(string(entityScreenState.CON_save_input.text)),
          str_to_int(string(entityScreenState.INT_input.text)),
          get_modifier(str_to_int(entityScreenState.INT_input.text)),
          str_to_int(string(entityScreenState.INT_save_input.text)),
          str_to_int(string(entityScreenState.WIS_input.text)),
          get_modifier(str_to_int(entityScreenState.WIS_input.text)),
          str_to_int(string(entityScreenState.WIS_save_input.text)),
          str_to_int(string(entityScreenState.CHA_input.text)),
          get_modifier(str_to_int(entityScreenState.CHA_input.text)),
          str_to_int(string(entityScreenState.CHA_save_input.text)),
          "",
          get_vulnerabilities_resistances_or_immunities(strings.split(string(entityScreenState.DMG_vulnerable_input.text), ", ")),
          get_vulnerabilities_resistances_or_immunities(strings.split(string(entityScreenState.DMG_resist_input.text), ", ")),
          get_vulnerabilities_resistances_or_immunities(strings.split(string(entityScreenState.DMG_immune_input.text), ", ")),
          get_condition_immunities(strings.split(string(""), ", ")),
          "",
          entityScreenState.languages_input.text,
          "",
          "",
          "",
          "",
          cstr(entityScreenState.img_file_paths[entityScreenState.current_icon_index]),
          cstr(entityScreenState.border_file_paths[entityScreenState.current_border_index]),
      }
      if !entityScreenState.entity_edit_mode {
          add_entity_to_file(new_entitiy)
      } else {
          //Edit file. Re-write whole file with current entity being replaced.
          temp_entities_list := load_entities_from_file(CONFIG.CUSTOM_ENTITY_FILE_PATH)
          defer delete_soa(temp_entities_list)
          temp_entities_list[entityScreenState.entity_to_edit] = new_entitiy
          for entity, i in temp_entities_list {
              if i == 0 {
                  add_entity_to_file(entity, wipe=true)
              } else {
                  add_entity_to_file(entity)
              }
          }
      }
      reload_entities()
      entityScreenState.entity_edit_mode = false
      set_input_values(entityScreenState)
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
    }, "Icon Options:")

  entityScreenState.panelRight.rec = {
    cursor_x,
    cursor_y + LINE_HEIGHT,
    panel_width,
    panel_height - LINE_HEIGHT,
  }

  draw_width = panel_width - (PANEL_PADDING * 2)

  rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)LINE_HEIGHT, CONFIG.HEADER_COLOUR)
  rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Icon options")
  cursor_x += panel_width - (LINE_HEIGHT - (PANEL_PADDING * 2)) - PANEL_PADDING
  cursor_y += PANEL_PADDING

  if rl.GuiButton({cursor_x, cursor_y, LINE_HEIGHT - (PANEL_PADDING * 2), LINE_HEIGHT - (PANEL_PADDING * 2)}, rl.GuiIconText(.ICON_RESTART, "")) {
    reload_icons(entityScreenState)
    reload_borders(entityScreenState)
  }
  cursor_x = current_panel_x
  cursor_y += LINE_HEIGHT + PANEL_PADDING + entityScreenState.panelRight.scroll.y

  {
    cursor_x += PANEL_PADDING
    start_x := cursor_x

    if len(entityScreenState.icons) > 0 {
      rl.GuiButton({cursor_x, cursor_y, PANEL_PADDING * 3, 128}, rl.GuiIconText(.ICON_ARROW_LEFT_FILL, ""))
      cursor_x = start_x
      cursor_x += (draw_width / 2) - 64
      rl.DrawTexture(entityScreenState.icons[entityScreenState.current_icon_index], cast(i32)cursor_x, cast(i32)cursor_y, rl.WHITE)
      cursor_x = start_x + panel_width - (PANEL_PADDING * 5)
      rl.GuiButton({cursor_x, cursor_y, PANEL_PADDING * 3, 128}, rl.GuiIconText(.ICON_ARROW_RIGHT_FILL, ""))
      cursor_x = start_x
      cursor_y += cast(f32)entityScreenState.icons[entityScreenState.current_icon_index].height + PANEL_PADDING

      if rl.GuiButton({cursor_x, cursor_y, draw_width / 2, LINE_HEIGHT}, "Prev") {
        if entityScreenState.current_icon_index >= 1 {
          entityScreenState.current_icon_index -= 1
        } else {
          entityScreenState.current_icon_index = cast(i32)len(entityScreenState.icons) - 1
        }
      }
      cursor_x += draw_width / 2
      
      if rl.GuiButton({cursor_x, cursor_y, draw_width / 2, LINE_HEIGHT}, "Next") {
        if entityScreenState.current_icon_index < cast(i32)len(entityScreenState.icons) - 1 {
          entityScreenState.current_icon_index += 1
        } else {
          entityScreenState.current_icon_index = 0
        }
      }
    } else {
      rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "No images found")
    }
  }
}

@(private)
set_input_values :: proc(entityScreenState: ^EntityScreenState) {
  if entityScreenState.entity_edit_mode {
    entity := state.custom_entities[entityScreenState.entity_to_edit]
    entityScreenState.name_input.text = cstr(entity.name)
    entityScreenState.race_input.text = cstr(entity.race)
    entityScreenState.size_input.text = cstr(entity.size)
    switch entity.type {
    case .PLAYER: entityScreenState.type_dropdown.selected = 0
    case .NPC: entityScreenState.type_dropdown.selected = 1
    case .MONSTER: entityScreenState.type_dropdown.selected = 2
    }
    entityScreenState.AC_input.text = cstr(entity.AC)
    entityScreenState.HP_max_input.text = cstr(entity.HP_max)
    entityScreenState.HP_input.text = cstr(entity.HP)
    entityScreenState.temp_HP_input.text = cstr(entity.temp_HP)
    entityScreenState.STR_input.text = cstr(entity.STR)
    entityScreenState.STR_save_input.text = cstr(entity.STR_save)
    entityScreenState.DEX_input.text = cstr(entity.DEX)
    entityScreenState.DEX_save_input.text = cstr(entity.DEX_save)
    entityScreenState.CON_input.text = cstr(entity.CON)
    entityScreenState.CON_save_input.text = cstr(entity.CON_save)
    entityScreenState.INT_input.text = cstr(entity.INT)
    entityScreenState.INT_save_input.text = cstr(entity.INT_save)
    entityScreenState.WIS_input.text = cstr(entity.WIS)
    entityScreenState.WIS_save_input.text = cstr(entity.WIS_save)
    entityScreenState.CHA_input.text = cstr(entity.CHA)
    entityScreenState.CHA_save_input.text = cstr(entity.CHA_save)
    entityScreenState.DMG_vulnerable_input.text = cstr(strings.join(gen_vulnerability_resistance_or_immunity_string(entity.dmg_vulnerabilities), ", "))
    entityScreenState.DMG_resist_input.text = cstr(strings.join(gen_vulnerability_resistance_or_immunity_string(entity.dmg_resistances), ", "))
    entityScreenState.DMG_immune_input.text = cstr(strings.join(gen_vulnerability_resistance_or_immunity_string(entity.dmg_immunities), ", "))
    entityScreenState.languages_input.text = cstr(entity.languages)
    for file_path, i in entityScreenState.img_file_paths {
      if cstr(file_path) == entity.img_url {
        entityScreenState.current_icon_index = cast(i32)i
      }
    }
  } else {
    //Set everything to default options. Will happen when some clear button is clicked.
    entityScreenState.name_input.text = cstr("")
    entityScreenState.race_input.text = cstr("")
    entityScreenState.size_input.text = cstr("")
    entityScreenState.type_dropdown.selected = 0
    entityScreenState.AC_input.text = cstr("")
    entityScreenState.HP_max_input.text = cstr("")
    entityScreenState.HP_input.text = cstr("")
    entityScreenState.temp_HP_input.text = cstr("")
    entityScreenState.STR_input.text = cstr("")
    entityScreenState.STR_save_input.text = cstr("")
    entityScreenState.DEX_input.text = cstr("")
    entityScreenState.DEX_save_input.text = cstr("")
    entityScreenState.CON_input.text = cstr("")
    entityScreenState.CON_save_input.text = cstr("")
    entityScreenState.INT_input.text = cstr("")
    entityScreenState.INT_save_input.text = cstr("")
    entityScreenState.WIS_input.text = cstr("")
    entityScreenState.WIS_save_input.text = cstr("")
    entityScreenState.CHA_input.text = cstr("")
    entityScreenState.CHA_save_input.text = cstr("")
    entityScreenState.DMG_vulnerable_input.text = cstr("")
    entityScreenState.DMG_resist_input.text = cstr("")
    entityScreenState.DMG_immune_input.text = cstr("")
    entityScreenState.languages_input.text = cstr("")
    entityScreenState.current_icon_index = 0
  }
}

@(private)
delete_custom_entity :: proc(index: i32) {
  ordered_remove_soa(&state.custom_entities, index)

  for entity, i in state.custom_entities {
    if i == 0 {add_entity_to_file(entity, wipe=true)} else {add_entity_to_file(entity)}
  }
}

@(private)
reload_icons :: proc(entityScreenState: ^EntityScreenState) {
  delete(entityScreenState.img_file_paths)
  delete(entityScreenState.icons)
  //entityScreenState.img_file_paths = []string{}

  for texture in entityScreenState.icons {
    rl.UnloadTexture(texture)
  }

  temp_path_list := [dynamic]string{}
  dir_handle, ok := os.open(fmt.tprint(CONFIG.CUSTOM_ENTITY_PATH, "images", sep=FILE_SEPERATOR))
  defer os.close(dir_handle)
  file_infos, err := os.read_dir(dir_handle, 0)

  for file in file_infos {
    if !file.is_dir {
      if strings.split(file.name, ".")[1] == "png" {
        fmt.println(file.name)
        append(&temp_path_list, file.fullpath)
      }
    }
  }
  entityScreenState.img_file_paths = temp_path_list[:]
  
  temp_texture_list := [dynamic]rl.Texture{}
  for img_path in entityScreenState.img_file_paths {
    temp_img := rl.LoadImage(cstr(img_path))
    defer rl.UnloadImage(temp_img)
    if (temp_img.width != 128) || (temp_img.height != 128) {
      rl.ImageResize(&temp_img, 128, 128)
    }
    texture := rl.LoadTextureFromImage(temp_img)
    append(&temp_texture_list, texture)
  }
  entityScreenState.icons = temp_texture_list[:]
  entityScreenState.current_icon_index = 0
}

@(private)
reload_borders :: proc(entityScreenState: ^EntityScreenState) {
  delete(entityScreenState.border_file_paths)
  delete(entityScreenState.borders)
  //entityScreenState.img_file_paths = []string{}

  for texture in entityScreenState.borders {
    rl.UnloadTexture(texture)
  }

  temp_path_list := [dynamic]string{}
  dir_handle, ok := os.open(fmt.tprint(app_dir, "images", sep=FILE_SEPERATOR))
  defer os.close(dir_handle)
  file_infos, err := os.read_dir(dir_handle, 0)

  for file in file_infos {
    if !file.is_dir {
      if strings.split(file.name, ".")[1] == "png" {
        append(&temp_path_list, file.fullpath)
      }
    }
  }
  entityScreenState.border_file_paths = temp_path_list[:]
  
  temp_texture_list := [dynamic]rl.Texture{}
  for border_path in entityScreenState.border_file_paths {
    temp_border := rl.LoadImage(cstr(border_path))
    defer rl.UnloadImage(temp_border)
    if (temp_border.width != 128) || (temp_border.height != 128) {
      rl.ImageResize(&temp_border, 128, 128)
    }
    texture := rl.LoadTextureFromImage(temp_border)
    append(&temp_texture_list, texture)
  }
  entityScreenState.borders = temp_texture_list[:]
  entityScreenState.current_border_index = 0
}
