#+feature dynamic-literals

package main

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:time"
import rl "vendor:raylib"

frame := 0

DamageType :: enum {
  SLASHING,
  PIERCING,
  BLUDGEONING,
  NON_MAGICAL,
  POISON,
  ACID,
  FIRE,
  COLD,
  RADIANT,
  NECROTIC,
  LIGHTNING,
  THUNDER,
  FORCE,
  PSYCHIC,
}

Condition :: enum {
  BLINDED,
  CHARMED,
  DEAFENED,
  FRIGHTENED,
  GRAPPLED,
  INCAPACITATED,
  INVISIBLE,
  PARALYZED,
  PETRIFIED,
  POISONED,
  PRONE,
  RESTRAINED,
  STUNNED,
  UNCONSCIOUS,
  EXHAUSTION,
}

CombatState :: struct {
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
    height_needed_mid: f32,
    from_dropdown: DropdownState,
    to_dropdown: DropdownSelectState,
    dmg_type_selected: DamageType,
    dmg_type_dropdown: DropdownState,
    dmg_input: TextInputState,
    heal_input: TextInputState,
    condition_dropdown: DropdownState,
    temp_HP_input: TextInputState,
    panelRight: PanelState,
    json_data: string,
    stats_lines_needed: f32,
}

InitCombatState :: proc(combatState: ^CombatState) {
    combatState.first_load = true
    combatState.entities = [dynamic]Entity{}
    combatState.current_entity_index = 0
    combatState.current_entity = nil
    combatState.current_round = 1
    combatState.turn_timer = time.Stopwatch{}
    combatState.combat_timer = time.Stopwatch{}
    InitPanelState(&combatState.panelLeft)
    InitPanelState(&combatState.panelMid)
    InitDropdownState(&combatState.from_dropdown, "From:", []cstring{})
    InitDropdownSelectState(&combatState.to_dropdown, "To:", []cstring{})
    dmg_type_options := [dynamic]cstring{"Slashing", "Piercing", "Bludgeoning", "Non-magical", "Poison", "Acid", "Fire", "Cold", "Radiant", "Necrotic", "Lightning", "Thunder", "Force", "Psychic"}
    InitDropdownState(&combatState.dmg_type_dropdown, "Type:", dmg_type_options[:])
    InitTextInputState(&combatState.dmg_input)
    InitTextInputState(&combatState.heal_input)
    conditions := [dynamic]cstring{"Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", "Invisible", "Paralyzed", "Petrified", "Petrified", "Poisoned", "Prone", "Restrained", "Stunned", "Unconsious", "Exhaustion"}
    InitDropdownState(&combatState.condition_dropdown, "Condition:", conditions[:])
    InitTextInputState(&combatState.temp_HP_input)
    InitPanelState(&combatState.panelRight)
    combatState.json_data = "{}"
    combatState.stats_lines_needed = 0
    //delete(dmg_type_options)
    //delete(conditions)
}

DeInitCombatState :: proc(combatState: ^CombatState) {
  delete(combatState.entities)
}

dropdown_btn_list: [dynamic]i32
dropdown_btn_list_active: [dynamic]^bool

