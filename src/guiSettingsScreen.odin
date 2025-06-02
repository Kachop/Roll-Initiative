package main

import "core:fmt"
import "core:log"
import rl "vendor:raylib"
import "core:strings"
import "core:unicode/utf8"
import "core:os"

/*
TODO: Add some sort of error indicators next to fields where no file can be found after saving.
*/

draw_settings_screen :: proc() {
    using state.gui_properties

    defer GuiMessageBoxQueue(&state.settings_screen_state.message_queue)

    TOTAL_WIDTH_RATIO :: 1.7
    INPUT_WIDTH_RATIO :: 3

    input_width := state.window_width / INPUT_WIDTH_RATIO
    label_width := (state.window_width / TOTAL_WIDTH_RATIO) - (state.window_width / INPUT_WIDTH_RATIO) - PANEL_PADDING
    label_x     := (state.window_width - (state.window_width / TOTAL_WIDTH_RATIO)) / 2

    if (state.settings_screen_state.first_load) {
        state.settings_screen_state.entities_file_input.text   = fmt.caprint(state.config.ENTITY_FILE_PATH[len(state.app_dir):])
        state.settings_screen_state.entities_dir.text          = fmt.caprint(state.config.CUSTOM_ENTITIES_DIR[len(state.app_dir):])
        state.settings_screen_state.custom_entities_input.text = fmt.caprint(state.config.CUSTOM_ENTITY_FILE_PATH[len(state.config.CUSTOM_ENTITIES_DIR):])
        state.settings_screen_state.webpage_file_inpit.text    = fmt.caprint(state.config.WEBPAGE_FILE_PATH[len(state.app_dir):])
        state.settings_screen_state.combats_dir_input.text     = fmt.caprint(state.config.COMBAT_FILES_DIR[len(state.app_dir):])
        state.settings_screen_state.first_load = false
   }

    state.cursor.x = PADDING_LEFT
    state.cursor.y = PADDING_TOP

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
    if (GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
        state.settings_screen_state.first_load = true
        state.current_screen_state = state.title_screen_state
        return
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
    
    TEXT_SIZE = TEXT_SIZE_TITLE
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    GuiLabel({state.cursor.x, state.cursor.y, state.window_width - (state.cursor.x * 2), MENU_BUTTON_HEIGHT}, "Settings")
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

    state.cursor.x = PADDING_LEFT
    state.cursor.y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    label_widths := 250 + state.gui_properties.PADDING_ICONS

    state.cursor.x = label_x
    GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "SRD entities: ")
    state.cursor.x += label_width + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.entities_file_input)
    state.cursor.x = label_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING

    rl.GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "Custom entities:")
    state.cursor.x += label_width + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.entities_dir)
    state.cursor.x = label_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING
  
    rl.GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "Custom entities file:")
    state.cursor.x += label_width + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.custom_entities_input)
    state.cursor.x = label_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING

    GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "Webpage file path: ")
    state.cursor.x += label_width + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.webpage_file_inpit)
    state.cursor.x = label_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING

    GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "Combat files dir: ")
    state.cursor.x += label_width + PANEL_PADDING
    GuiTextInput({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.combats_dir_input)
    state.cursor.x = label_x
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING

    GuiLabel({state.cursor.x, state.cursor.y, label_width, LINE_HEIGHT}, "Resolution: ")
    state.cursor.x += label_width + PANEL_PADDING

    if GuiToggle({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, &state.settings_screen_state.fullscreen_toggle) {
        state.fullscreen = state.settings_screen_state.fullscreen_toggle.toggle^
        rl.ToggleFullscreen()
    }
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING

    if GuiButton({state.cursor.x, state.cursor.y, input_width, LINE_HEIGHT}, "Save") {
        state.config.ENTITY_FILE_PATH    = fmt.tprint(state.app_dir, state.settings_screen_state.entities_file_input.text, sep="")
        state.config.CUSTOM_ENTITIES_DIR = fmt.tprint(state.app_dir, state.settings_screen_state.entities_dir.text, sep="")
        state.config.CUSTOM_ENTITY_FILE  = fmt.tprint(state.settings_screen_state.custom_entities_input.text, sep="")
        state.config.WEBPAGE_FILE_PATH   = fmt.tprint(state.app_dir, state.settings_screen_state.webpage_file_inpit.text, sep="")
        state.config.COMBAT_FILES_DIR    = fmt.tprint(state.app_dir, state.settings_screen_state.combats_dir_input.text, sep="")
        SAVE_CONFIG(&state.config)
        LOAD_CONFIG(&state.config)

        state.srd_entities    = load_entities_from_file(state.config.ENTITY_FILE_PATH)
        state.custom_entities = load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH)

        new_message := MessageBoxState{}

        init_message_box(&new_message, "Notification!", "Settings saved!")
        add_message(&state.settings_screen_state.message_queue, new_message)
    }
    state.cursor.y += LINE_HEIGHT + PANEL_PADDING
}
