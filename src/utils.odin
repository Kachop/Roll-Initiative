package main

import "core:fmt"
import "core:unicode/utf8"
import "core:os"
import "core:encoding/base64"
import "core:strconv"
import "core:encoding/json"
import "core:strings"
import "core:time"
import vmem "core:mem/virtual"
import rl "vendor:raylib"


text_align_left :: proc() {
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
}

text_align_center :: proc() {
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
}

get_text_width :: proc(text: cstring, text_size: i32) -> i32 {
    return rl.MeasureText(text, text_size)
}

get_text_lines_needed :: proc(text: cstring, width: f32, font_size: i32) -> i32 {
  lines_needed: i32
  lines := strings.split_lines(cast(string)text, allocator=frame_alloc)

  for line in lines {
    lines_needed += 1
    text_width := rl.MeasureText(cstr(line), font_size)
    if cast(f32)text_width > width {
      lines_needed += cast(i32)(text_width / cast(i32)width)
    }
  }
  return lines_needed
}


fit_text :: proc(text: cstring, width: f32, control: rl.GuiControl, text_size: ^i32) -> (result: bool){
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
    i   := 0
    for len(str) > 0 {
        if get_text_width(cstr(str), text_size) > cast(i32)width {
            str = strings.concatenate([]string{str[:len(str)-4], "..."}, allocator=frame_alloc)
        } else {
            result = strings.clone_to_cstring(str, allocator=frame_alloc)
            return
        }
        i += 1
    }
    return
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
    vmem.arena_free_all(&entities_arena)
    //state.srd_entities    = make(#soa[dynamic]Entity, entities_alloc)
    //state.custom_entities = make(#soa[dynamic]Entity, entities_alloc)
    load_entities_from_file(state.config.ENTITY_FILE_PATH, &state.srd_entities)
    load_entities_from_file(state.config.CUSTOM_ENTITY_FILE_PATH, &state.custom_entities)
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
                if entity.DEX_mod >= sorted_entity.DEX_mod {
                    inject_at(&entities_sorted, j, entity)
                    break sorting_loop
                } else {
                    if j < len(entities_sorted) - 1 {
                        inject_at(&entities_sorted, j, entity)
                        break sorting_loop
                    }
                }
            } else if (j == len(entities_sorted) -1) {
                append(&entities_sorted, entity)
                break sorting_loop
            }
        }
        if (len(entities_sorted) == 0) {
            append(&entities_sorted, entity)
        }
    }

    for i in 0 ..< num_entities {
        entities[i] = entities_sorted[i]
    }
}

match_entity :: proc(entity_name: string) -> (result: Entity, ok: bool) {
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


get_entity_icon_data :: proc{get_entity_icon_from_paths, get_entity_icon_from_entity}

get_entity_icon_from_paths :: proc(icon_path: cstring, border_path: cstring) -> (rl.Texture, string) {
    temp_icon_image := rl.LoadImage(cstr(state.config.CUSTOM_ENTITIES_DIR, "images", icon_path, sep=FILE_SEPERATOR))
    defer rl.UnloadImage(temp_icon_image)
    temp_border_image := rl.LoadImage(cstr(state.config.CUSTOM_ENTITIES_DIR, "..", "borders", border_path, sep=FILE_SEPERATOR))
    defer rl.UnloadImage(temp_border_image)

    if temp_icon_image.width != 128 || temp_icon_image.height != 128 {
        rl.ImageResize(&temp_icon_image, 128, 128)
    }
    if temp_border_image.width != 128 || temp_border_image.height != 128 {
        rl.ImageResize(&temp_border_image, 128, 128)
    }

    rl.ImageAlphaMask(&temp_icon_image, temp_border_image)

    rl.ImageDraw(&temp_border_image, temp_icon_image, {0, 0, cast(f32)temp_icon_image.width, cast(f32)temp_icon_image.height}, {0, 0, cast(f32)temp_icon_image.width, cast(f32)temp_icon_image.height}, rl.WHITE)
    rl.ExportImage(temp_border_image, "temp.png")
    icon_data, _ := os.read_entire_file("temp.png")
    os.remove("temp.png")
    return rl.LoadTextureFromImage(temp_border_image), base64.encode(icon_data)
}

get_entity_icon_from_entity :: proc(entity: ^Entity) -> (rl.Texture, string) {
    texture, data := get_entity_icon_from_paths(entity.img_url, entity.img_border)
    entity.icon_data = data
    return texture, data
}

to_i32 :: proc{to_i32_str, to_i32_cstr}

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
    delete(state.server_state.json_data)
    result := ""

    combat_timer := cast(i32)time.duration_seconds(time.stopwatch_duration(state.combat_screen_state.combat_timer))
    turn_timer := cast(i32)time.duration_seconds(time.stopwatch_duration(state.combat_screen_state.turn_timer))

    result = strings.join([]string{
        "{\"round\": ",
        fmt.tprint(state.combat_screen_state.current_round),
        ",\"current_entity_index\": ",
        fmt.tprint(state.combat_screen_state.current_entity_idx),
        ",\"entities\": ["}, "")

    for i in 0 ..< state.combat_screen_state.num_entities {
        entity := state.combat_screen_state.entities[i]
        entity_string: string
        entity_type  : string
        
        switch entity.type {
        case .MONSTER:
            entity_type = "monster"
        case .PLAYER:
            entity_type = "player"
        case .NPC:
            entity_type = "NPC"
        }
    
        if (i < state.combat_screen_state.num_entities - 1) {
            entity_string = strings.join([]string{
                "{\"name\": \"",
                fmt.tprint(entity.name),
                "\",\"alias\": \"",
                fmt.tprint(entity.alias),
                "\",\"type\": \"",
                entity_type,
                "\",\"health\": ",
                fmt.tprint(entity.HP),
                ",\"max_health\": ",
                fmt.tprint(entity.HP_max),
                ",\"temp_health\": ",
                fmt.tprint(entity.temp_HP),
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
            }, "")
        } else {
            entity_string = strings.join([]string{
                "{\"name\": \"",
                fmt.tprint(entity.name),
                "\",\"alias\": \"",
                fmt.tprint(entity.alias),
                "\",\"type\": \"",
                entity_type,
                "\",\"health\": ",
                fmt.tprint(entity.HP),
                ",\"max_health\": ",
                fmt.tprint(entity.HP_max),
                ",\"temp_health\": ",
                fmt.tprint(entity.temp_HP),
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
            }, "")
        }
        result = strings.join([]string{result, entity_string}, "")
    }
 
    result = strings.join([]string{result, "]}"}, "")
    state.server_state.json_data = result
    context.allocator = static_alloc
    return
}