GuiDrawCombatScreen :: proc(combatState: ^CombatState) {
    using state.gui_properties

    cursor_x : f32 = PADDING_LEFT
    cursor_y : f32 = PADDING_TOP

    if (frame == 60) {
        combat_to_json(combatState^) 
        frame = 0
    }
    defer frame += 1
  
    initial_text_size := TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE_DEFAULT)
    
    if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, "Back")) {
        state.current_view_index -= 1
        combatState.first_load = true
        return
    }
    cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_ARROW_LEFT, ""))) {
        //Go back to previous turn
        if (combatState.current_entity_index == 0) {
            if (combatState.current_round > 1) {
                combatState.current_entity_index = cast(i32)len(combatState.entities) - 1
                combatState.current_round -= 1
            }
        } else {
            combatState.current_entity_index -= 1
        }
        combatState.current_entity = &combatState.entities[combatState.current_entity_index]
        time.stopwatch_reset(&combatState.turn_timer)
        if (combatState.combat_timer.running) {
            time.stopwatch_start(&combatState.turn_timer)
        }
    }
    cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
    
    if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_ARROW_RIGHT, ""))) {
        //Go to next turn
        if (combatState.current_entity_index == cast(i32)len(combatState.entities) - 1) {
            combatState.current_entity_index = 0
            combatState.current_round += 1
        } else {
            combatState.current_entity_index += 1
        }
        combatState.current_entity = &combatState.entities[combatState.current_entity_index]
        time.stopwatch_reset(&combatState.turn_timer)
        if (combatState.combat_timer.running) {
            time.stopwatch_start(&combatState.turn_timer)
        }
    }
    cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING

    TEXT_SIZE = TEXT_SIZE_TITLE
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)  

    available_title_width := state.window_width - cursor_x - PADDING_RIGHT - (MENU_BUTTON_WIDTH * 2) - (MENU_BUTTON_PADDING * 2)
    fit_text("Combat Control", available_title_width, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, available_title_width, MENU_BUTTON_HEIGHT}, "Combat Control")
    cursor_x += available_title_width + MENU_BUTTON_PADDING
    
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_PLAY, "") if (!combatState.combat_timer.running) else rl.GuiIconText(.ICON_PLAYER_PAUSE, ""))) {
        if !combatState.combat_timer.running {
            time.stopwatch_start(&combatState.combat_timer)
            time.stopwatch_start(&combatState.turn_timer)
        } else {
            time.stopwatch_stop(&combatState.combat_timer)
            time.stopwatch_stop(&combatState.turn_timer)
        } 
    }

    cursor_x += MENU_BUTTON_WIDTH + MENU_BUTTON_PADDING
    
    combat_time := fmt.ctprint(time.clock_from_stopwatch(combatState.combat_timer), sep=":")
    fit_text(combat_time, (state.window_height / 8), &TEXT_SIZE)
    rl.GuiLabel({(state.window_width * 0.975) - ((state.window_height / 8) * 2) -20, (state.window_height / 8) + 10, (state.window_height / 8), 40}, combat_time)
    
    if (rl.GuiButton({cursor_x, cursor_y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT}, rl.GuiIconText(.ICON_PLAYER_STOP, ""))) {
        //End the combat, do statistics, output files etc.
        //Display key details to the web client.
    }
    cursor_x = PADDING_LEFT
    cursor_y += MENU_BUTTON_HEIGHT + MENU_BUTTON_PADDING
    current_panel_x := cursor_x
    panel_y := cursor_y
    //Layout 3 panels to fill with the different bits of info needed.
    draw_width : f32 = state.window_width - PADDING_LEFT - PADDING_RIGHT
    draw_height : f32 = state.window_height - cursor_y - PADDING_BOTTOM
  
    panel_width := state.window_width / 3.5
    panel_height := draw_height
    dynamic_x_padding : f32 = (draw_width - (3 * panel_width)) / 2

    //Will contain all entities loaded into the program for adding into the combat. Can filter by entity
    entity_select_button_height : f32 = 50

    if combatState.first_load {
        combatState.first_load = false
        combatState.panelLeft.contentRec = {
            cursor_x,
            cursor_y,
            panel_width,
            0,
        }
        combatState.panelMid.contentRec = {
            cursor_x,
            cursor_y,
            panel_width,
            0,
        }
        combatState.panelRight.contentRec = {
            cursor_x,
            cursor_y,
            panel_width,
            0,
        }
    }

    rl.GuiPanel(
        {
            cursor_x,
            cursor_y,
            panel_width,
            panel_height,
        }, "Turn Order")
 
    combatState.panelLeft.rec = {
        cursor_x,
        cursor_y + entity_select_button_height,
        panel_width,
        panel_height - entity_select_button_height,
    }
    //Text header
    rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)entity_select_button_height, CONFIG.HEADER_COLOUR)
    //Text
    turn_text := fmt.ctprintf("Round %v:", combatState.current_round)
    fit_text(turn_text, panel_width / 2, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, entity_select_button_height}, cstr(turn_text))
    cursor_x += panel_width * 0.5

    TEXT_SIZE = initial_text_size
    //Turn timer
    turn_time := fmt.ctprint(time.clock_from_stopwatch(combatState.turn_timer), sep=":")
    fit_text(turn_time, panel_width / 2, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width, entity_select_button_height}, turn_time)
    cursor_x = current_panel_x
    cursor_y += entity_select_button_height + combatState.panelLeft.scroll.y
    TEXT_SIZE = initial_text_size

    num_rows_needed := len(combatState.entities)
    num_rows_max := combatState.panelLeft.rec.height / entity_select_button_height
  
    if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
        combatState.panelLeft.contentRec.width = panel_width - 14
        combatState.panelLeft.contentRec.height = (cast(f32)num_rows_needed * entity_select_button_height)
        rl.GuiScrollPanel(combatState.panelLeft.rec, nil, combatState.panelLeft.contentRec, &combatState.panelLeft.scroll, &combatState.panelLeft.view)
  
        rl.BeginScissorMode(cast(i32)combatState.panelLeft.view.x, cast(i32)combatState.panelLeft.view.y, cast(i32)combatState.panelLeft.view.width, cast(i32)combatState.panelLeft.view.height)
        //rl.ClearBackground(rl.SKYBLUE)
    } else {
        combatState.panelLeft.contentRec.width = panel_width
    }

    for _, i in combatState.entities {
        GuiEntityButton({cursor_x, cursor_y, combatState.panelLeft.contentRec.width, entity_select_button_height}, &combatState.entities, cast(i32)i)
        if (cast(i32)i == combatState.current_entity_index) {
            rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)combatState.panelLeft.contentRec.width, cast(i32)entity_select_button_height, rl.ColorAlpha(rl.BLUE, 0.2))
        }
        cursor_y += entity_select_button_height
        TEXT_SIZE = 30
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    if (cast(i32)num_rows_needed > cast(i32)num_rows_max) {
        rl.EndScissorMode()
    } else {
        combatState.panelLeft.scroll.y = 0
    }
    
    current_panel_x += panel_width + dynamic_x_padding
    cursor_x = current_panel_x
    cursor_y = panel_y

    line_height_mid : f32 = 50

    rl.GuiPanel(
        {
            cursor_x,
            cursor_y,
            panel_width,
            panel_height,
        },
        "Combat Controls")

    rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, cast(i32)50, CONFIG.HEADER_COLOUR)
    rl.GuiLabel({cursor_x, cursor_y, panel_width, 50}, "Combat Controls")
    cursor_y += 50

    cursor_x += PANEL_PADDING
    cursor_y += PANEL_PADDING

    draw_width = panel_width - (PANEL_PADDING * 2)
    draw_height = panel_height - line_height_mid - PANEL_PADDING - 50
        
    entity_names := [dynamic]cstring{}
    for entity in combatState.entities {
        append(&entity_names, entity.name)
    }
    defer delete(entity_names)

    //Damage control
    cursor_x_from_dropdown := cursor_x
    cursor_y_from_dropdown := cursor_y

    combatState.from_dropdown.labels = entity_names[:]

    defer GuiDropdownControl({cursor_x_from_dropdown, cursor_y_from_dropdown, draw_width / 2, line_height_mid}, &combatState.from_dropdown)
    defer register_button(&dropdown_btn_list, 0, &dropdown_btn_list_active, &combatState.from_dropdown.active)
    cursor_x += draw_width / 2
        
    cursor_x_to_dropdown := cursor_x
    cursor_y_to_dropdown := cursor_y

    combatState.to_dropdown.labels = entity_names[:]
        
    defer GuiDropdownSelectControl({cursor_x_to_dropdown, cursor_y_to_dropdown, draw_width / 2, line_height_mid}, &combatState.to_dropdown)
    defer register_button(&dropdown_btn_list, 1, &dropdown_btn_list_active, &combatState.to_dropdown.active)
    cursor_x = current_panel_x + PANEL_PADDING
    cursor_y += line_height_mid + PANEL_PADDING
    
    combatState.panelMid.rec = {
        cursor_x - PANEL_PADDING,
        cursor_y,
        panel_width,
        draw_height,
    }

    scroll_locked := false
    for btn_active in dropdown_btn_list_active {
        if btn_active^ {
            scroll_locked = true
        }
    }
 
    if (combatState.height_needed_mid > draw_height) {
        combatState.panelMid.contentRec.width = panel_width - 14
        combatState.panelMid.contentRec.height = combatState.height_needed_mid
        draw_width = panel_width - (PANEL_PADDING * 2) - 14
        //rl.DrawRectangle(cast(i32)combatState.panelMid.rec.x, cast(i32)combatState.panelMid.rec.y, cast(i32)combatState.panelMid.rec.width, cast(i32)combatState.panelMid.rec.height, rl.ColorAlpha(rl.WHITE, 1))
        rl.GuiLine({combatState.panelMid.rec.x, combatState.panelMid.rec.y, combatState.panelMid.rec.width, 5}, "") 
        if !scroll_locked {
            rl.GuiScrollPanel(combatState.panelMid.rec, nil, combatState.panelMid.contentRec, &combatState.panelMid.scroll, &combatState.panelMid.view)
        }
        rl.BeginScissorMode(cast(i32)combatState.panelMid.view.x, cast(i32)combatState.panelMid.view.y, cast(i32)combatState.panelMid.view.width, cast(i32)combatState.panelMid.view.height)
        //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
    } else {
        combatState.panelMid.contentRec.width = panel_width
        draw_width = panel_width - (PANEL_PADDING * 2)
    } 

    {
        cursor_y += PANEL_PADDING + combatState.panelMid.scroll.y
        combatState.height_needed_mid = 0
        start_y := cursor_y
        rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Damage")
        cursor_x += draw_width / 2

        cursor_x_dmg_type := cursor_x
        cursor_y_dmg_type := cursor_y

        defer GuiDropdownControl({cursor_x_dmg_type, cursor_y_dmg_type, draw_width / 2, line_height_mid}, &combatState.dmg_type_dropdown)
        defer register_button(&dropdown_btn_list, 2, &dropdown_btn_list_active, &combatState.dmg_type_dropdown.active)
        cursor_x = current_panel_x + PANEL_PADDING
        cursor_y += line_height_mid + PANEL_PADDING
        
        switch combatState.dmg_type_dropdown.labels[combatState.dmg_type_dropdown.selected] {
        case "Slashing":
            combatState.dmg_type_selected = .SLASHING
        case "Piercing":
            combatState.dmg_type_selected = .PIERCING
        case "Bludgeoning":
            combatState.dmg_type_selected = .BLUDGEONING
        case "Non-magical":
            combatState.dmg_type_selected = .NON_MAGICAL
        case "Poison":
            combatState.dmg_type_selected = .POISON
        case "Acid":
            combatState.dmg_type_selected = .ACID
        case "Fire":
            combatState.dmg_type_selected = .FIRE
        case "Cold":
            combatState.dmg_type_selected = .COLD
        case "Radiant":
            combatState.dmg_type_selected = .RADIANT
        case "Necrotic":
            combatState.dmg_type_selected = .NECROTIC
        case "Lightning":
            combatState.dmg_type_selected = .LIGHTNING
        case "Thunder":
            combatState.dmg_type_selected = .THUNDER
        case "Force":
            combatState.dmg_type_selected = .FORCE
        case "Psychic":
            combatState.dmg_type_selected = .PSYCHIC
        }

        fit_text("Amount:", draw_width / 3, &TEXT_SIZE)
        TEXT_SIZE = initial_text_size
        rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
        cursor_x += draw_width / 3

        GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.dmg_input)
        cursor_x += draw_width / 3

        fit_text("Resolve", draw_width / 3, &TEXT_SIZE)
        TEXT_SIZE = initial_text_size
        if rl.GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") && (!combatState.to_dropdown.active) {
            resolve_damage(combatState)
        }
        cursor_x = current_panel_x + PANEL_PADDING
        cursor_y += line_height_mid + PANEL_PADDING
        //Healing control
        rl.GuiLabel({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Healing")
        cursor_y += line_height_mid + PANEL_PADDING
        
        fit_text("Amount:", draw_width / 3, &state.gui_properties.TEXT_SIZE)
        TEXT_SIZE = initial_text_size
        rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
        cursor_x += draw_width / 3
 
        GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.heal_input)
        cursor_x += draw_width / 3
        
        fit_text("Resolve", draw_width / 3, &TEXT_SIZE)
        TEXT_SIZE = initial_text_size
        if rl.GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") && (!combatState.to_dropdown.active) {
            resolve_healing(combatState)
        }
        cursor_x = current_panel_x + PANEL_PADDING
        cursor_y += line_height_mid + PANEL_PADDING

        rl.GuiLabel({cursor_x, cursor_y, draw_width, line_height_mid}, "Temp HP")
        cursor_y += line_height_mid + PANEL_PADDING
        
        rl.GuiLabel({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Amount:")
        cursor_x += draw_width / 3
        
        GuiTextInput({cursor_x, cursor_y, draw_width / 3, line_height_mid}, &combatState.temp_HP_input)
        cursor_x += draw_width / 3
   
        if rl.GuiButton({cursor_x, cursor_y, draw_width / 3, line_height_mid}, "Resolve") {
            resolve_temp_HP(combatState)
        }
        cursor_x = current_panel_x + PANEL_PADDING
        cursor_y += line_height_mid + PANEL_PADDING

        rl.GuiLabel({cursor_x, cursor_y, draw_width, line_height_mid}, "Conditions")
        cursor_y += line_height_mid + PANEL_PADDING
        
        cursor_x_conditions := cursor_x
        cursor_y_conditions := cursor_y

        defer GuiDropdownControl({cursor_x_conditions, cursor_y_conditions, draw_width / 2, line_height_mid}, &combatState.condition_dropdown)
        defer register_button(&dropdown_btn_list, 3, &dropdown_btn_list_active, &combatState.condition_dropdown.active)
        cursor_x += draw_width / 2

        if rl.GuiButton({cursor_x, cursor_y, draw_width / 2, line_height_mid}, "Apply") {}
        cursor_y += line_height_mid + PANEL_PADDING
        combatState.height_needed_mid = cursor_y - start_y
    }
  
    if (combatState.height_needed_mid > draw_height) {
        rl.EndScissorMode()
    } else {
        combatState.panelMid.scroll.y = 0
    }
    //Stats and info for the currently selected entity.
    current_panel_x += panel_width + dynamic_x_padding
    cursor_x = current_panel_x
    cursor_y = panel_y
        
    rl.GuiPanel(
        {
            cursor_x,
            cursor_y,
            panel_width,
            panel_height,
        },
        "Entity Info")

    rl.DrawRectangle(cast(i32)cursor_x, cast(i32)cursor_y, cast(i32)panel_width, 50, CONFIG.HEADER_COLOUR)
    rl.GuiLabel({cursor_x, cursor_y, panel_width, 50}, "Entity Info")
    cursor_y += 50 
  
    y_offset : f32 = 50
  
    combatState.panelRight.rec = {
        cursor_x,
        cursor_y,
        panel_width,
        panel_height - y_offset,
    }

    line_height : f32 = 50

    if (combatState.stats_lines_needed * line_height > combatState.panelRight.rec.height - y_offset) {
        combatState.panelRight.contentRec.width = panel_width - 14
        combatState.panelRight.contentRec.height = combatState.stats_lines_needed * line_height
        rl.GuiScrollPanel(combatState.panelRight.rec, nil, combatState.panelRight.contentRec, &combatState.panelRight.scroll, &combatState.panelRight.view)
    
        rl.BeginScissorMode(cast(i32)combatState.panelRight.view.x, cast(i32)combatState.panelRight.view.y, cast(i32)combatState.panelRight.view.width, cast(i32)combatState.panelRight.view.height)
        //rl.ClearBackground(CONFIG.PANEL_BACKGROUND_COLOUR)
    } else {
        combatState.panelRight.contentRec.width = panel_width
    }

    if (combatState.current_entity != nil) {
        GuiEntityStats({cursor_x, cursor_y, panel_width, line_height}, combatState.current_entity^, combatState)
    }

    if (combatState.stats_lines_needed * line_height > combatState.panelRight.rec.height - y_offset) {
        rl.EndScissorMode()
      } else {
        combatState.panelRight.scroll.y = 0
      }
}

