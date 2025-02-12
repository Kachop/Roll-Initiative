package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:time"
import rl "vendor:raylib"
import "core:encoding/base64"
import "core:strconv"

getTextWidth :: proc(text: cstring, text_size: i32) -> i32 {
    return rl.MeasureText(text, text_size)
}

getTextHeight :: proc(text: cstring, text_size: i32) -> i32 {
    state.gui_properties.FONT = rl.GuiGetFont()
    spacing := rl.GuiGetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SPACING)
    return cast(i32)rl.MeasureTextEx(state.gui_properties.FONT, text, cast(f32)text_size, cast(f32)(spacing))[1]
}
 
fit_text :: proc(text: cstring, width: f32, text_size: ^i32) -> (result: bool){
    if getTextWidth(text, text_size^) > cast(i32)width {
        if text_size^ > 10 {
            text_size^ -= 1
        } else {
            rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, text_size^)
            result = false
            return
        }
        if getTextWidth(text, text_size^) > cast(i32)width {
            result = fit_text(text, width, text_size)
        } else {
            rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, text_size^)
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
    display_string: [dynamic]rune
    for char in string(text) {
        append(&display_string, char)
        if getTextWidth(fmt.ctprint(utf8.runes_to_string(display_string[:])), text_size) > cast(i32)width {
            pop(&display_string)
            pop(&display_string)
            pop(&display_string)
            pop(&display_string)
            append(&display_string, rune('.'))
            append(&display_string, rune('.'))
            append(&display_string, rune('.'))
            result = fmt.ctprint(utf8.runes_to_string(display_string[:]))
            return
        }
    }
    result = fmt.ctprint(utf8.runes_to_string(display_string[:]))
    delete(display_string)
    return
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

order_by_initiative :: proc(entities: ^[dynamic]Entity) {
    entities_sorted := [dynamic]Entity{}
    for entity in entities {
        fmt.println(entity.name)
    }

    for entity in entities {
        sorting_loop: for sorted_entity, j in entities_sorted {
            if (entity.initiative > sorted_entity.initiative) {
                inject_at(&entities_sorted, j, entity)
                break sorting_loop
            } else if (entity.initiative == sorted_entity.initiative) {
                if entity.DEX_mod > sorted_entity.DEX_mod {
                    inject_at(&entities_sorted, j, entity)
                    break sorting_loop
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
    entities^ = entities_sorted
}

match_entity :: proc(entity_name: string) -> (result: i32, found: bool) {
    for entity, i in state.srd_entities {
        if string(entity.name) == entity_name {
            result = cast(i32)i
            found = true
            return
        }
    }
    return
}

get_entity_icon_data :: proc{get_entity_icon_from_paths, get_entity_icon_from_entity}

get_entity_icon_from_paths :: proc(icon_path: cstring, border_path: cstring) -> (rl.Texture, []u8) {
  temp_icon_image := rl.LoadImage(cstr(state.config.CUSTOM_ENTITY_PATH, "images", icon_path, sep=FILE_SEPERATOR))
  defer rl.UnloadImage(temp_icon_image)
  temp_border_image := rl.LoadImage(cstr(state.config.CUSTOM_ENTITY_PATH, "..", "borders", border_path, sep=FILE_SEPERATOR))
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
  return rl.LoadTextureFromImage(temp_border_image), icon_data
}

get_entity_icon_from_entity :: proc(entity: ^Entity) -> (rl.Texture, []u8) {
  texture, data := get_entity_icon_from_paths(entity.img_url, entity.img_border)
  entity.icon_data = data
  return get_entity_icon_from_paths(entity.img_url, entity.img_border)
}

combat_to_json :: proc(combatState: CombatScreenState) {
    //Convert current combat state to json string.
    /*{
        "combat_timer": 154,
        "turn_timer": 154,
        "round": 2,
        entities: [
          "entity_name": {
            "health": 0,
            "max_health": 0,
            "conditions": [],
            "visible": true,
            "dead": false,
          },
          "entity_name": {
            "health": 0,
            ...
          },
        ],
      }*/
    
    result := ""
    
    combat_timer := cast(i32)time.duration_seconds(time.stopwatch_duration(combatState.combat_timer))
    turn_timer := cast(i32)time.duration_seconds(time.stopwatch_duration(combatState.turn_timer))

    result = strings.join([]string{
        "{\"round\": ",
        fmt.tprint(combatState.current_round),
        ",\"current_entity_index\": ",
        fmt.tprint(combatState.current_entity_index),
        ",\"entities\": ["}, "")

    for entity, i in combatState.entities {
        entity_string: string
        defer delete(entity_string)
        entity_type: string
        
        switch entity.type {
        case .MONSTER:
            entity_type = "monster"
        case .PLAYER:
            entity_type = "player"
        case .NPC:
            entity_type = "NPC"
        }
        
        img_str := base64.encode(entity.icon_data)
        defer delete(img_str)
        
        if (i < len(combatState.entities) - 1) {
            entity_string = strings.join([]string{
                "{\"name\": \"",
                fmt.tprint(entity.name),
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
                img_str if (entity.type == .PLAYER) else string(entity.img_url),
                "\"",
                "},",
            }, "")
        } else {
            entity_string = strings.join([]string{
                "{\"name\": \"",
                string(entity.name),
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
                img_str if (entity.type == .PLAYER) else string(entity.img_url),
                "\"",
                "}",
            }, "")
        }
        result = strings.join([]string{result, entity_string}, "")
    }
    
    result = strings.join([]string{result, "]}"}, "")
    
    serverState.json_data = result
    return
}
