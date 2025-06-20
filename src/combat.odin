package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"

load_combat_file :: proc(filename: string) -> (error: bool) {
	for &entity in state.setup_screen_state.party_selected {
		entity = Entity{}
	}
	for &entity in state.setup_screen_state.enemies_selected {
		entity = Entity{}
	}

	file_data, ok := os.read_entire_file(filename, allocator = frame_alloc)

	idx := 0

	if ok {
		json_data, err := json.parse(file_data)

		if err == .None {
			party_saved := json_data.(json.Object)["party"]
			enemies_saved := json_data.(json.Object)["enemies"]

			for alias, fields in party_saved.(json.Object) {
				loaded_entity, ok := match_entity(fields.(json.Object)["name"].(string))

				loaded_entity.alias = fmt.caprint(alias)
				loaded_entity.team = .PARTY
				loaded_entity.initiative = cast(i32)fields.(json.Object)["initiative"].(json.Float)
				loaded_entity.visible = cast(bool)fields.(json.Object)["visible"].(json.Boolean)

				state.setup_screen_state.party_selected[idx] = loaded_entity

				entity_button_state := new(EntityButtonState)
				init_entity_button_state(
					entity_button_state,
					&state.setup_screen_state.party_selected[idx],
					&state.setup_screen_state.party_button_states,
					idx,
				)
				append(&state.setup_screen_state.party_button_states, entity_button_state^)
				idx += 1
			}
			state.setup_screen_state.num_party = idx
			idx = 0

			for alias, fields in enemies_saved.(json.Object) {
				loaded_entity, ok := match_entity(fields.(json.Object)["name"].(string))

				loaded_entity.alias = fmt.caprint(alias)
				loaded_entity.team = .ENEMIES
				loaded_entity.initiative = cast(i32)fields.(json.Object)["initiative"].(json.Float)
				loaded_entity.visible = cast(bool)fields.(json.Object)["visible"].(json.Boolean)

				state.setup_screen_state.enemies_selected[idx] = loaded_entity

				entity_button_state := new(EntityButtonState)
				init_entity_button_state(
					entity_button_state,
					&state.setup_screen_state.enemies_selected[idx],
					&state.setup_screen_state.enemy_button_states,
					idx,
				)
				append(&state.setup_screen_state.enemy_button_states, entity_button_state^)
				idx += 1
			}
			state.setup_screen_state.num_enemies = idx
		} else {
			log.errorf("%v", err)
			return false
		}
	} else {
		log.error("Failed to read file")
		return false
	}
	return true
}

save_combat_file :: proc(filename: string) -> bool {
	file := init_file(filename)

	combat_data := Object{}

	party := Object{}

	for i in 0 ..< state.setup_screen_state.num_party {
		entity := state.setup_screen_state.party_selected[i]
		entity_obj := Object{}

		entity_obj["name"] = cast(String)entity.name
		entity_obj["initiative"] = cast(Integer)entity.initiative
		entity_obj["visible"] = cast(Boolean)entity.visible

		party[str(entity.alias)] = entity_obj
	}

	enemies := Object{}

	for i in 0 ..< state.setup_screen_state.num_enemies {
		entity := state.setup_screen_state.enemies_selected[i]
		entity_obj := Object{}

		entity_obj["name"] = cast(String)entity.name
		entity_obj["initiative"] = cast(Integer)entity.initiative
		entity_obj["visible"] = cast(Boolean)entity.visible

		enemies[str(entity.alias)] = entity_obj
	}

	combat_data["party"] = party
	combat_data["enemies"] = enemies

	add_object("", combat_data, &file)
	return write(filename, file)
}