register_button :: proc(buttons: ^[dynamic]i32, button_index: i32, buttons_active: ^[dynamic]^bool, button_active: ^bool) {
    registered := false

    for button in buttons {
        if (button == button_index) {
            registered = true
        }
    }
    
    if !registered {
        append(buttons, button_index)
        append(buttons_active, button_active)
    }
}

GuiEntityButtonClickable :: proc(rec: rl.Rectangle, entity_list: ^[dynamic]Entity, index: i32) -> (clicked: bool) {
    using state.gui_properties

    x := rec.x
    y := rec.y
    width := rec.width
    height := rec.height

    mouse_pos := rl.GetMousePosition()
    //Draw border
    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, CONFIG.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x+2, cast(i32)y+2, cast(i32)width-4, cast(i32)height-4, CONFIG.BUTTON_COLOUR)

    if rl.CheckCollisionPointRec(mouse_pos, rec) {
        rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, rl.ColorAlpha(CONFIG.BUTTON_HOVER_COLOUR, 0.2))
        
        if rl.IsMouseButtonDown(.LEFT) {
            clicked = true
            return
        }
    }
    
    initial_text_size := TEXT_SIZE_DEFAULT
    
    defer {
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    available_width := (width * 0.7) - ((width * 0.05) + (height * 0.4) + (width * 0.1))
    fit_text(entity_list[index].name, available_width, &TEXT_SIZE)

    rl.GuiLabel({x + (width * 0.05) + (height * 0.4) + (width * 0.1), y + (height * 0.1), available_width, (height * 0.8)}, entity_list[index].name)
    
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size) 

    if rl.GuiButton({x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_UP, "")) {
        if (index > 0) {
            temp_entity := entity_list[index]
            ordered_remove(entity_list, index)
            inject_at(entity_list, index-1, temp_entity)
        }
    }
    
    if rl.GuiButton({x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_DOWN, "")) {
        if (index < cast(i32)len(entity_list^)-1) {
            temp_entity := entity_list[index]
            ordered_remove(entity_list, index)
            inject_at(entity_list, index+1, temp_entity)
        }
    }
    //Initiative label
    rl.GuiLabel({x + (width * 0.05) + (height * 0.4), y + (height * 0.1), (width * 0.1), (height * 0.8)}, int_to_str(entity_list[index].initiative))
    //Health label
    health_label_text: cstring
    if entity_list[index].temp_HP > 0 {
        health_label_text = fmt.ctprintf("%v/%v+%v", entity_list[index].HP, entity_list[index].HP_max, entity_list[index].temp_HP)
    } else {
        health_label_text = fmt.ctprintf("%v/%v", entity_list[index].HP, entity_list[index].HP_max)
    }

    fit_text(health_label_text, (width * 0.18), &TEXT_SIZE)
    rl.GuiLabel({x + (width * 0.8), y + (height * 0.05), (width * 0.18), (height * 0.85)}, cstr(health_label_text))
    //Visibility option 
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, cast(i32)(height * 0.2))
    rl.GuiSetStyle(.CHECKBOX, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_RIGHT)
    rl.GuiCheckBox({x + (width * 0.8), y + (height * 0.75), (height * 0.2), (height * 0.2)}, "visible", &entity_list[index].visible)
    return
}

