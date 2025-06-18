package main

import "core:encoding/json"
import "core:log"
import "core:os"
import "core:strings"

load_combat_file :: proc(filename: string) -> (error: bool) {
	for i in 0 ..< state.setup_screen_state.num_entities {
		state.setup_screen_state.entities_selected[i] = Entity{}
	}

	file_data, ok := os.read_entire_file(filename)
	defer delete(file_data)

	idx := 0

	if ok {
		json_data, err := json.parse(file_data)

		if err == .None {
			for alias, fields in json_data.(json.Object) {
				loaded_entity, ok := match_entity(fields.(json.Object)["name"].(string))

				loaded_entity.alias = strings.clone_to_cstring(alias)
				loaded_entity.initiative = cast(i32)fields.(json.Object)["initiative"].(json.Float)
				loaded_entity.visible = cast(bool)fields.(json.Object)["visible"].(json.Boolean)

				state.setup_screen_state.entities_selected[idx] = loaded_entity

				entity_button_state := new(EntityButtonState)
				init_entity_button_state(
					entity_button_state,
					&state.setup_screen_state.entities_selected[idx],
					&state.setup_screen_state.entity_button_states,
					idx,
				)
				append(&state.setup_screen_state.entity_button_states, entity_button_state^)

				idx += 1
			}
		} else {
			log.errorf("%v", err)
			return false
		}
	} else {
		return false
	}
	state.setup_screen_state.num_entities = idx
	return true
}

save_combat_file :: proc(filename: string) -> bool {
	file := init_file(filename)

	entity_data := Object{}

	for i in 0 ..< state.setup_screen_state.num_entities {
		entity := state.setup_screen_state.entities_selected[i]
		entity_map := Object{}

		entity_map["name"] = cast(String)entity.name
		entity_map["initiative"] = cast(Integer)entity.initiative
		entity_map["visible"] = cast(Boolean)entity.visible

		entity_data[str(entity.alias)] = entity_map
	}

	add_object("", entity_data, &file)
	return write(filename, file)
}
