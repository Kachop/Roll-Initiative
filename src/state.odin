#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import rl "vendor:raylib"

TitleScreenState :: struct {

}

init_title_screen :: proc(screenState: ^TitleScreenState) {

}

d_init_title_screen :: proc(screenState: ^TitleScreenState) {

}

LoadScreenState :: struct {
  first_load: bool,
  dir_nav_list: [dynamic]cstring,
  current_dir_index: u32,
  current_dir: cstring,
  files_list: [dynamic]cstring,
  dirs_list: [dynamic]cstring,
  selected_file: cstring,
  panel: PanelState,
}

init_load_screen :: proc(screenState: ^LoadScreenState) {
  screenState.first_load = true
  screenState.dir_nav_list = [dynamic]cstring{}
  screenState.current_dir = cstr(os.get_current_directory(context.temp_allocator))
  screenState.files_list = [dynamic]cstring{}
  screenState.dirs_list = [dynamic]cstring{}
  screenState.selected_file = nil
  InitPanelState(&screenState.panel)
  
  get_current_dir_files(screenState)
  append(&screenState.dir_nav_list, cstr(state.app_dir))
}

d_init_load_screen :: proc(screenState: ^LoadScreenState) {
  delete(screenState.dir_nav_list)
  delete(screenState.files_list)
  delete(screenState.dirs_list)
}

SetupScreenState :: struct {
  first_load: bool,
  entities_filtered: #soa[dynamic]Entity,
  entities_selected: [dynamic]Entity,
  selected_entity: ^Entity,
  selected_entity_index: int,
  filter_tab: TabControlState,
  panelLeft: PanelState,
  panelMid: PanelState,
  panelRight: PanelState,
  filename_input: TextInputState,
  initiative_input: TextInputState,
  stats_lines_needed: f32,

}

init_setup_screen :: proc(screenState: ^SetupScreenState) {
  screenState.first_load = true
  screenState.entities_filtered = state.srd_entities
  screenState.entities_selected = [dynamic]Entity{}
  screenState.selected_entity = nil
  screenState.selected_entity_index = 0
  options := [dynamic]cstring{"Monsters", "Characters"}
  InitTabControlState(&screenState.filter_tab, options[:])
  InitPanelState(&screenState.panelLeft)
  InitPanelState(&screenState.panelMid)
  InitPanelState(&screenState.panelRight)
  InitTextInputState(&screenState.filename_input)
  InitTextInputState(&screenState.initiative_input)
  screenState.stats_lines_needed = 0
}

d_init_setup_screen :: proc(screenState: ^SetupScreenState) {

}

CombatScreenState :: struct {
  first_load: bool,
  entities: [dynamic]Entity,
  current_entity_index: i32,
  current_entity: ^Entity,
  current_round: i32,
  turn_timer: time.Stopwatch,
  combat_timer: time.Stopwatch,
  panelLeft: PanelState,
  panelMid: PanelState,
  scroll_lock_mid: bool,
  from_dropdown: DropdownState,
  to_dropdown: DropdownSelectState,
  dmg_type_selected: DamageType,
  dmg_type_dropdown: DropdownState,
  dmg_input: TextInputState,
  heal_input: TextInputState,
  condition_dropdown: DropdownSelectState,
  temp_HP_input: TextInputState,
  panelRight: PanelState,
  json_data: string,
  stats_lines_needed: f32,
}

init_combat_screen :: proc(screenState: ^CombatScreenState) {
  screenState.first_load = true
  screenState.entities = [dynamic]Entity{}
  screenState.current_entity_index = 0
  screenState.current_entity = nil
  screenState.current_round = 1
  screenState.turn_timer = time.Stopwatch{}
  screenState.combat_timer = time.Stopwatch{}
  InitPanelState(&screenState.panelLeft)
  InitPanelState(&screenState.panelMid)
  dmg_type_options := [dynamic]cstring{"Slashing", "Piercing", "Bludgeoning", "Non-magical", "Poison", "Acid", "Fire", "Cold", "Radiant", "Necrotic", "Lightning", "Thunder", "Force", "Psychic"}
  InitDropdownState(&screenState.dmg_type_dropdown, "Type:", dmg_type_options[:])
  InitTextInputState(&screenState.dmg_input)
  InitTextInputState(&screenState.heal_input)

  conditions := [dynamic]cstring{"Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", "Stunned", "Unconsious", "Exhaustion"}
  InitDropdownSelectState(&screenState.condition_dropdown, "Condition:", conditions[:])
  InitTextInputState(&screenState.temp_HP_input)

  InitPanelState(&screenState.panelRight)
  screenState.json_data = "{}"
  screenState.stats_lines_needed = 0
}

d_init_combat_screen :: proc(screenState: ^CombatScreenState) {
  delete(screenState.entities)
}

SettingsScreenState :: struct {
  first_load: bool,
  entities_dir: TextInputState,
  entities_file_input: TextInputState,
  custom_entities_input: TextInputState,
  webpage_file_inpit: TextInputState,
  combats_dir_input: TextInputState,
}

init_settings_screen :: proc(screenState: ^SettingsScreenState) {
  screenState.first_load = true
  InitTextInputState(&screenState.entities_dir)
  InitTextInputState(&screenState.entities_file_input)
  InitTextInputState(&screenState.custom_entities_input)
  InitTextInputState(&screenState.webpage_file_inpit)
  InitTextInputState(&screenState.combats_dir_input)
}

