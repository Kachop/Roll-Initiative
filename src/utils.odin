package main

import "core:encoding/base64"
import "core:encoding/json"
import "core:fmt"
import mem "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode/utf8"
import rl "vendor:raylib"

gui_enable :: proc() {
	rl.GuiEnable()
	state.gui_enabled = true
}

gui_disable :: proc() {
	rl.GuiDisable()
	state.gui_enabled = false
}

set_text_size :: proc(size: i32) {
	state.gui_properties.TEXT_SIZE = size
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, size)
}

text_align_left :: proc() {
	rl.GuiSetStyle(
		.DEFAULT,
		cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT,
		cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT,
	)
}

text_align_center :: proc() {
	rl.GuiSetStyle(
		.DEFAULT,
		cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT,
		cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER,
	)
}

get_text_width :: proc(text: cstring, text_size: i32) -> i32 {
	return rl.MeasureText(text, text_size)
}

get_text_lines_needed :: proc(text: cstring, width: f32, font_size: i32) -> i32 {
	lines_needed: i32
	lines := strings.split_lines(cast(string)text, allocator = frame_alloc)

	for line in lines {
		lines_needed += 1
		text_width := rl.MeasureText(cstr(line), font_size)
		if cast(f32)text_width > width {
			lines_needed += cast(i32)(text_width / cast(i32)width)
		}
	}
	return lines_needed
}


fit_text :: proc(
	text: cstring,
	width: f32,
	control: rl.GuiControl,
	text_size: ^i32,
) -> (
	result: bool,
) {
	if get_text_width(text, text_size^) > cast(i32)width {
		if text_size^ > 10 {
			text_size^ -= 1
		} else {
			rl.GuiSetStyle(control, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, text_size^)
			result = false
			return
		}
		if get_text_width(text, text_size^) > cast(i32)width {
			result = fit_text(text, width, control, text_size)
		} else {
			rl.GuiSetStyle(control, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, text_size^)
			result = true
			return
		}
	} else {
		result = true
		return
	}
	return
}

crop_text :: proc(text: cstring, width: f32, text_size: i32) -> (result: cstring) {
	str := string(text)
	i := 0
	for len(str) > 0 {
		if get_text_width(cstr(str), text_size) > cast(i32)width {
			str = strings.concatenate([]string{str[:len(str) - 4], "..."}, allocator = frame_alloc)
		} else {
			result = strings.clone_to_cstring(str, allocator = frame_alloc)
			return
		}
		i += 1
	}
	return
}

scissor_start :: proc(
	panel_state: ^PanelState,
	panel_width: f32,
	scroll_locked: bool = false,
) -> bool {
	if (panel_state.height_needed > panel_state.rec.height) {
		panel_state.content_rec.width = panel_width - 14
		panel_state.content_rec.height = panel_state.height_needed
		if !scroll_locked {
			rl.GuiScrollPanel(
				panel_state.rec,
				nil,
				panel_state.content_rec,
				&panel_state.scroll,
				&panel_state.view,
			)
		}
		rl.BeginScissorMode(
			cast(i32)panel_state.view.x,
			cast(i32)panel_state.view.y,
			cast(i32)panel_state.view.width,
			cast(i32)panel_state.view.height,
		)
		return true
	} else {
		panel_state.content_rec.width = panel_width
		return false
	}
}

scissor_stop :: proc(panel_state: ^PanelState) {
	if (panel_state.height_needed > panel_state.rec.height) {
		rl.EndScissorMode()
	} else {
		panel_state.scroll.y = 0
	}
}

register_button :: proc(button_list: ^map[i32]^bool, button: $T/^GuiControl) {
	registered := false

	for test_button, _ in button_list {
		if (test_button == button.id) {
			registered = true
		}
	}

	if !registered {
		button_list[button.id] = &button.active
	}
}

reload_entities :: proc() {
	vmem.arena_free_all(&icons_arena)
	vmem.arena_free_all(&entities_arena)
	reload_icons_and_borders()
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
}

