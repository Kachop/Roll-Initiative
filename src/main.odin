#+feature dynamic-literals

package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "core:thread"
import "core:os/os2"
import "core:net"

/*
Features TODO:
- Logging of combat go by go, with dmg, healing etc.
- Some sort of built-in media controls and playlist builder / spotify API control.
- Random CR combat maker.
- Random enemy generator.
- Web animations.
*/

cstr :: fmt.ctprint

when ODIN_OS == .Windows {
  FILE_SEPERATOR :: "\\"
  BROWSER_COMMAND :: "start"
} else when ODIN_OS == .Linux {
  FILE_SEPERATOR :: "/"
  BROWSER_COMMAND :: "xdg-open" 
}

app_title :: "/Roll Initiative"
app_dir := fmt.tprint(#directory, "../", sep="")
current_dir :: #directory[:len(#directory)-1]

CONFIG: Config

View :: enum {
  TITLE_SCREEN,
  LOAD_SCREEN,
  SETUP_SCREEN,
  COMBAT_SCREEN,
  SETTINGS_SCREEN,
  ENTITY_SCREEN,
}

State :: struct {
  window_width, window_height: f32,
  views_list: [dynamic]View,
  current_view_index: u32,
  srd_entities: #soa[dynamic]Entity,
  custom_entities: #soa[dynamic]Entity,
  gui_properties: GuiProperties,
  hover_consumed: bool,
}

InitState :: proc(state: ^State) {
  state.window_width = cast(f32)rl.GetRenderWidth()
  state.window_height = cast(f32)rl.GetRenderHeight()
  state.views_list = [dynamic]View{.TITLE_SCREEN}
  state.current_view_index = 0
  state.srd_entities = load_entities_from_file(CONFIG.ENTITY_FILE_PATH)
  state.custom_entities = load_entities_from_file(CONFIG.CUSTOM_ENTITY_FILE_PATH)
  state.gui_properties = getDefaultProperties()
}

state: State
server_thread: ^thread.Thread

@(init)
init :: proc() {
  fmt.println(#directory)
  //Initialisation steps
  rl.InitWindow(1080, 720, "Roll Initiative")
  rl.SetTargetFPS(60)
  rl.SetExitKey(.Q)
  icon_img := rl.LoadImage("icon.png")
  rl.SetWindowIcon(icon_img)
  //rl.SetWindowState({.WINDOW_RESIZABLE})
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 60)
  
  ip_string: string
  when ODIN_OS == .Windows {
    continue
  } else when ODIN_OS == .Linux {
    ip_string, _ = get_ip_linux()
  }
  LOAD_CONFIG(&CONFIG)

  InitState(&state)

  server_thread = thread.create_and_start(run_combat_server)
  
  web_addr := fmt.tprintf("http://%v:%v", ip_string, CONFIG.PORT)
  p, err := os2.process_start({
      command = {BROWSER_COMMAND, web_addr},
    })

  _, err = os2.process_wait(p)

  fmt.println(net.enumerate_interfaces())
}

main :: proc() {
  defer rl.CloseWindow()
 
  fileDialogState: GuiFileDialogState
  setupState: SetupState
  combatState: CombatState
  settingsState: SettingsState
  entityScreenState: EntityScreenState

  InitFileDialog(&fileDialogState)
  InitSetupState(&setupState)
  InitCombatState(&combatState)
  InitSettingsState(&settingsState)
  InitEntityScreenState(&entityScreenState)

  for (!rl.WindowShouldClose()) {
    //Do non-drawing stuff
    state.window_width = cast(f32)rl.GetRenderWidth()
    state.window_height = cast(f32)rl.GetRenderHeight()

    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 60)
    //Draw
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(CONFIG.BACKGROUND_COLOUR)

    switch state.views_list[state.current_view_index] {
    case .TITLE_SCREEN:
      drawTitleScreen()
    case .LOAD_SCREEN:
      drawLoadScreen(&fileDialogState, &setupState)
    case .SETUP_SCREEN:
      GuiDrawSetupScreen(&setupState, &combatState)
    case .COMBAT_SCREEN:
      GuiDrawCombatScreen(&combatState)
    case .SETTINGS_SCREEN:
      GuiDrawSettingsScreen(&settingsState)
    case .ENTITY_SCREEN:
      GuiDrawEntityScreen(&entityScreenState)
    }
  }
  
  for texture in entityScreenState.icons {
    rl.UnloadTexture(texture)
  }

  delete_soa(state.srd_entities)
  delete_soa(state.custom_entities)

  thread.terminate(server_thread, 0)
  thread.destroy(server_thread)
}

drawTitleScreen :: proc() {
  using state.gui_properties
  
  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  TITLE_BUTTON_WIDTH = state.window_width / 2

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_GEAR_BIG, ""))) {
    inject_at(&state.views_list, state.current_view_index+1, View.SETTINGS_SCREEN)
    state.current_view_index += 1
    return
  }

  title_width := getTextWidth("Roll Initiative", TEXT_SIZE_TITLE)
  title_x : f32 = (state.window_width / 2) - cast(f32)(title_width / 2)
  rl.GuiLabel({title_x, cursor_y, state.window_width / 2, TITLE_BUTTON_HEIGHT}, app_title)
  cursor_x = state.window_width / 4
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "New Combat")) {
    inject_at(&state.views_list, state.current_view_index+1, View.SETUP_SCREEN)
    state.current_view_index += 1
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Load Combat")) {
    inject_at(&state.views_list, state.current_view_index+1, View.LOAD_SCREEN)
    state.current_view_index += 1
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_PADDING

  if rl.GuiButton({cursor_x, cursor_y, TITLE_BUTTON_WIDTH, TITLE_BUTTON_HEIGHT}, "Add Entity") {
    inject_at(&state.views_list, state.current_view_index+1, View.ENTITY_SCREEN)
    state.current_view_index += 1
    return
  }
  cursor_y += TITLE_BUTTON_HEIGHT + TITLE_BUTTON_WIDTH
}

drawLoadScreen :: proc(fileDialogState: ^GuiFileDialogState, setupState: ^SetupState) {
  using state.gui_properties

  cursor_x : f32 = PADDING_LEFT
  cursor_y : f32 = PADDING_TOP

  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)

  if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
    fileDialogState.first_load = true
    state.current_view_index -= 1
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

  if (GuiFileDialog({cursor_x, cursor_y, state.window_width - PADDING_LEFT - PADDING_RIGHT, state.window_height - cursor_y - PADDING_BOTTOM}, fileDialogState)) {
    //Go to the setup screen and load all the information from the selected file.
    //load_combat(fileDialogState.selected_file)
    combat := read_combat_file(string(fileDialogState.selected_file), setupState)
    setupState.entities_selected = combat.entities
    //setupState.initiatives = combat.initiatives
    inject_at(&state.views_list, state.current_view_index+1, View.SETUP_SCREEN)
    state.current_view_index += 1
  }
}

reload_entities :: proc() {
  state.custom_entities = load_entities_from_file(CONFIG.CUSTOM_ENTITY_FILE_PATH)
}