GuiEntityButton :: proc(rec: rl.Rectangle, entity_list: ^[dynamic]Entity, index: i32) {
    using state.gui_properties

    x := rec.x
    y := rec.y
    width := rec.width
    height := rec.height
    //Draw border
    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, CONFIG.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x+2, cast(i32)y+2, cast(i32)width-4, cast(i32)height-4, CONFIG.BUTTON_COLOUR)
    
    initial_text_size := TEXT_SIZE_DEFAULT
    
    defer {
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    available_width := (width * 0.7) - ((width * 0.05) + (height * 0.4) + (width * 0.1))
    fit_text(entity_list[index].name, available_width, &TEXT_SIZE)

    rl.GuiLabel({x + (width * 0.05) + (height * 0.4) + (width * 0.1), y + (height * 0.1), available_width, (height * 0.8)}, entity_list[index].name)
    
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size) 

    if rl.GuiButton({x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_UP, "")) {
        if (index > 0) {
            temp_entity := entity_list[index]
            ordered_remove(entity_list, index)
            inject_at(entity_list, index-1, temp_entity)
        }
    }
    
    if rl.GuiButton({x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_DOWN, "")) {
        if (index < cast(i32)len(entity_list^)-1) {
            temp_entity := entity_list[index]
            ordered_remove(entity_list, index)
            inject_at(entity_list, index+1, temp_entity)
        }
    }
    //Initiative label
    rl.GuiLabel({x + (width * 0.05) + (height * 0.4), y + (height * 0.1), (width * 0.1), (height * 0.8)}, int_to_str(entity_list[index].initiative))
    //Health label
    health_label_text: cstring
    if entity_list[index].temp_HP > 0 {
        health_label_text = fmt.ctprintf("%v/%v+%v", entity_list[index].HP, entity_list[index].HP_max, entity_list[index].temp_HP)
    } else {
        health_label_text = fmt.ctprintf("%v/%v", entity_list[index].HP, entity_list[index].HP_max)
    }

    fit_text(health_label_text, (width * 0.18), &TEXT_SIZE)
    rl.GuiLabel({x + (width * 0.8), y + (height * 0.05), (width * 0.18), (height * 0.85)}, cstr(health_label_text))
    //Visibility option 
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, cast(i32)(height * 0.2))
    rl.GuiCheckBox({x + (width * 0.8), y + (height * 0.75), (height * 0.2), (height * 0.2)}, "visible", &entity_list[index].visible)
}

