#+feature dynamic-literals

package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import rl "vendor:raylib"

GUI_ID: i32 = 0

TitleScreenState :: struct {
}

LoadScreenState :: struct {
	first_load:        bool,
	message_queue:     MessageBoxQueueState,
	dir_nav_list:      [dynamic]cstring,
	current_dir_index: u32,
	current_dir:       cstring,
	files_list:        [dynamic]cstring,
	dirs_list:         [dynamic]cstring,
	selected_file:     cstring,
	panel:             PanelState,
}

init_load_screen :: proc() {
	state.load_screen_state.first_load = true
	state.load_screen_state.dir_nav_list = [dynamic]cstring{}
	state.load_screen_state.current_dir = fmt.caprint(
		os.get_current_directory(context.temp_allocator),
	)
	state.load_screen_state.files_list = [dynamic]cstring{}
	state.load_screen_state.dirs_list = [dynamic]cstring{}
	state.load_screen_state.selected_file = nil
	init_panel_state(&state.load_screen_state.panel)

	get_current_dir_files()
	append(&state.load_screen_state.dir_nav_list, fmt.caprint(state.app_dir))
}

d_init_load_screen :: proc() {
}

SetupScreenState :: struct {
	first_load:            bool,
	message_queue:         MessageBoxQueueState,
	entities_filtered:     []Entity,
	entities_searched:     []Entity,
	num_entities_filtered: int,
	num_entities_searched: int,
	party_button_states:   [dynamic]EntityButtonState,
	enemy_button_states:   [dynamic]EntityButtonState,
	party_selected:        []Entity,
	enemies_selected:      []Entity,
	num_party:             int,
	num_enemies:           int,
	selected_entity:       ^Entity,
	selected_entity_idx:   int,
	panel_left:            PanelState,
	search_tab:            TabControlState,
	entity_search_state:   TextInputState,
	panel_mid:             PanelState,
	view_tab:              TabControlState,
	panel_right:           PanelState,
	filename_input:        TextInputState,
	initiative_input:      TextInputState,
	long_rest_popup:       PopupState,
	popup_toggled:         bool,
}

init_setup_screen :: proc() {
	state.setup_screen_state.first_load = true
	state.setup_screen_state.entities_filtered = make([]Entity, 1024)
	state.setup_screen_state.entities_searched = make([]Entity, 1024)
	state.setup_screen_state.party_selected = make([]Entity, 256, allocator = entities_alloc)
	state.setup_screen_state.enemies_selected = make([]Entity, 256, allocator = entities_alloc)

	state.setup_screen_state.selected_entity = nil
	state.setup_screen_state.selected_entity_idx = -1

	init_panel_state(&state.setup_screen_state.panel_left)
	search_options := make([]cstring, 2)
	search_options[0] = fmt.caprint("Characters")
	search_options[1] = fmt.caprint("Monsters")
	init_tab_control_state(&state.setup_screen_state.search_tab, search_options)
	init_text_input_state(&state.setup_screen_state.entity_search_state)
	init_panel_state(&state.setup_screen_state.panel_mid)
	view_options := make([]cstring, 2)
	view_options[0] = fmt.caprint("Party")
	view_options[1] = fmt.caprint("Enemies")
	init_tab_control_state(&state.setup_screen_state.view_tab, view_options)
	init_panel_state(&state.setup_screen_state.panel_right)
	init_text_input_state(&state.setup_screen_state.filename_input)
	init_text_input_state(&state.setup_screen_state.initiative_input)
}

d_init_setup_screen :: proc() {

}