order_by_initiative :: proc(entities: ^[]Entity, num_entities: int) {
	entities_sorted := [dynamic]Entity{}

	for i in 0 ..< num_entities {
		entity := entities[i]
		sorting_loop: for sorted_entity, j in entities_sorted {
			if (entity.initiative > sorted_entity.initiative) {
				inject_at(&entities_sorted, j, entity)
				break sorting_loop
			} else if (entity.initiative == sorted_entity.initiative) {
				if entity.DEX >= sorted_entity.DEX {
					inject_at(&entities_sorted, j, entity)
					break sorting_loop
				} else {
					if j < len(entities_sorted) - 1 {
						inject_at(&entities_sorted, j + 1, entity)
						break sorting_loop
					}
				}
			} else if (j == len(entities_sorted) - 1) {
				append(&entities_sorted, entity)
				break sorting_loop
			}
		}
		if (len(entities_sorted) == 0) {
			append(&entities_sorted, entity)
		}
	}

	for entity, i in entities_sorted {
		entities[i] = entity
	}
}

match_saved_entity :: proc(entity_name: string) -> (result: Entity, ok: bool) {
	for entity in state.srd_entities {
		if str(entity.name) == entity_name {
			return entity, true
		}
	}
	for entity in state.custom_entities {
		if str(entity.name) == entity_name {
			return entity, true
		}
	}
	return Entity{}, false
}

match_entity :: proc(
	entity_name: string,
	entities: []Entity,
	num_entities: int,
) -> (
	result: Entity,
	ok: bool,
) {
	for i in 0 ..< num_entities {
		to_match := entities[i]
		if str(to_match.name) == entity_name {
			return to_match, true
		}
	}
	return Entity{}, false
}

get_entity_icon_data :: proc {
	get_entity_icon_from_paths,
	get_entity_icon_from_entity,
}

get_entity_icon_from_paths :: proc(
	icon_path: cstring,
	border_path: cstring,
	allocator: mem.Allocator = icons_alloc,
) -> (
	rl.Texture,
	string,
) {
	context.allocator = frame_alloc
	temp_icon_image := rl.LoadImage(
		cstr(state.config.CUSTOM_ENTITIES_DIR, "images", icon_path, sep = FILE_SEPERATOR),
	)
	defer rl.UnloadImage(temp_icon_image)
	temp_border_image := rl.LoadImage(
		cstr(state.config.CUSTOM_ENTITIES_DIR, "..", "borders", border_path, sep = FILE_SEPERATOR),
	)
	defer rl.UnloadImage(temp_border_image)

	img_size: i32 = 256

	if temp_icon_image.width != img_size || temp_icon_image.height != img_size {
		rl.ImageResize(&temp_icon_image, img_size, img_size)
	}
	if temp_border_image.width != img_size || temp_border_image.height != img_size {
		rl.ImageResize(&temp_border_image, img_size, img_size)
	}

	rl.ImageAlphaMask(&temp_icon_image, temp_border_image)

	rl.ImageDraw(
		&temp_border_image,
		temp_icon_image,
		{0, 0, cast(f32)temp_icon_image.width, cast(f32)temp_icon_image.height},
		{0, 0, cast(f32)temp_icon_image.width, cast(f32)temp_icon_image.height},
		rl.WHITE,
	)
	rl.ExportImage(temp_border_image, "temp.png")
	icon_data, _ := os.read_entire_file("temp.png")
	defer delete(icon_data)
	os.remove("temp.png")
	context.allocator = static_alloc
	return rl.LoadTextureFromImage(
		temp_border_image,
	), base64.encode(icon_data, allocator = allocator)
}

get_entity_icon_from_entity :: proc(entity: ^Entity) -> (rl.Texture, string) {
	rl.UnloadTexture(entity.icon)

	texture, data := get_entity_icon_from_paths(entity.img_url, entity.img_border)
	entity.icon = texture
	entity.icon_data = data
	return texture, data
}

to_i32 :: proc {
	to_i32_str,
	to_i32_cstr,
}

to_i32_str :: proc(str: string) -> i32 {
	int_val, ok := strconv.parse_i64(str)
	if ok {
		return cast(i32)int_val
	}
	return 0
}

