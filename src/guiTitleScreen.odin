package main

import "core:fmt"
import rl "vendor:raylib"

draw_title_screen :: proc() {
    using state.gui_properties

    state.cursor.x = PADDING_LEFT
    state.cursor.y = PADDING_TOP

    TITLE_BUTTON_HEIGHT = state.window_height / 7
    TITLE_BUTTON_WIDTH  = state.window_width / 2
  
    if (GuiButton({state.cursor.x, state.cursor.y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_GEAR_BIG, ""))) {
        state.current_screen_state = state.settings_screen_state
        return
    }
    state.cursor.x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
   
    TEXT_SIZE = TEXT_SIZE_TITLE
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
    GuiLabel({state.cursor.x, state.cursor.y, state.window_width - (state.cursor.x * 2), MENU_BUTTON_HEIGHT}, app_title)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

    state.cursor.x = state.window_width / 4
    state.cursor.y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING
  
    if (GuiButton({state.cursor.x, state.cursor.y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "New Combat")) {
        state.current_screen_state = state.setup_screen_state
        return
    }
    state.cursor.y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING
  
    if (GuiButton({state.cursor.x, state.cursor.y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Load Combat")) {
        state.current_screen_state = state.load_screen_state
        return
    }
    state.cursor.y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING
  
    if GuiButton({state.cursor.x, state.cursor.y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Add Entity") {
        state.current_screen_state = state.entity_screen_state
        return
    }
    state.cursor.y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING
    if GuiButton({state.cursor.x, state.cursor.y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Generate Combat") {
        return
    }
  
    state.cursor.x = PADDING_LEFT
    state.cursor.y = state.window_height * 0.93
    TEXT_SIZE = 20
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    rl.GuiLabel({state.cursor.x, state.cursor.y, 100, 50}, fmt.ctprintf("v%v.%v", VERSION_MAJOR, VERSION_MINOR))
}
