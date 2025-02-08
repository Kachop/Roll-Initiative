package main

import "core:fmt"
import rl "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"

GuiDrawSettingsScreen :: proc(settingsState: ^SettingsScreenState) {
  using state.gui_properties

  if (settingsState.first_load) {
    settingsState.entities_file_input.text = cstr(state.config.ENTITY_FILE_PATH[len(#directory)+3:])
    settingsState.entities_dir.text = cstr(state.config.CUSTOM_ENTITY_PATH[len(#directory)+3:])
    settingsState.custom_entities_input.text = cstr(state.config.CUSTOM_ENTITY_FILE)
    settingsState.webpage_file_inpit.text = cstr(state.config.WEBPAGE_FILE_PATH[len(#directory)+3:])
    settingsState.combats_dir_input.text = cstr(state.config.COMBAT_FILES_PATH[len(#directory)+3:])
    settingsState.first_load = false
  }

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  TEXT_SIZE = TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    settingsState.first_load = true
    state.current_screen_state = state.title_screen_state
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_TITLE)

  title_width := getTextWidth("Settings", TEXT_SIZE_TITLE)
  title_x : f32 = (state.window_width / 2) - cast(f32)(title_width / 2)
  rl.GuiLabel({title_x, cursor_y, cast(f32)title_width, MENU_BUTTON_HEIGHT}, "Settings")
  cursor_x = PADDING_LEFT
  cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)

  label_widths := 250 + state.gui_properties.PADDING_ICONS
  
  rl.GuiLabel({cursor_x, cursor_y, 250, LINE_HEIGHT}, "SRD entities: ")
  cursor_x += label_widths
  GuiTextInput({cursor_x, cursor_y, 500, LINE_HEIGHT}, &settingsState.entities_file_input)
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING

  rl.GuiLabel({cursor_x, cursor_y, 250, LINE_HEIGHT}, "Custom entities:")
  cursor_x += label_widths
  GuiTextInput({cursor_x, cursor_y, 500, LINE_HEIGHT}, &settingsState.entities_dir)
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING
  
  rl.GuiLabel({cursor_x, cursor_y, 250, LINE_HEIGHT}, "Custom entities file:")
  cursor_x += label_widths
  GuiTextInput({cursor_x, cursor_y, 500, LINE_HEIGHT}, &settingsState.custom_entities_input)
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING

  rl.GuiLabel({cursor_x, cursor_y, 250, LINE_HEIGHT}, "Webpage file path: ")
  cursor_x += label_widths
  GuiTextInput({cursor_x, cursor_y, 500, LINE_HEIGHT}, &settingsState.webpage_file_inpit)
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING

  rl.GuiLabel({cursor_x, cursor_y, 250, LINE_HEIGHT}, "Combat files dir: ")
  cursor_x += label_widths
  GuiTextInput({cursor_x, cursor_y, 500, LINE_HEIGHT}, &settingsState.combats_dir_input)
  cursor_y += LINE_HEIGHT + PANEL_PADDING

  if rl.GuiButton({cursor_x, cursor_y, 500, LINE_HEIGHT}, "Save") {
    state.config.ENTITY_FILE_PATH = fmt.tprint(settingsState.entities_file_input.text)
    state.config.CUSTOM_ENTITY_PATH = fmt.tprint(settingsState.entities_dir.text)
    state.config.CUSTOM_ENTITY_FILE = fmt.tprint(settingsState.custom_entities_input.text)
    state.config.WEBPAGE_FILE_PATH = fmt.tprint(settingsState.webpage_file_inpit.text)
    state.config.COMBAT_FILES_PATH = fmt.tprint(settingsState.combats_dir_input.text)
    SAVE_CONFIG(state.config)
    LOAD_CONFIG(&state.config)
  }
  cursor_y += LINE_HEIGHT + PANEL_PADDING
}
