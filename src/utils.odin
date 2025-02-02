package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:time"
import rl "vendor:raylib"
import "core:encoding/base64"

TextInputState :: struct {
  edit_mode: bool,
  alloc: [256]rune,
  text: cstring,
}

InitTextInputState :: proc(inputState: ^TextInputState) {
  inputState.text = fmt.ctprint(utf8.runes_to_string(inputState.alloc[:], context.temp_allocator))
}

GuiTextInput :: proc(bounds: rl.Rectangle, inputState: ^TextInputState) {
  if (rl.GuiTextBox(bounds, inputState.text, size_of(inputState.alloc), inputState.edit_mode)) {
    if (!state.hover_consumed) {
        inputState.edit_mode = !inputState.edit_mode
    }
  }
}

DropdownState :: struct {
  title: cstring,
  labels: []cstring,
  selected: i32,
  active: bool,
}

InitDropdownState :: proc(state: ^DropdownState, title: cstring, labels: []cstring) {
  state.title = title
  state.labels = labels
}

DropdownSelectState :: struct {
  title: cstring,
  labels: []cstring,
  selected: [dynamic]bool,
  active: bool,
}

InitDropdownSelectState :: proc(dropdownState: ^DropdownSelectState, title: cstring, labels: []cstring) {
  dropdownState.title = title
  dropdownState.labels = labels
}

DeInitDropdownSelectState :: proc(dropdownState: ^DropdownSelectState) {
  delete(dropdownState.labels)
}

PanelState :: struct {
  rec: rl.Rectangle,
  contentRec: rl.Rectangle,
  view: rl.Rectangle,
  scroll: rl.Vector2,
  height_needed: f32,
  active: bool,
}

InitPanelState :: proc(state: ^PanelState) {
  state.rec = {0, 0, 0, 0}
  state.contentRec = {}
  state.view = {0, 0, 0, 0}
  state.scroll = {0, 0}
}

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

str_to_int :: proc{
    cstr_to_int,
    _str_to_int}

cstr_to_int :: proc(cstr: cstring) -> i32 {
    return _str_to_int(string(cstr))
}

_str_to_int :: proc(str: string) -> i32 {
    digits : f32 = cast(f32)len(str)
    current_digit : f32 = 1
    num : f32 = 0
    negative: bool

    if str == "" {
        return 0
    }
    
    if str[0] == '-' {
        negative = true
    }
  
    for char in str {
        switch cast(byte)char {
        case 49:
            num += 1 * math.pow10(digits - current_digit)
        case 50:
            num += 2 * math.pow10(digits - current_digit)
        case 51:
            num += 3 * math.pow10(digits - current_digit)
        case 52:
            num += 4 * math.pow10(digits - current_digit)
        case 53:
            num += 5 * math.pow10(digits - current_digit)
        case 54:
            num += 6 * math.pow10(digits - current_digit)
        case 55:
            num += 7 * math.pow10(digits - current_digit)
        case 56:
            num += 8 * math.pow10(digits - current_digit)
        case 57:
            num += 9 * math.pow10(digits - current_digit)
        }
        current_digit += 1
    }
    if negative {
        return cast(i32)-num
    }
    return cast(i32)num
}
 
int_to_str :: proc(num: i32) -> cstring {
    num := num
    digits := 0
    temp_num := num
    runes: [dynamic]rune
    digit_found: bool = false
  
    for {
        digits += 1
        temp_num = temp_num / 10
        if temp_num == 0 {
            break
        }
    }

    if (num < 0) {
        append(&runes, cast(rune)'-')
    }
  
    temp_num = num
  
    digit_loop: for i in 0..<digits {
        temp_num = num
        digit_finder: for digit_found == false {
            if ((temp_num >= 0) && (temp_num < 10)) {
                digit_found = true
                break digit_finder
            } else if ((temp_num < 0) && (temp_num > -10)) {
                digit_found = true
                break digit_finder
            }
            temp_num = (temp_num / 10)
        }
        switch temp_num {
        case 0:
            append(&runes, cast(rune)48)
        case 1, -1:
            append(&runes, cast(rune)49)
        case 2, -2:
            append(&runes, cast(rune)50)
        case 3, -3:
            append(&runes, cast(rune)51)
        case 4, -4:
            append(&runes, cast(rune)52)
        case 5, -5:
            append(&runes, cast(rune)53)
        case 6, -6:
            append(&runes, cast(rune)54)
        case 7, -7:
            append(&runes, cast(rune)55)
        case 8, -8:
            append(&runes, cast(rune)56)
        case 9, -9:
            append(&runes, cast(rune)57)
        }
        if (num >= 0) {
            num -= cast(i32)(cast(f32)temp_num * math.pow10(cast(f32)digits - (cast(f32)i + 1)))
            digit_found = false
        } else if (num < 0) {
            num += cast(i32)(cast(f32)temp_num * math.pow10(cast(f32)digits - (cast(f32)i + 1)))
            digit_found = false
        }
    }
    result := cstr(utf8.runes_to_string(runes[:], context.temp_allocator))
    delete(runes)
    return result
}

order_by_initiative :: proc(entities: ^[dynamic]Entity) {
    entities_sorted := [dynamic]Entity{}

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
        "{\"combat_timer\": ",
        fmt.tprint(combat_timer),
        ",\"turn_timer\": ",
        fmt.tprint(turn_timer),
        ",\"round\": ",
        fmt.tprint(combatState.current_round),
        ",\"current_entity_index\": ",
        fmt.tprint(combatState.current_entity_index),
        ",\"entities\": ["}, "")

    for entity, i in combatState.entities {
        entity_string: string
        defer delete(entity_string)
        entity_type: string
        img: []u8
        defer delete(img)
        
        switch entity.type {
        case .MONSTER:
            entity_type = "monster"
        case .PLAYER:
            entity_type = "player"
            img, _ = os.read_entire_file(string(entity.img_url))
        case .NPC:
            entity_type = "NPC"
            img, _ = os.read_entire_file(string(entity.img_url))
        }
        
        img_str := base64.encode(img)
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
                ",\"conditions\": [\"none\"]",
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
                ",\"conditions\": [\"none\"]",
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
    //delete(result)
    return
}