CombatScreenState :: struct {
	first_load:                    bool,
	message_queue:                 MessageBoxQueueState,
	back_button:                   ButtonState,
	decrement_button:              ButtonState,
	increment_button:              ButtonState,
	start_button:                  ButtonState,
	stop_button:                   ButtonState,
	entities:                      []Entity,
	num_entities:                  int,
	entity_names:                  [dynamic]cstring,
	current_entity_idx:            i32,
	current_entity:                ^Entity,
	view_entity_idx:               i32,
	view_entity:                   ^Entity,
	current_round:                 i32,
	turn_timer:                    time.Stopwatch,
	combat_timer:                  time.Stopwatch,
	combat_logger:                 Logger,
	add_entity_mode:               bool,
	remove_entity_mode:            bool,
	add_entity_button:             ButtonState,
	remove_entity_button:          ButtonState,
	btn_list:                      map[i32]^bool,
	panel_left_top:                PanelState,
	panel_left_bottom:             PanelState,
	panel_left_bottom_text:        cstring,
	entity_button_states:          [dynamic]EntityButtonState,
	panel_mid:                     PanelState,
	main_tab_state:                TabControlState,
	scroll_lock_mid:               bool,
	from_dropdown:                 DropdownState,
	to_dropdown:                   DropdownSelectState,
	dmg_type_selected:             DamageType,
	dmg_type_dropdown:             DropdownState,
	dmg_input:                     TextInputState,
	heal_input:                    TextInputState,
	temp_HP_input:                 TextInputState,
	condition_dropdown:            DropdownSelectState,
	custom_condition_input:        TextInputState,
	toggle_active:                 i32,
	temp_resist_immunity_toggle:   ToggleSliderState,
	temp_resist_immunity_dropdown: DropdownSelectState,
	blinded_toggle_state:          ToggleState,
	blinded_toggle:                bool,
	charmed_toggle_state:          ToggleState,
	charmed_toggle:                bool,
	deafened_toggle_state:         ToggleState,
	deafened_toggle:               bool,
	frightened_toggle_state:       ToggleState,
	frightened_toggle:             bool,
	grappled_toggle_state:         ToggleState,
	grappled_toggle:               bool,
	incapacitated_toggle_state:    ToggleState,
	incapacitated_toggle:          bool,
	invisible_toggle_state:        ToggleState,
	invisible_toggle:              bool,
	paralyzed_toggle_state:        ToggleState,
	paralyzed_toggle:              bool,
	petrified_toggle_state:        ToggleState,
	petrified_toggle:              bool,
	poisoned_toggle_state:         ToggleState,
	poisoned_toggle:               bool,
	prone_toggle_state:            ToggleState,
	prone_toggle:                  bool,
	restrained_toggle_state:       ToggleState,
	restrained_toggle:             bool,
	stunned_toggle_state:          ToggleState,
	stunned_toggle:                bool,
	unconscious_toggle_state:      ToggleState,
	unconscious_toggle:            bool,
	exhaustion_toggle_state:       ToggleState,
	exhaustion_toggle:             bool,
	panel_right_top:               PanelState,
	panel_right_bottom:            PanelState,
	panel_right_bottom_text:       cstring,
	view_entity_tab_state:         TabControlState,
	current_entity_tab_state:      TabControlState,
	json_data:                     string,
}