dropdownRec: rl.Rectangle
dropdownContentRec: rl.Rectangle
dropdownView: rl.Rectangle
dropdownScroll: rl.Vector2

GuiDropdownControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownState) {
    using state.gui_properties

    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height
    
    initial_text_size := TEXT_SIZE
    initial_scroll_speed := rl.GuiGetStyle(.SCROLLBAR, cast(i32)rl.GuiScrollBarProperty.SCROLL_SPEED)
    
    defer {
        state.gui_properties.TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
    
    border : i32 : 2
    line_height : i32 : 50
    max_items : i32 : 4
    
    mouse_pos := rl.GetMousePosition()
    
    if rl.IsMouseButtonPressed(.LEFT) {
        if (rl.CheckCollisionPointRec(mouse_pos, bounds)) {
            collision := rl.CheckCollisionRecs(dropdownView, bounds)
            if (!collision || !state.hover_consumed) {
                if !dropdown_state.active {
                    for &dropdown_active in dropdown_btn_list_active {
                        dropdown_active^ = false
                    }
                }
                dropdown_state.active = !dropdown_state.active
                if (dropdown_state.active) {
                    dropdownRec = {x, y + height, width, cast(f32)line_height * cast(f32)max_items}
                    dropdownContentRec = {x, y + height, width, 0}
                    dropdownView = {0, 0, 0, 0}
                    dropdownScroll = {0, 0}
                }
                if (!collision && !state.hover_consumed) {
                    state.hover_consumed = !state.hover_consumed
                } else if (!dropdown_state.active) {
                    state.hover_consumed = false
                }
            fmt.println("Dropdown button clicked")
            }
        }
    }
    
    if dropdown_state.active {
        
        if (cast(i32)len(dropdown_state.labels) >= max_items) {
            rl.DrawRectangle(cast(i32)x, cast(i32)(y + height), cast(i32)width, line_height * max_items, CONFIG.BUTTON_BORDER_COLOUR)
            rl.DrawRectangle(cast(i32)x + border, cast(i32)(y + height) + border, cast(i32)width - (border * 2), (line_height * max_items) - (border * 2), CONFIG.DROPDOWN_COLOUR)
        } else {
            rl.DrawRectangle(cast(i32)x, cast(i32)(y + height), cast(i32)width, line_height * cast(i32)len(dropdown_state.labels), CONFIG.BUTTON_BORDER_COLOUR)
            rl.DrawRectangle(cast(i32)x + border, cast(i32)(y + height) + border, cast(i32)width - (border * 2), (line_height * cast(i32)len(dropdown_state.labels)) - (border * 2), CONFIG.DROPDOWN_COLOUR)
        }
        
        if (cast(i32)len(dropdown_state.labels) > max_items) {
            dropdownContentRec.width = width - 14
            dropdownContentRec.height = cast(f32)len(dropdown_state.labels) * cast(f32)line_height
            rl.GuiScrollPanel(dropdownRec, nil, dropdownContentRec, &dropdownScroll, &dropdownView)
            rl.BeginScissorMode(cast(i32)dropdownView.x, cast(i32)dropdownView.y, cast(i32)dropdownView.width, cast(i32)dropdownView.height)
            rl.ClearBackground(CONFIG.DROPDOWN_COLOUR)
        } else {
            dropdownContentRec.width = width
        }
        
        currently_selected := rl.Rectangle{x, y + height + (cast(f32)dropdown_state.selected * cast(f32)line_height) + dropdownScroll.y, dropdownContentRec.width, cast(f32)line_height}
        rl.DrawRectangle(cast(i32)currently_selected.x, cast(i32)currently_selected.y, cast(i32)currently_selected.width, cast(i32)currently_selected.height, rl.ColorAlpha(CONFIG.DROPDOWN_SELECTED_COLOUR, 0.2))
        
        for i in 0..<len(dropdown_state.labels) {
            option_bounds := rl.Rectangle{x, y + height + (cast(f32)i * cast(f32)line_height) + dropdownScroll.y, dropdownContentRec.width, cast(f32)line_height}
            if rl.CheckCollisionPointRec(mouse_pos, option_bounds) {
                rl.DrawRectangle(cast(i32)option_bounds.x, cast(i32)option_bounds.y, cast(i32)option_bounds.width, cast(i32)option_bounds.height, rl.ColorAlpha(CONFIG.DROPDOWN_HOVER_COLOUR, 0.2))
                //Draw highlight colour
                if rl.IsMouseButtonPressed(.LEFT) {
                    dropdown_state.selected = cast(i32)i
                    dropdown_state.active = false
                    state.hover_consumed = false
                }
            }
        }
        
        for label, i in dropdown_state.labels {
            label_string: cstring
            if !fit_text(label, dropdownContentRec.width- (cast(f32)border * 2), &TEXT_SIZE) {
                label_string = crop_text(label, dropdownContentRec.width - (cast(f32)border * 2), TEXT_SIZE)
            } else {
                label_string = label
            }
            rl.GuiLabel({x + (cast(f32)border * 2), y + height + (cast(f32)i * cast(f32)line_height) + dropdownScroll.y, dropdownContentRec.width, cast(f32)line_height}, label_string)
            rl.GuiLine({x, y + height + (cast(f32)i * cast(f32)line_height) + dropdownScroll.y - (cast(f32)border / 2), dropdownContentRec.width, cast(f32)border}, "")
            TEXT_SIZE = initial_text_size
        }

        if (cast(i32)len(dropdown_state.labels) > max_items) {
            rl.EndScissorMode()
        } else {
            dropdownScroll.y = 0
        }
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
    
    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, CONFIG.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x + border, cast(i32)y + border, cast(i32)width - (border * 2), cast(i32)height - (border * 2), CONFIG.BUTTON_COLOUR)

    title_width := getTextWidth(dropdown_state.title, TEXT_SIZE)
    fit_text(dropdown_state.title, width, &TEXT_SIZE)
    rl.GuiLabel({x + (width / 2) - (cast(f32)title_width / 2), y + cast(f32)border, cast(f32)title_width, height - (cast(f32)border * 2)}, dropdown_state.title)
}

GuiDropdownSelectControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownSelectState) {
    using state.gui_properties

    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height

    initial_text_size := TEXT_SIZE

    defer {
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
    
    border : i32 : 2
    line_height : i32 : 50
    max_items : i32 : 4

    mouse_pos := rl.GetMousePosition()
    
    if rl.IsMouseButtonPressed(.LEFT) {
        if rl.CheckCollisionPointRec(mouse_pos, bounds) {
            collision := rl.CheckCollisionRecs(dropdownView, bounds)
            if (!collision || !state.hover_consumed) {
                if !dropdown_state.active {
                    for &dropdown_active in dropdown_btn_list_active {
                        dropdown_active^ = false
                    }
                }
                dropdown_state.active = !dropdown_state.active
                if (dropdown_state.active) {
                    dropdownRec = {x, y + height, width, cast(f32)line_height * cast(f32)max_items}
                    dropdownContentRec = {x, y + height, width, 0}
                    dropdownView = {0, 0, 0, 0}
                    dropdownScroll = {0, 0}
                }
                if (!collision && !state.hover_consumed) {
                    state.hover_consumed = !state.hover_consumed
                } else if (!dropdown_state.active) {
                    state.hover_consumed = false
                }
            }
        }
    }

    if dropdown_state.active {
        rl.DrawRectangle(cast(i32)x, cast(i32)(y + height), cast(i32)width, line_height * max_items, CONFIG.DROPDOWN_COLOUR)
        if (cast(i32)len(dropdown_state.labels) > max_items) {
            dropdownContentRec.width = width - 14
            dropdownContentRec.height = cast(f32)len(dropdown_state.labels) * cast(f32)line_height
            rl.GuiScrollPanel(dropdownRec, nil, dropdownContentRec, &dropdownScroll, &dropdownView)
            rl.BeginScissorMode(cast(i32)dropdownView.x, cast(i32)dropdownView.y, cast(i32)dropdownView.width, cast(i32)dropdownView.height)
        } else {
            dropdownContentRec.width = width
        }
        for label, i in dropdown_state.labels {
            label_string: cstring
            if !fit_text(label, dropdownContentRec.width - (cast(f32)line_height * 0.4) - (cast(f32)border * 2), &TEXT_SIZE) {
                label_string = crop_text(label, dropdownContentRec.width - (cast(f32)line_height * 0.4) - (cast(f32)border * 2), TEXT_SIZE)
            } else {
                label_string = label
            }
            rl.GuiCheckBox({x + cast(f32)border, y + height + (cast(f32)i * cast(f32)line_height) + (cast(f32)line_height * 0.3) + dropdownScroll.y, cast(f32)line_height * 0.4 - cast(f32)border, cast(f32)line_height * 0.4}, label_string, &dropdown_state.selected[i])
            rl.GuiLine({x, y + height + (cast(f32)i * cast(f32)line_height) + dropdownScroll.y, dropdownContentRec.width, cast(f32)border}, "")
            TEXT_SIZE = initial_text_size
        }
        if (cast(i32)len(dropdown_state.labels) > max_items) {
            rl.EndScissorMode()
        } else {
            dropdownScroll.y = 0
        }
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
    
    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, CONFIG.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x + border, cast(i32)y + border, cast(i32)width - (border * 2), cast(i32)height - (border * 2), CONFIG.BUTTON_COLOUR)
    
    title_width := getTextWidth(dropdown_state.title, TEXT_SIZE)
    fit_text(dropdown_state.title, width, &TEXT_SIZE)
    rl.GuiLabel({x + (width / 2) - (cast(f32)title_width / 2), y + cast(f32)border, cast(f32)title_width, height - (cast(f32)border * 2)}, dropdown_state.title)
}

GuiEntityStats :: proc(bounds: rl.Rectangle, entity: Entity, combatState: ^CombatState) {
    using state.gui_properties

    current_panel_x := bounds.x
    panel_y := bounds.y
    panel_width := bounds.width
    line_height := bounds.height

    cursor_x := current_panel_x
    cursor_y := panel_y
    
    cursor_y += combatState.panelRight.scroll.y
    //Display info for selected entity.
    combatState.stats_lines_needed = 0
    rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, entity.name)
    cursor_y += LINE_HEIGHT

    combatState.stats_lines_needed += 1
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, LINE_HEIGHT}, entity.size)
    cursor_x += panel_width / 2
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, LINE_HEIGHT}, entity.race)
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, LINE_HEIGHT}, rl.GuiIconText(.ICON_SHIELD, cstr(entity.AC)))
    cursor_x += panel_width / 2
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 2, LINE_HEIGHT}, rl.GuiIconText(.ICON_HEART, cstr(entity.HP)))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width, line_height}, entity.speed)
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1
    
    fit_text("Stat", panel_width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "Stat")
    cursor_x += panel_width / 4
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    fit_text("Score", panel_width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "Score")
    cursor_x += panel_width / 4
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    fit_text("Modifier", panel_width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "Modifier")
    cursor_x += panel_width / 4
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    fit_text("Save", panel_width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "Save")
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "STR: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.STR))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.STR_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.STR_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "DEX: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.DEX))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.DEX_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.DEX_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "CON: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CON))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CON_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CON_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "INT: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.INT))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.INT_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.INT_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "WIS: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.WIS))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.WIS_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.WIS_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, "CHA: ")
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CHA))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CHA_mod))
    cursor_x += panel_width / 4
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 4, LINE_HEIGHT}, cstr(entity.CHA_save))
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1

    fit_text("Vulnerabilities:", panel_width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, LINE_HEIGHT}, "Vulnerabilities:")
    cursor_x += panel_width / 3
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Resistances:", panel_width / 3, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, line_height}, "Resistances:")
    TEXT_SIZE = TEXT_SIZE_DEFAULT
    fit_text("Immunities:", panel_width / 3, &TEXT_SIZE)
    cursor_x += panel_width / 3
    rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, line_height}, "Immunities:")
    cursor_x = current_panel_x
    cursor_y += LINE_HEIGHT

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    
    vulnerabilities: []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_vulnerabilities)
    resistances : []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_resistances)
    immunities : []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_immunities)

    vulnerability_y, resistance_y, immunity_y: f32
    prev_y := cursor_y

    for vulnerability in vulnerabilities {
      rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, LINE_HEIGHT}, cstr(vulnerability))
      cursor_y += LINE_HEIGHT
    }
    vulnerability_y = cursor_y
    cursor_x += panel_width / 3
    cursor_y = prev_y
    
    for resistance in resistances {
      rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, LINE_HEIGHT}, cstr(resistance))
      cursor_y += LINE_HEIGHT
    }
    resistance_y = cursor_y
    cursor_x += panel_width / 3
    cursor_y = prev_y

    for immunity in immunities {
      rl.GuiLabel({cursor_x, cursor_y, panel_width / 3, LINE_HEIGHT}, cstr(immunity))
      cursor_y += LINE_HEIGHT
    }
    immunity_y = cursor_y
    cursor_x = current_panel_x

    if ((len(resistances) >= len(immunities)) && (len(resistances) >= len(vulnerabilities))) {
      cursor_y = resistance_y
    } else if ((len(immunities) >= len(resistances)) && (len(immunities) >= len(vulnerabilities))) {
      cursor_y = immunity_y
    } else {
      cursor_y = vulnerability_y
    }

    combatState.stats_lines_needed += cast(f32)i32((cursor_y - prev_y) / LINE_HEIGHT)


    rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, "Skills:")
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1
    skills := strings.split(cast(string)entity.skills, ", ")

    for skill in skills {
        rl.GuiLabel({cursor_x, cursor_y, panel_width, LINE_HEIGHT}, cstr(skill))
        cursor_y += LINE_HEIGHT
        combatState.stats_lines_needed += 1
    }
    rl.GuiLabel({cursor_x, cursor_y, panel_width, line_height}, entity.CR)
    cursor_y += LINE_HEIGHT
    combatState.stats_lines_needed += 1
}