d_init_settings_screen :: proc(screenState: ^SettingsScreenState) {

}

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
  combined_image: rl.Texture,
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
  DMG_vulnerable_input: DropdownSelectState,
  DMG_resist_input: DropdownSelectState,
  DMG_immune_input: DropdownSelectState,
  languages_input: TextInputState,
}

init_entity_screen :: proc(screenState: ^EntityScreenState) {
  InitPanelState(&screenState.panelLeft)
  InitPanelState(&screenState.panelMid)
  InitPanelState(&screenState.panelRight)
  
  temp_path_list := [dynamic]string{}
  dir_handle, ok := os.open(fmt.tprint(state.config.CUSTOM_ENTITY_PATH, "images", sep=FILE_SEPERATOR))
  file_infos, err := os.read_dir(dir_handle, 0)

  reload_icons(screenState)
  reload_borders(screenState)
  screenState.combined_image, _ = get_entity_icon_data(cstr(screenState.img_file_paths[screenState.current_icon_index]), cstr(screenState.border_file_paths[screenState.current_border_index]))

  type_options := [dynamic]cstring{"player", "NPC", "monster"}
  screenState.first_load = true
  InitTextInputState(&screenState.name_input)
  InitTextInputState(&screenState.race_input)
  InitTextInputState(&screenState.size_input)
  InitDropdownState(&screenState.type_dropdown, "", type_options[:])
  InitTextInputState(&screenState.AC_input)
  InitTextInputState(&screenState.HP_input)
  InitTextInputState(&screenState.HP_max_input)
  InitTextInputState(&screenState.temp_HP_input)
  InitTextInputState(&screenState.speed_input)
  InitTextInputState(&screenState.STR_input)
  InitTextInputState(&screenState.DEX_input)
  InitTextInputState(&screenState.CON_input)
  InitTextInputState(&screenState.INT_input)
  InitTextInputState(&screenState.WIS_input)
  InitTextInputState(&screenState.CHA_input)
  InitTextInputState(&screenState.STR_save_input)
  InitTextInputState(&screenState.DEX_save_input)
  InitTextInputState(&screenState.CON_save_input)
  InitTextInputState(&screenState.INT_save_input)
  InitTextInputState(&screenState.WIS_save_input)
  InitTextInputState(&screenState.CHA_save_input)
  dmg_type_options := [dynamic]cstring{"Slashing", "Piercing", "Bludgeoning", "Non-magical", "Poison", "Acid", "Fire", "Cold", "Radiant", "Necrotic", "Lightning", "Thunder", "Force", "Psychic"}
  InitDropdownSelectState(&screenState.DMG_vulnerable_input, "Type:", dmg_type_options[:])
  InitDropdownSelectState(&screenState.DMG_resist_input, "Type:", dmg_type_options[:])
  InitDropdownSelectState(&screenState.DMG_immune_input, "Type:", dmg_type_options[:])
  InitTextInputState(&screenState.languages_input)
}

d_init_entity_screen :: proc(screenState: ^EntityScreenState) {

}

WindowState :: union {
  TitleScreenState,
  LoadScreenState,
  SetupScreenState,
  CombatScreenState,
  SettingsScreenState,
  EntityScreenState,
}

State :: struct {
  window_width, window_height: f32,
  
  title_screen_state: TitleScreenState,
  load_screen_state: LoadScreenState,
  setup_screen_state: SetupScreenState,
  combat_screen_state: CombatScreenState,
  settings_screen_state: SettingsScreenState,
  entity_screen_state: EntityScreenState,
  current_screen_state: WindowState,
  screen_state_queue: [dynamic]WindowState,

  srd_entities: #soa[dynamic]Entity,
  custom_entities: #soa[dynamic]Entity,
  gui_properties: GuiProperties,
  hover_consumed: bool,
  config: Config,
  app_dir: string,
}

init_state :: proc(state: ^State) {
  state.window_width = cast(f32)rl.GetRenderWidth()
  state.window_height = cast(f32)rl.GetRenderHeight()
  state.app_dir = os.get_current_directory()
  LOAD_CONFIG(&state.config)
  state.srd_entities = load_entities_from_file(state.config.ENTITY_FILE_PATH)
  state.custom_entities = load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH)
  state.gui_properties = getDefaultProperties()
  init_title_screen(&state.title_screen_state)
  init_load_screen(&state.load_screen_state)
  init_setup_screen(&state.setup_screen_state)
  init_combat_screen(&state.combat_screen_state)
  init_settings_screen(&state.settings_screen_state)
  init_entity_screen(&state.entity_screen_state)
  state.current_screen_state = state.title_screen_state

}

d_init_state :: proc(state: ^State) {
  d_init_title_screen(&state.title_screen_state)
  d_init_load_screen(&state.load_screen_state)
  d_init_setup_screen(&state.setup_screen_state)
  d_init_combat_screen(&state.combat_screen_state)
  d_init_settings_screen(&state.settings_screen_state)
  d_init_entity_screen(&state.entity_screen_state)
  state.current_screen_state = nil

  delete_soa(state.srd_entities)
  delete_soa(state.custom_entities)

  unload_config(&state.config)
}