init_combat_screen :: proc() {
	state.combat_screen_state.first_load = true

	init_button_state(&state.combat_screen_state.back_button)
	init_button_state(&state.combat_screen_state.decrement_button)
	init_button_state(&state.combat_screen_state.increment_button)
	init_button_state(&state.combat_screen_state.start_button)
	init_button_state(&state.combat_screen_state.stop_button)

	state.combat_screen_state.entities = make_slice([]Entity, 256, allocator = entities_alloc)
	state.combat_screen_state.current_entity_idx = 0
	state.combat_screen_state.current_entity = nil
	state.combat_screen_state.view_entity_idx = 0
	state.combat_screen_state.view_entity = nil
	state.combat_screen_state.current_round = 1
	state.combat_screen_state.turn_timer = time.Stopwatch{}
	state.combat_screen_state.combat_timer = time.Stopwatch{}
	state.combat_screen_state.add_entity_mode = false
	state.combat_screen_state.remove_entity_mode = false
	init_button_state(&state.combat_screen_state.add_entity_button)
	init_button_state(&state.combat_screen_state.remove_entity_button)
	init_panel_state(&state.combat_screen_state.panel_left_top)
	init_panel_state(&state.combat_screen_state.panel_left_bottom)
	init_panel_state(&state.combat_screen_state.panel_mid)

	main_tab_options := [dynamic]cstring{"Damage", "Conditions"}
	init_tab_control_state(&state.combat_screen_state.main_tab_state, main_tab_options[:])

	init_dropdown_state(
		&state.combat_screen_state.dmg_type_dropdown,
		"",
		state.dmg_type_options[:],
		&state.combat_screen_state.btn_list,
	)
	init_text_input_state(&state.combat_screen_state.dmg_input)
	init_text_input_state(&state.combat_screen_state.heal_input)
	init_text_input_state(&state.combat_screen_state.temp_HP_input)

	init_dropdown_select_state(
		&state.combat_screen_state.condition_dropdown,
		"Condition:",
		state.condition_options,
		&state.combat_screen_state.btn_list,
	)
	init_text_input_state(&state.combat_screen_state.custom_condition_input)

	temp_options := [dynamic]cstring{"Resistance", "Immunity", "Vulnerability"}
	init_toggle_slider_state(
		&state.combat_screen_state.temp_resist_immunity_toggle,
		temp_options[:],
	)

	init_dropdown_select_state(
		&state.combat_screen_state.temp_resist_immunity_dropdown,
		"Type:",
		state.dmg_type_options[:],
		&state.combat_screen_state.btn_list,
	)

	init_toggle_state(
		&state.combat_screen_state.blinded_toggle_state,
		"Blinded",
		&state.combat_screen_state.blinded_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.charmed_toggle_state,
		"Charmed",
		&state.combat_screen_state.charmed_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.deafened_toggle_state,
		"Deafened",
		&state.combat_screen_state.deafened_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.frightened_toggle_state,
		"Frightened",
		&state.combat_screen_state.frightened_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.grappled_toggle_state,
		"Grappled",
		&state.combat_screen_state.grappled_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.incapacitated_toggle_state,
		"Incapacitated",
		&state.combat_screen_state.incapacitated_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.invisible_toggle_state,
		"Invisible",
		&state.combat_screen_state.invisible_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.paralyzed_toggle_state,
		"Paralyzed",
		&state.combat_screen_state.paralyzed_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.petrified_toggle_state,
		"Petrified",
		&state.combat_screen_state.petrified_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.poisoned_toggle_state,
		"Poisoned",
		&state.combat_screen_state.poisoned_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.prone_toggle_state,
		"Prone",
		&state.combat_screen_state.prone_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.restrained_toggle_state,
		"Restrained",
		&state.combat_screen_state.restrained_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.stunned_toggle_state,
		"Stunned",
		&state.combat_screen_state.stunned_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.unconscious_toggle_state,
		"Unconscious",
		&state.combat_screen_state.unconscious_toggle,
	)

	init_toggle_state(
		&state.combat_screen_state.exhaustion_toggle_state,
		"Exhausted",
		&state.combat_screen_state.exhaustion_toggle,
	)

	init_panel_state(&state.combat_screen_state.panel_right_top)
	init_panel_state(&state.combat_screen_state.panel_right_bottom)
	state.combat_screen_state.json_data = "{}"

	stats_tab_options := [dynamic]cstring{"Stats", "Traits", "Actions", "LA"}
	init_tab_control_state(&state.combat_screen_state.view_entity_tab_state, stats_tab_options[:])
	stats_tab_options = [dynamic]cstring{"Traits", "Actions", "LA"}
	init_tab_control_state(
		&state.combat_screen_state.current_entity_tab_state,
		stats_tab_options[:],
	)
}

d_init_combat_screen :: proc() {
}

SettingsScreenState :: struct {
	first_load:            bool,
	message_queue:         MessageBoxQueueState,
	entities_dir:          TextInputState,
	entities_file_input:   TextInputState,
	custom_entities_input: TextInputState,
	webpage_file_inpit:    TextInputState,
	combats_dir_input:     TextInputState,
	btn_list:              map[i32]^bool,
	fullscreen_toggle:     ToggleState,
	fullscreen:            bool,
}

init_settings_screen :: proc() {
	state.settings_screen_state.first_load = true
	init_text_input_state(&state.settings_screen_state.entities_dir)
	init_text_input_state(&state.settings_screen_state.entities_file_input)
	init_text_input_state(&state.settings_screen_state.custom_entities_input)
	init_text_input_state(&state.settings_screen_state.webpage_file_inpit)
	init_text_input_state(&state.settings_screen_state.combats_dir_input)
	init_toggle_state(
		&state.settings_screen_state.fullscreen_toggle,
		"Fullscreen",
		&state.settings_screen_state.fullscreen,
	)
}