to_i32_cstr :: proc(cstr: cstring) -> i32 {
	return to_i32_str(str(cstr))
}

combat_to_json :: proc() {
	context.allocator = server_alloc

	result := ""

	combat_timer := cast(i32)time.duration_seconds(
		time.stopwatch_duration(state.combat_screen_state.combat_timer),
	)
	turn_timer := cast(i32)time.duration_seconds(
		time.stopwatch_duration(state.combat_screen_state.turn_timer),
	)

	result = strings.join(
		[]string {
			"{\"type\": \"combat_view\",",
			"\"combat_name\": \"",
			fmt.tprint(state.setup_screen_state.filename_input.text),
			"\",\"round\": ",
			fmt.tprint(state.combat_screen_state.current_round),
			",\"current_entity_index\": ",
			fmt.tprint(state.combat_screen_state.current_entity_idx),
			",\"entities\": [",
		},
		"",
	)

	for i in 0 ..< state.combat_screen_state.num_entities {
		entity := state.combat_screen_state.entities[i]
		entity_string: string
		entity_type: string

		switch entity.type {
		case .MONSTER:
			entity_type = "monster"
		case .PLAYER:
			entity_type = "player"
		case .NPC:
			entity_type = "NPC"
		}

		entity_team: string
		#partial switch entity.team {
		case .PARTY:
			entity_team = "party"
		case .ENEMIES:
			entity_team = "enemies"
		}

		if (i < state.combat_screen_state.num_entities - 1) {
			entity_string = strings.join(
				[]string {
					"{\"name\": \"",
					fmt.tprint(entity.name),
					"\",\"alias\": \"",
					fmt.tprint(entity.alias),
					"\",\"type\": \"",
					entity_type,
					"\",\"team\": \"",
					entity_team,
					"\",\"health\": ",
					fmt.tprint(entity.HP),
					",\"max_health\": ",
					fmt.tprint(entity.HP_max),
					",\"temp_health\": ",
					fmt.tprint(entity.temp_HP),
					",\"ac\": ",
					fmt.tprint(entity.AC),
					",\"conditions\": ",
					fmt.tprintf("%v", gen_condition_string(entity.conditions)),
					",\"custom_conditions\": ",
					fmt.tprintf("%v", gen_custom_condition_string(entity.custom_conditions)),
					",\"visible\": ",
					"true" if entity.visible else "false",
					",\"dead\": ",
					"true" if !entity.alive else "false",
					",\"img_url\": \"",
					fmt.tprint(entity.icon_data) if (entity.type == .PLAYER) else fmt.tprint(entity.img_url),
					"\"",
					"},",
				},
				"",
			)
		} else {
			entity_string = strings.join(
				[]string {
					"{\"name\": \"",
					fmt.tprint(entity.name),
					"\",\"alias\": \"",
					fmt.tprint(entity.alias),
					"\",\"type\": \"",
					entity_type,
					"\",\"team\": \"",
					entity_team,
					"\",\"health\": ",
					fmt.tprint(entity.HP),
					",\"max_health\": ",
					fmt.tprint(entity.HP_max),
					",\"temp_health\": ",
					fmt.tprint(entity.temp_HP),
					",\"ac\": ",
					fmt.tprint(entity.AC),
					",\"conditions\": ",
					fmt.tprintf("%v", gen_condition_string(entity.conditions)),
					",\"visible\": ",
					"true" if entity.visible else "false",
					",\"dead\": ",
					"true" if !entity.alive else "false",
					",\"img_url\": \"",
					fmt.tprint(entity.icon_data) if (entity.type == .PLAYER) else fmt.tprint(entity.img_url),
					"\"",
					"}",
				},
				"",
			)
		}
		result = strings.join([]string{result, entity_string}, "")
	}
	result = strings.join([]string{result, "]}"}, "")
	state.server_state.json_data = result
	context.allocator = static_alloc
}

