package main

import "core:fmt"
import rl "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"

SettingsState ::struct {
  first_load: bool,
  entities_dir: TextInputState,
  entities_file_input: TextInputState,
  custom_entities_input: TextInputState,
  webpage_file_inpit: TextInputState,
  combats_dir_input: TextInputState,
}

InitSettingsState :: proc(settingsState: ^SettingsState) {
  settingsState.first_load = true
  InitTextInputState(&settingsState.entities_dir)
  InitTextInputState(&settingsState.entities_file_input)
  InitTextInputState(&settingsState.custom_entities_input)
  InitTextInputState(&settingsState.webpage_file_inpit)
  InitTextInputState(&settingsState.combats_dir_input)
}

GuiDrawSettingsScreen :: proc(settingsState: ^SettingsState) {
  using state.gui_properties

  if (settingsState.first_load) {
    settingsState.entities_file_input.text = cstr(CONFIG.ENTITY_FILE_PATH)
    settingsState.entities_dir.text = cstr(CONFIG.CUSTOM_ENTITY_PATH)
    settingsState.custom_entities_input.text = cstr(CONFIG.CUSTOM_ENTITY_FILE)
    settingsState.webpage_file_inpit.text = cstr(CONFIG.WEBPAGE_FILE_PATH)
    settingsState.combats_dir_input.text = cstr(CONFIG.COMBAT_FILES_PATH)
    settingsState.first_load = false
  }

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  TEXT_SIZE = TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    CONFIG.ENTITY_FILE_PATH = fmt.tprint(settingsState.entities_file_input.text)
    CONFIG.CUSTOM_ENTITY_PATH = fmt.tprint(settingsState.entities_dir.text)
    CONFIG.CUSTOM_ENTITY_FILE = fmt.tprint(settingsState.custom_entities_input.text)
    CONFIG.WEBPAGE_FILE_PATH = fmt.tprint(settingsState.webpage_file_inpit.text)
    CONFIG.COMBAT_FILES_PATH = fmt.tprint(settingsState.combats_dir_input.text)
    SAVE_CONFIG(CONFIG)
    settingsState.first_load = true
    state.current_view_index -= 1
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
  cursor_x = PADDING_LEFT
  cursor_y += LINE_HEIGHT + PANEL_PADDING
  
}