d_init_settings_screen :: proc() {}

EntityScreenState :: struct {
	first_load:           bool,
	entity_edit_mode:     bool,
	entity_to_edit:       i32,
	btn_list:             map[i32]^bool,
	panel_left:           PanelState,
	reset_button_left:    ButtonState,
	panel_mid:            PanelState,
	reset_button_mid:     ButtonState,
	panel_right:          PanelState,
	reset_button_right:   ButtonState,
	img_file_paths:       []string,
	border_file_paths:    []string,
	icons:                []rl.Texture,
	borders:              []rl.Texture,
	current_icon_index:   i32,
	current_border_index: i32,
	combined_image:       rl.Texture,
	name_input:           TextInputState,
	race_input:           TextInputState,
	size_input:           TextInputState,
	type_dropdown:        DropdownState,
	AC_input:             TextInputState,
	HP_input:             TextInputState,
	HP_max_input:         TextInputState,
	temp_HP_input:        TextInputState,
	speed_input:          TextInputState,
	STR_input:            TextInputState,
	DEX_input:            TextInputState,
	CON_input:            TextInputState,
	INT_input:            TextInputState,
	WIS_input:            TextInputState,
	CHA_input:            TextInputState,
	STR_save_input:       TextInputState,
	DEX_save_input:       TextInputState,
	CON_save_input:       TextInputState,
	INT_save_input:       TextInputState,
	WIS_save_input:       TextInputState,
	CHA_save_input:       TextInputState,
	DMG_vulnerable_input: DropdownSelectState,
	DMG_resist_input:     DropdownSelectState,
	DMG_immune_input:     DropdownSelectState,
	languages_input:      TextInputState,
}

init_entity_screen :: proc() {
	init_panel_state(&state.entity_screen_state.panel_left)
	init_panel_state(&state.entity_screen_state.panel_mid)
	init_panel_state(&state.entity_screen_state.panel_right)

	init_button_state(&state.entity_screen_state.reset_button_left)
	init_button_state(&state.entity_screen_state.reset_button_mid)
	init_button_state(&state.entity_screen_state.reset_button_right)

	reload_icons_and_borders()
	state.entity_screen_state.combined_image, _ = get_entity_icon_data(
		cstr(
			state.entity_screen_state.img_file_paths[state.entity_screen_state.current_icon_index],
		),
		cstr(
			state.entity_screen_state.border_file_paths[state.entity_screen_state.current_border_index],
		),
		allocator = frame_alloc,
	)

	type_options := [dynamic]cstring{"Player", "NPC", "Monster"}
	state.entity_screen_state.first_load = true
	init_text_input_state(&state.entity_screen_state.name_input)
	init_text_input_state(&state.entity_screen_state.race_input)
	init_text_input_state(&state.entity_screen_state.size_input)
	init_dropdown_state(
		&state.entity_screen_state.type_dropdown,
		"",
		type_options[:],
		&state.entity_screen_state.btn_list,
	)
	init_text_input_state(&state.entity_screen_state.AC_input)
	init_text_input_state(&state.entity_screen_state.HP_input)
	init_text_input_state(&state.entity_screen_state.HP_max_input)
	init_text_input_state(&state.entity_screen_state.temp_HP_input)
	init_text_input_state(&state.entity_screen_state.speed_input)
	init_text_input_state(&state.entity_screen_state.STR_input)
	init_text_input_state(&state.entity_screen_state.DEX_input)
	init_text_input_state(&state.entity_screen_state.CON_input)
	init_text_input_state(&state.entity_screen_state.INT_input)
	init_text_input_state(&state.entity_screen_state.WIS_input)
	init_text_input_state(&state.entity_screen_state.CHA_input)
	init_text_input_state(&state.entity_screen_state.STR_save_input)
	init_text_input_state(&state.entity_screen_state.DEX_save_input)
	init_text_input_state(&state.entity_screen_state.CON_save_input)
	init_text_input_state(&state.entity_screen_state.INT_save_input)
	init_text_input_state(&state.entity_screen_state.WIS_save_input)
	init_text_input_state(&state.entity_screen_state.CHA_save_input)
	dmg_type_options := [dynamic]cstring {
		"Slashing",
		"Piercing",
		"Bludgeoning",
		"Non-magical",
		"Poison",
		"Acid",
		"Fire",
		"Cold",
		"Radiant",
		"Necrotic",
		"Lightning",
		"Thunder",
		"Force",
		"Psychic",
	}
	init_dropdown_select_state(
		&state.entity_screen_state.DMG_vulnerable_input,
		"Type:",
		dmg_type_options[:],
		&state.entity_screen_state.btn_list,
	)
	init_dropdown_select_state(
		&state.entity_screen_state.DMG_resist_input,
		"Type:",
		dmg_type_options[:],
		&state.entity_screen_state.btn_list,
	)
	init_dropdown_select_state(
		&state.entity_screen_state.DMG_immune_input,
		"Type:",
		dmg_type_options[:],
		&state.entity_screen_state.btn_list,
	)
	init_text_input_state(&state.entity_screen_state.languages_input)
}