party_to_json :: proc() {
	context.allocator = server_alloc

	result := ""

	result = strings.join([]string{"{\"type\": \"party_view\"", ",\"entities\": ["}, "")

	for i in 0 ..< state.setup_screen_state.num_party {
		entity := state.setup_screen_state.party_selected[i]
		entity_string: string
		entity_type: string

		switch entity.type {
		case .MONSTER:
			entity_type = "monster"
		case .PLAYER:
			entity_type = "player"
		case .NPC:
			entity_type = "NPC"
		}

		entity_team: string
		#partial switch entity.team {
		case .PARTY:
			entity_team = "party"
		case .ENEMIES:
			entity_team = "enemies"
		}

		if (i < state.setup_screen_state.num_party - 1) {
			entity_string = strings.join(
				[]string {
					"{\"name\": \"",
					fmt.tprint(entity.name),
					"\",\"alias\": \"",
					fmt.tprint(entity.alias),
					"\",\"type\": \"",
					entity_type,
					"\",\"team\": \"",
					entity_team,
					"\",\"health\": ",
					fmt.tprint(entity.HP),
					",\"max_health\": ",
					fmt.tprint(entity.HP_max),
					",\"temp_health\": ",
					fmt.tprint(entity.temp_HP),
					",\"ac\": ",
					fmt.tprint(entity.AC),
					",\"conditions\": ",
					fmt.tprintf("%v", gen_condition_string(entity.conditions)),
					",\"visible\": ",
					"true" if entity.visible else "false",
					",\"dead\": ",
					"true" if !entity.alive else "false",
					",\"img_url\": \"",
					fmt.tprint(entity.icon_data) if (entity.type == .PLAYER) else fmt.tprint(entity.img_url),
					"\"",
					"},",
				},
				"",
			)
		} else {
			entity_string = strings.join(
				[]string {
					"{\"name\": \"",
					fmt.tprint(entity.name),
					"\",\"alias\": \"",
					fmt.tprint(entity.alias),
					"\",\"type\": \"",
					entity_type,
					"\",\"team\": \"",
					entity_team,
					"\",\"health\": ",
					fmt.tprint(entity.HP),
					",\"max_health\": ",
					fmt.tprint(entity.HP_max),
					",\"temp_health\": ",
					fmt.tprint(entity.temp_HP),
					",\"ac\": ",
					fmt.tprint(entity.AC),
					",\"conditions\": ",
					fmt.tprintf("%v", gen_condition_string(entity.conditions)),
					",\"visible\": ",
					"true" if entity.visible else "false",
					",\"dead\": ",
					"true" if !entity.alive else "false",
					",\"img_url\": \"",
					fmt.tprint(entity.icon_data) if (entity.type == .PLAYER) else fmt.tprint(entity.img_url),
					"\"",
					"}",
				},
				"",
			)
		}
		result = strings.join([]string{result, entity_string}, "")
	}
	result = strings.join([]string{result, "]}"}, "")
	state.server_state.json_data = result
	context.allocator = static_alloc
}

add_to_damage_set :: proc(damage_types: ^DamageSet, damage_type: cstring) {
	switch damage_type {
	case "Slashing":
		damage_types^ ~= {.SLASHING}
	case "Piercing":
		damage_types^ ~= {.PIERCING}
	case "Bludgeoning":
		damage_types^ ~= {.BLUDGEONING}
	case "Non-magical":
		damage_types^ ~= {.NON_MAGICAL}
	case "Poison":
		damage_types^ ~= {.POISON}
	case "Acid":
		damage_types^ ~= {.ACID}
	case "Fire":
		damage_types^ ~= {.FIRE}
	case "Cold":
		damage_types^ ~= {.COLD}
	case "Radiant":
		damage_types^ ~= {.RADIANT}
	case "Necrotic":
		damage_types^ ~= {.NECROTIC}
	case "Lightning":
		damage_types^ ~= {.LIGHTNING}
	case "Thunder":
		damage_types^ ~= {.THUNDER}
	case "Force":
		damage_types^ ~= {.FORCE}
	case "Psychic":
		damage_types^ ~= {.PSYCHIC}
	}

}
