package main

import "core:os"
import "core:log"
import "core:strings"
import "core:encoding/json"

Combat :: struct {
    entities: [dynamic]Entity,
    round   : i32,
}

load_combat_file :: proc(filename: string) -> (combat: Combat, error: bool) {

    file_data, ok := os.read_entire_file(filename)
    defer delete(file_data)

    if ok {
        json_data, err := json.parse(file_data)

        if err == .None {
            for alias, fields in json_data.(json.Object) {
                loaded_entity, ok := match_entity(fields.(json.Object)["name"].(string))

                loaded_entity.alias      = strings.clone_to_cstring(alias)
                loaded_entity.initiative = cast(i32)fields.(json.Object)["initiative"].(json.Float)
                loaded_entity.visible    = cast(bool)fields.(json.Object)["visible"].(json.Boolean)

                append(&combat.entities, loaded_entity)
            }
        } else {
            log.errorf("%v", err)
            return combat, false
        }
    } else {
        return combat, false
    }
    return combat, true
}

save_combat_file :: proc(filename: string) -> bool {
    file := init_file(filename)
  
    entity_data := Object{}

    for entity, i in state.current_combat.entities {
        entity_map := Object{}

        entity_map["name"]       = cast(String)entity.name
        entity_map["initiative"] = cast(Integer)entity.initiative
        entity_map["visible"]    = cast(Boolean)entity.visible

        entity_data[str(entity.alias)] = entity_map
    }

    add_object("", entity_data, &file)
    return write(filename, file)
}
