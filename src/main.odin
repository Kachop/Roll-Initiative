#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"
import "core:thread"
import "core:os/os2"
import "core:net"

/*
Features TODO:
- Make some sort of system for viewing stats and abilities outside of current entity turn!!
- Logging of combat go by go, with dmg, healing etc.
- Some sort of built-in media controls and playlist builder / spotify API control.
- Random CR combat maker.
- Random enemy generator.
- Web animations.
*/

cstr :: fmt.ctprint
str :: fmt.tprint

FRAME := 0

when ODIN_OS == .Windows {
  FILE_SEPERATOR :: "\\"
  BROWSER_COMMAND :: "start"
} else when ODIN_OS == .Linux {
  FILE_SEPERATOR :: "/"
  BROWSER_COMMAND :: "xdg-open" 
}

app_title :: "/Roll Initiative"

//CONFIG: Config

View :: enum {
  TITLE_SCREEN,
  LOAD_SCREEN,
  SETUP_SCREEN,
  COMBAT_SCREEN,
  SETTINGS_SCREEN,
  ENTITY_SCREEN,
}

state: State
server_thread: ^thread.Thread

@(init)
init :: proc() {
  rl.SetTraceLogLevel(.NONE)

  rl.GuiSetIconScale(2)

  when ODIN_DEBUG {
    context.logger = log.create_console_logger()
  }
  //Initialisation steps
  rl.InitWindow(1080, 720, "Roll Initiative")
  rl.SetTargetFPS(60)
  rl.SetExitKey(.Q)
  icon_img := rl.LoadImage("icon.png")
  rl.SetWindowIcon(icon_img)
  //rl.SetWindowState({.WINDOW_RESIZABLE})
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 60)
  
  init_state(&state)

  when ODIN_OS == .Windows {
    state.ip_str, _ = get_ip_windows()
  } else when ODIN_OS == .Linux {
    state.ip_str, _ = get_ip_linux()
  }

  server_thread = thread.create_and_start(run_combat_server)
  
  log.infof("Started webserver @: http://%v:%v", state.ip_str, state.config.PORT)
  web_addr := fmt.tprintf("http://%v:%v", state.ip_str, state.config.PORT)
  p, err := os2.process_start({
      command = {BROWSER_COMMAND, web_addr},
    })

  _, err = os2.process_wait(p)
  log.debugf("Error launching browser: %v", err)
}

main :: proc() {
  when ODIN_DEBUG {
    context.logger = log.create_console_logger()
  }
  default_allocator := context.allocator
  tracking_allocator: mem.Tracking_Allocator
  mem.tracking_allocator_init(&tracking_allocator, default_allocator)
  context.allocator = mem.tracking_allocator(&tracking_allocator)

  reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
    err := false

    for _, value in a.allocation_map {
      fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
      err = true
    }

    mem.tracking_allocator_reset(a)
    return err
  }

  log.debugf("Starting main loop.")

  defer rl.CloseWindow()

  for (!rl.WindowShouldClose()) {
    state.window_width = cast(f32)rl.GetRenderWidth()
    state.window_height = cast(f32)rl.GetRenderHeight()

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 60)
    //Draw
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    FRAME += 1
    if (FRAME % 60) == 0 {
      log.debugf("HOVER STACK: %v", state.hover_stack.stack)
    }

    rl.ClearBackground(state.config.BACKGROUND_COLOUR)
    clean_hover_stack()
    switch s in &state.current_screen_state {
    case TitleScreenState: drawTitleScreen()
    case LoadScreenState: drawLoadScreen(&state.load_screen_state)
    case SetupScreenState: GuiDrawSetupScreen(&state.setup_screen_state, &state.combat_screen_state)
    case CombatScreenState: GuiDrawCombatScreen(&state.combat_screen_state)
    case SettingsScreenState: GuiDrawSettingsScreen(&state.settings_screen_state)
    case EntityScreenState: GuiDrawEntityScreen(&state.entity_screen_state)
    }
    free_all(context.temp_allocator)
  }
  
  d_init_state(&state)
  //reset_tracking_allocator(&tracking_allocator)
  thread.terminate(server_thread, 0)
  thread.destroy(server_thread)
}

drawTitleScreen :: proc() {
  using state.gui_properties
  
  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  TITLE_BUTTON_WIDTH = state.window_width / 2

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_GEAR_BIG, ""))) {
    state.current_screen_state = state.settings_screen_state
    return
  }

  title_width := getTextWidth("Roll Initiative", TEXT_SIZE_TITLE)
  title_x : f32 = (state.window_width / 2) - cast(f32)(title_width / 2)
  rl.GuiLabel({title_x, cursor_y, state.window_width / 2, TITLE_BUTTON_HEIGHT}, app_title)
  cursor_x = state.window_width / 4
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "New Combat")) {
    state.current_screen_state = state.setup_screen_state
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Load Combat")) {
    state.current_screen_state = state.load_screen_state
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Add Entity") {
    state.current_screen_state = state.entity_screen_state
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING
}

drawLoadScreen :: proc(fileDialogState: ^LoadScreenState) {
  using state.gui_properties

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    state.current_screen_state = state.title_screen_state
    return
  }
  cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

  TEXT_SIZE = TEXT_SIZE_TITLE
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
  
  available_title_width := state.window_width - cursor_x - PADDING_RIGHT
  fit_text("Load Combat", available_title_width, &TEXT_SIZE)
  rl.GuiLabel({cursor_x, cursor_y, available_title_width, MENU_BUTTON_HEIGHT}, "Load Combat")
  cursor_x = PADDING_LEFT
  cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING

  rl.GuiLine({cursor_x, cursor_y, state.window_width - PADDING_LEFT - PADDING_RIGHT, LINE_WIDTH}, "")
  cursor_y += LINE_WIDTH + MENU_BUTTON_PADDING

  if (GuiFileScreen({cursor_x, cursor_y, state.window_width - PADDING_LEFT - PADDING_RIGHT, state.window_height - cursor_y - PADDING_BOTTOM}, fileDialogState)) {
    //Go to the setup screen and load all the information from the selected file.
    //load_combat(fileDialogState.selected_file)
    //combat := read_combat_file(string(fileDialogState.selected_file), state.setup_screen_state)
    //state.setup_screen_state.entities_selected = combat.entities
    //setupState.initiatives = combat.initiatives
    state.current_screen_state = state.setup_screen_state
  }
}

reload_entities :: proc() {
  state.custom_entities = load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH)
}