d_init_entity_screen :: proc() {
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
	fullscreen:                  bool,
	gui_enabled:                 bool,
	hover_stack:                 HoverStack,
	cursor:                      [2]f32,
	mouse_pos:                   [2]f32,
	title_screen_state:          TitleScreenState,
	load_screen_state:           LoadScreenState,
	setup_screen_state:          SetupScreenState,
	combat_screen_state:         CombatScreenState,
	settings_screen_state:       SettingsScreenState,
	entity_screen_state:         EntityScreenState,
	current_screen_state:        WindowState,
	screen_state_queue:          [dynamic]WindowState,
	srd_entities:                []Entity,
	custom_entities:             []Entity,
	num_srd_entities:            int,
	num_custom_entities:         int,
	dmg_type_options:            [dynamic]cstring,
	condition_options:           []cstring,
	gui_properties:              GuiProperties,
	hover_consumed:              bool,
	config:                      Config,
	app_dir:                     string,
	ip_str:                      string,
	server_state:                ServerState,
}

init_state :: proc(state: ^State) {
	state.app_dir = double_escape_backslashes(os.get_current_directory())
	state.app_dir = os.get_current_directory()
	LOAD_CONFIG(&state.config)

	state.gui_enabled = true
	state.hover_stack.enabled = true

	state.cursor = {0, 0}
	state.mouse_pos = rl.GetMousePosition()

	state.srd_entities = make([]Entity, 1024, allocator = entities_alloc)
	state.custom_entities = make([]Entity, 256, allocator = entities_alloc)

	state.num_srd_entities = load_entities_from_file(
		state.config.ENTITY_FILE_PATH,
		&state.srd_entities,
	)
	state.num_custom_entities = load_entities_from_file(
		state.config.CUSTOM_ENTITY_FILE_PATH,
		&state.custom_entities,
	)

	//reload_entities()

	state.dmg_type_options = make([dynamic]cstring)
	state.dmg_type_options = {
		"Any",
		"Slashing",
		"Piercing",
		"Bludgeoning",
		"Non-magical",
		"Poison",
		"Acid",
		"Fire",
		"Cold",
		"Radiant",
		"Necrotic",
		"Lightning",
		"Thunder",
		"Force",
		"Psychic",
	}

	state.condition_options = make([]cstring, 15)
	state.condition_options = {
		"Blinded",
		"Charmed",
		"Deafened",
		"Frightened",
		"Grappled",
		"Incapacitated",
		"Invisible",
		"Paralyzed",
		"Petrified",
		"Poisoned",
		"Prone",
		"Restrained",
		"Stunned",
		"Unconsious",
		"Exhaustion",
	}

	state.gui_properties = getDefaultProperties()
	init_load_screen()
	init_setup_screen()
	init_combat_screen()
	init_settings_screen()
	init_entity_screen()
	state.current_screen_state = state.title_screen_state

	state.server_state = ServerState{}
	state.server_state.json_data = "{}"
}

d_init_state :: proc(state: ^State) {
	d_init_load_screen()
	d_init_setup_screen()
	d_init_combat_screen()
	d_init_settings_screen()
	d_init_entity_screen()
	state.current_screen_state = nil

	delete(state.srd_entities)
	delete(state.custom_entities)

	unload_config(&state.config)
}