resolve_damage :: proc(combatState: ^CombatState) {
    //Function to resolve damage instances and alter entity HP's.
    //Eventually add logging functionality for statistical output.
    //Add calculation for resistances.
    dmg_amount : i32 = str_to_int(string(combatState.dmg_input.text))
    
    for &entity, i in combatState.entities {
        if (combatState.to_dropdown.selected[i]) {
            if combatState.dmg_type_selected not_in entity.dmg_immunities {
            if combatState.dmg_type_selected in entity.dmg_resistances {
                dmg_amount /= 2
            }
                dmg_amount -= entity.temp_HP
                if dmg_amount >= 0 {
                    entity.temp_HP = 0
                    entity.HP -= dmg_amount
                    is_entity_dead(&entity)
                } else {
                    entity.temp_HP = -dmg_amount
                }
            }
        }
        combatState.to_dropdown.selected[i] = false
    }
}

resolve_healing :: proc(combatState: ^CombatState) {
    //Same as dmg function but for healing
    heal_amount : i32 = str_to_int(string(combatState.heal_input.text))
    
    for &entity, i in combatState.entities {
        if (combatState.to_dropdown.selected[i]) {
            entity.HP += heal_amount
            is_entity_over_max(&entity)
        }
        combatState.to_dropdown.selected[i] = false
    }
}

resolve_temp_HP :: proc(combatState: ^CombatState) {
  HP_amount : i32 = str_to_int(string(combatState.temp_HP_input.text))

  for &entity, i in combatState.entities {
    if (combatState.to_dropdown.selected[i]) {
      entity.temp_HP = HP_amount if (HP_amount > entity.temp_HP) else entity.temp_HP
    }
    combatState.to_dropdown.selected[i] = false
  }
}
