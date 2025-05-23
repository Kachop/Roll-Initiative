package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

GuiControl :: struct {
  id: i32,
  hovered: bool,
}

HoverStack :: struct {
  stack: [dynamic]^GuiControl,
  count: i32,
}

hover_stack_add :: proc(guiControl: ^GuiControl) {
  already_added: bool

  if state.hover_stack.count == 0 {
    for item in state.hover_stack.stack {
      if item.id ==  guiControl.id {
        already_added = true
      }
    }
  } else {
    for item, i in state.hover_stack.stack {
      if item.id == guiControl.id {
        ordered_remove(&state.hover_stack.stack, i)
      }
    }
  }
  if !already_added {
    append(&state.hover_stack.stack, guiControl)
    state.hover_stack.count += 1
  }
}

is_current_hover :: proc(guiControl: GuiControl) -> bool {
  if len(state.hover_stack.stack) > 0 {
    if state.hover_stack.stack[len(state.hover_stack.stack)-1].id == guiControl.id {
      return true
    }
  }
  return false
}

clean_hover_stack :: proc() {
  for item, i in state.hover_stack.stack {
    if item.hovered == false {
      ordered_remove(&state.hover_stack.stack, i)
    }
  }
  state.hover_stack.count = 0
}

GuiButtonState :: struct {
  using guiControl: GuiControl,
  text: cstring,
}

InitGuiButtonState :: proc(button_state: ^GuiButtonState, text: cstring) {
  button_state.id = GUI_ID
  GUI_ID += 1
  button_state.text = text
}

GuiButton :: proc{
  GuiButtonWithState,
  GuiButtonStateless,
}

GuiButtonWithState :: proc(bounds: rl.Rectangle, button_state: ^GuiButtonState) -> bool {
  initial_alignment := rl.GuiGetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT)

  border :: 2

  rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
  rl.DrawRectangle(cast(i32)bounds.x + border, cast(i32)bounds.y + border, cast(i32)bounds.width - (border * 2), cast(i32)bounds.height - (border * 2), state.config.BUTTON_COLOUR)
  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
  defer rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)initial_alignment)
  rl.GuiLabel(bounds, button_state.text)

  if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
    button_state.hovered = true
    hover_stack_add(button_state)
  } else {
    button_state.hovered = false
  }
  
  if is_current_hover(button_state) {
    rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, rl.ColorAlpha(state.config.BUTTON_HOVER_COLOUR, 0.2))
    if rl.IsMouseButtonReleased(.LEFT) {
      return true
    }
  }
  return false
}

GuiButtonStateless :: proc(bounds: rl.Rectangle, text: cstring) -> bool {
  initial_alignment := rl.GuiGetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT)

  border :: 2

  rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
  rl.DrawRectangle(cast(i32)bounds.x + border, cast(i32)bounds.y + border, cast(i32)bounds.width - (border * 2), cast(i32)bounds.height - (border * 2), state.config.BUTTON_COLOUR)
  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)
  defer rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)initial_alignment)
  rl.GuiLabel(bounds, text)

  if len(state.hover_stack.stack) == 0 {
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
      rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, rl.ColorAlpha(state.config.BUTTON_HOVER_COLOUR, 0.2))
      if rl.IsMouseButtonReleased(.LEFT) {
        return true
      }
    }
  }
  return false
}

TextInputState :: struct {
  using guiControl: GuiControl,
  edit_mode: bool,
  alloc: [256]rune,
  text: cstring,
}

InitTextInputState :: proc(inputState: ^TextInputState) {
  inputState.id = GUI_ID
  GUI_ID += 1
  inputState.text = fmt.caprint(utf8.runes_to_string(inputState.alloc[:], context.allocator))
}

GuiTextInput :: proc(bounds: rl.Rectangle, inputState: ^TextInputState) {
  if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
    inputState.hovered = true
    hover_stack_add(inputState)
  } else {
    inputState.hovered = false
  }
  
  if (rl.GuiTextBox(bounds, inputState.text, size_of(inputState.alloc), inputState.edit_mode)) {
      if is_current_hover(inputState) && !inputState.edit_mode {
        inputState.edit_mode = true
      } else if inputState.edit_mode {
        inputState.edit_mode = false
      }
    }
  }

EntityButtonState :: struct {
  using guiControl: GuiControl,
  entity_list: ^[dynamic]Entity,
  index: i32
}

InitEntityButtonState :: proc(button_state: ^EntityButtonState, entity_list: ^[dynamic]Entity, index: i32) {
  button_state.id = GUI_ID
  GUI_ID += 1
  button_state.entity_list = entity_list
  button_state.index = index
}

GuiEntityButtonClickable :: proc(rec: rl.Rectangle, button_state: ^EntityButtonState) -> (clicked: bool) {
      using state.gui_properties
      rl.GuiSetIconScale(1)
      defer rl.GuiSetIconScale(2)

      x := rec.x
      y := rec.y
      width := rec.width
      height := rec.height

      mouse_pos := rl.GetMousePosition()
      //Draw border
      rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, state.config.BUTTON_BORDER_COLOUR)
      rl.DrawRectangle(cast(i32)x+2, cast(i32)y+2, cast(i32)width-4, cast(i32)height-4, state.config.BUTTON_COLOUR)
      
      if is_current_hover(button_state) {
          rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, rl.ColorAlpha(state.config.BUTTON_HOVER_COLOUR, 0.2))
          
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
      fit_text(button_state.entity_list[button_state.index].alias, available_width, &TEXT_SIZE)

      rl.GuiLabel({x + (width * 0.05) + (height * 0.4) + (width * 0.1), y + (height * 0.1), available_width, (height * 0.8)}, button_state.entity_list[button_state.index].alias)
      
      TEXT_SIZE = initial_text_size
      rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size)

      if rl.CheckCollisionPointRec(mouse_pos, rec) {
        button_state.hovered = true
        hover_stack_add(button_state)
      } else {
        button_state.hovered = false
      }

      if rl.GuiButton({x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_UP, "")) {
        if is_current_hover(button_state) {
          if (button_state.index > 0) {
              temp_entity := button_state.entity_list[button_state.index]
              ordered_remove(button_state.entity_list, button_state.index)
              inject_at(button_state.entity_list, button_state.index-1, temp_entity)
          }
        }
      }
      
      if rl.GuiButton({x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_DOWN, "")) {
        if is_current_hover(button_state) {
          if (button_state.index < cast(i32)len(button_state.entity_list^)-1) {
              temp_entity := button_state.entity_list[button_state.index]
              ordered_remove(button_state.entity_list, button_state.index)
              inject_at(button_state.entity_list, button_state.index+1, temp_entity)
          }
        }
      }
      //Initiative label
      rl.GuiLabel({x + (width * 0.05) + (height * 0.4), y + (height * 0.1), (width * 0.1), (height * 0.8)}, cstr(button_state.entity_list[button_state.index].initiative))
      //Health label
      health_label_text: cstring
      if button_state.entity_list[button_state.index].temp_HP > 0 {
          health_label_text = fmt.ctprintf("%v/%v+%v", button_state.entity_list[button_state.index].HP, button_state.entity_list[button_state.index].HP_max, button_state.entity_list[button_state.index].temp_HP)
      } else {
          health_label_text = fmt.ctprintf("%v/%v", button_state.entity_list[button_state.index].HP, button_state.entity_list[button_state.index].HP_max)
      }

      fit_text(health_label_text, (width * 0.18), &TEXT_SIZE)
      rl.GuiLabel({x + (width * 0.8), y + (height * 0.05), (width * 0.18), (height * 0.85)}, cstr(health_label_text))
      //Visibility option 
      rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, cast(i32)(height * 0.2))
      rl.GuiSetStyle(.CHECKBOX, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_RIGHT)
      rl.GuiCheckBox({x + (width * 0.8), y + (height * 0.75), (height * 0.2), (height * 0.2)}, "visible", &button_state.entity_list[button_state.index].visible)
      return
  }

GuiEntityButton :: proc(rec: rl.Rectangle, button_state: ^EntityButtonState) {
    using state.gui_properties
    rl.GuiSetIconScale(1)
    defer rl.GuiSetIconScale(2)

    x := rec.x
    y := rec.y
    width := rec.width
    height := rec.height
    //Draw border
    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, state.config.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x+2, cast(i32)y+2, cast(i32)width-4, cast(i32)height-4, state.config.BUTTON_COLOUR)
    
    initial_text_size := TEXT_SIZE_DEFAULT
    
    defer {
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    available_width := (width * 0.7) - ((width * 0.05) + (height * 0.4) + (width * 0.1))
    fit_text(button_state.entity_list[button_state.index].alias, available_width, &TEXT_SIZE)

    rl.GuiLabel({x + (width * 0.05) + (height * 0.4) + (width * 0.1), y + (height * 0.1), available_width, (height * 0.8)}, button_state.entity_list[button_state.index].alias)
    
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size)
    
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), rec) {
      button_state.hovered = true
      hover_stack_add(button_state)
    } else {
      button_state.hovered = false
    }

    if rl.GuiButton({x + (height * 0.1), y + (height * 0.1), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_UP, "")) {
      if is_current_hover(button_state) {
        if (button_state.index > 0) {
            temp_entity := button_state.entity_list[button_state.index]
            ordered_remove(button_state.entity_list, button_state.index)
            inject_at(button_state.entity_list, button_state.index-1, temp_entity)
        }
      }
    }
    
    if rl.GuiButton({x + (height * 0.1), y + (height * 0.55), (height * 0.35), (height * 0.35)}, rl.GuiIconText(.ICON_ARROW_DOWN, "")) {
      if is_current_hover(button_state) {
        if (button_state.index < cast(i32)len(button_state.entity_list^)-1) {
            temp_entity := button_state.entity_list[button_state.index]
            ordered_remove(button_state.entity_list, button_state.index)
            inject_at(button_state.entity_list, button_state.index+1, temp_entity)
        }
      }
    }
    //Initiative label
    rl.GuiLabel({x + (width * 0.05) + (height * 0.4), y + (height * 0.1), (width * 0.1), (height * 0.8)}, cstr(button_state.entity_list[button_state.index].initiative))
    //Health label
    health_label_text: cstring
    if button_state.entity_list[button_state.index].temp_HP > 0 {
        health_label_text = fmt.ctprintf("%v/%v+%v", button_state.entity_list[button_state.index].HP, button_state.entity_list[button_state.index].HP_max, button_state.entity_list[button_state.index].temp_HP)
    } else {
        health_label_text = fmt.ctprintf("%v/%v", button_state.entity_list[button_state.index].HP, button_state.entity_list[button_state.index].HP_max)
    }

    fit_text(health_label_text, (width * 0.18), &TEXT_SIZE)
    rl.GuiLabel({x + (width * 0.8), y + (height * 0.05), (width * 0.18), (height * 0.85)}, cstr(health_label_text))
    //Visibility option 
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, cast(i32)(height * 0.2))
    rl.GuiCheckBox({x + (width * 0.8), y + (height * 0.75), (height * 0.2), (height * 0.2)}, "visible", &button_state.entity_list[button_state.index].visible)
}

DropdownState :: struct {
  using guiControl: GuiControl,
  title: cstring,
  labels: []cstring,
  selected: i32,
  active: bool,
  btn_list: ^map[i32]^bool,
}

InitDropdownState :: proc(state: ^DropdownState, title: cstring, labels: []cstring, btn_list: ^map[i32]^bool) {
  initial_allocator := context.allocator
  context.allocator = static_alloc
  state.id = GUI_ID
  GUI_ID += 1
  state.title = title
  state.labels = labels
  state.btn_list = btn_list
  context.allocator = initial_allocator
}

@(deferred_in=_draw_dropdown)
GuiDropdownControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownState) {
    using state.gui_properties

    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height

    cursor_x : f32 = x
    cursor_y : f32 = y
    
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

    if rl.CheckCollisionPointRec(mouse_pos, bounds) {
        dropdown_state.hovered = true
        hover_stack_add(dropdown_state)
    } else {
        dropdown_state.hovered = false
    }

    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, state.config.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x + border, cast(i32)y + border, cast(i32)width - (border * 2), cast(i32)height - (border * 2), state.config.BUTTON_COLOUR)
    if is_current_hover(dropdown_state) {
        rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, rl.ColorAlpha(state.config.BUTTON_HOVER_COLOUR, 0.2))
    }

    title_width := getTextWidth(dropdown_state.title, TEXT_SIZE)
    fit_text(dropdown_state.title, width, &TEXT_SIZE)
    rl.GuiLabel({x + (width / 2) - (cast(f32)title_width / 2), y + cast(f32)border, cast(f32)title_width, height - (cast(f32)border * 2)}, dropdown_state.title) 
}

_draw_dropdown :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownState) {
    using state.gui_properties

    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height

    cursor_x : f32 = x
    cursor_y : f32 = y

    border : i32 : 2
    line_height : i32 : 50
    max_items : i32 : 4

    mouse_pos := rl.GetMousePosition()

    dropdown_height : f32 = cast(f32)(max_items * line_height) if (cast(i32)len(dropdown_state.labels) >= max_items) else cast(f32)(cast(i32)len(dropdown_state.labels) * line_height)

    if y <= (state.window_height / 2) {
        cursor_y += cast(f32)line_height
    } else {
        cursor_y -= dropdown_height
    }

    if rl.CheckCollisionPointRec(mouse_pos, bounds if (!dropdown_state.active) else rl.Rectangle{bounds.x, cursor_y, bounds.width, bounds.height + dropdown_height}) {
        dropdown_state.hovered = true
        hover_stack_add(dropdown_state)
    } else {
        dropdown_state.hovered = false
    }
 
    if is_current_hover(dropdown_state) {
        if rl.CheckCollisionPointRec(mouse_pos, bounds) {
            if rl.IsMouseButtonReleased(.LEFT) {
                if !dropdown_state.active {
                    for _, dropdown_active in dropdown_state.btn_list {
                        dropdown_active^ = false
                    }
                    dropdown_state.active = true
                } else {
                    dropdown_state.active = false
                }
                if (dropdown_state.active) {
                    dropdownRec = {x, cursor_y, width, cast(f32)line_height * cast(f32)max_items}
                    dropdownContentRec = {x, cursor_y, width, 0}
                    dropdownView = {0, 0, 0, 0}
                    dropdownScroll = {0, 0}
                }
            }
        }
    }
 
    if dropdown_state.active {
        rl.DrawRectangle(cast(i32)x, cast(i32)cursor_y, cast(i32)width, cast(i32)dropdown_height, state.config.BUTTON_BORDER_COLOUR)
        rl.DrawRectangle(cast(i32)x + border, cast(i32)cursor_y + border, cast(i32)width - (border * 2), cast(i32)dropdown_height - (border * 2), state.config.DROPDOWN_COLOUR)
        
        if (cast(i32)len(dropdown_state.labels) > max_items) {
            dropdownContentRec.width = width - 14
            dropdownContentRec.height = cast(f32)len(dropdown_state.labels) * cast(f32)line_height
            rl.GuiScrollPanel(dropdownRec, nil, dropdownContentRec, &dropdownScroll, &dropdownView)
            rl.BeginScissorMode(cast(i32)dropdownView.x, cast(i32)dropdownView.y, cast(i32)dropdownView.width, cast(i32)dropdownView.height)
            rl.ClearBackground(state.config.DROPDOWN_COLOUR)
        } else {
            dropdownContentRec.width = width
        }
    
        cursor_y += dropdownScroll.y
        selected_cursor_y := cursor_y + (cast(f32)dropdown_state.selected * cast(f32)line_height)
        
        currently_selected := rl.Rectangle{x, selected_cursor_y, dropdownContentRec.width, cast(f32)line_height}
        rl.DrawRectangle(cast(i32)currently_selected.x, cast(i32)currently_selected.y, cast(i32)currently_selected.width, cast(i32)currently_selected.height, rl.ColorAlpha(state.config.DROPDOWN_SELECTED_COLOUR, 0.2))
        
        for label, i in dropdown_state.labels {
            option_bounds := rl.Rectangle{x, cursor_y, dropdownContentRec.width, cast(f32)line_height}

            label_string: cstring
            if !fit_text(label, option_bounds.width - (cast(f32)border * 2), &TEXT_SIZE) {
                label_string = crop_text(label, option_bounds.width - (cast(f32)border * 2), TEXT_SIZE)
            } else {
                label_string = label
            }

            rl.GuiLabel({option_bounds.x + (cast(f32)border * 2), option_bounds.y, option_bounds.width, cast(f32)line_height}, label_string)
            rl.GuiLine({option_bounds.x, option_bounds.y, option_bounds.width, cast(f32)border}, "")
            
            if rl.CheckCollisionPointRec(mouse_pos, option_bounds) {
                rl.DrawRectangle(cast(i32)option_bounds.x, cast(i32)option_bounds.y, cast(i32)option_bounds.width, cast(i32)option_bounds.height, rl.ColorAlpha(state.config.DROPDOWN_HOVER_COLOUR, 0.2))
                //Draw highlight colour
                if rl.IsMouseButtonReleased(.LEFT) {
                    dropdown_state.selected = cast(i32)i
                    dropdown_state.active = false
                    state.hover_consumed = false
                }
            }
            cursor_y += cast(f32)line_height
        }

        if (cast(i32)len(dropdown_state.labels) > max_items) {
            rl.EndScissorMode()
        } else {
            dropdownScroll.y = 0
        }
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
}


DropdownSelectState :: struct {
  using guiControl: GuiControl,
  title: cstring,
  labels: []cstring,
  selected: [dynamic]bool,
  active: bool,
  btn_list: ^map[i32]^bool,
}

InitDropdownSelectState :: proc(dropdownState: ^DropdownSelectState, title: cstring, labels: []cstring, btn_list: ^map[i32]^bool) {
  initial_allocator := context.allocator
  context.allocator = static_alloc
  dropdownState.id = GUI_ID
  GUI_ID += 1
  dropdownState.title = title
  dropdownState.labels = labels

  for _ in dropdownState.labels {
    append(&dropdownState.selected, false)
  }
  dropdownState.btn_list = btn_list
  context.allocator = initial_allocator
}

DeInitDropdownSelectState :: proc(dropdownState: ^DropdownSelectState) {
  delete(dropdownState.labels)
}

@(deferred_in=_draw_dropdown_select)
GuiDropdownSelectControl :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownSelectState) {
    using state.gui_properties
    initial_allocator := context.allocator
    context.allocator = static_alloc

    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height

    cursor_x : f32 = x
    cursor_y : f32 = y

    initial_text_size := TEXT_SIZE

    defer {
        TEXT_SIZE = initial_text_size
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }
    
    border : i32 : 2
    line_height : i32 : 50
    max_items : i32 : 4

    mouse_pos := rl.GetMousePosition()
    if !dropdown_state.active {
        if rl.CheckCollisionPointRec(mouse_pos, bounds) {
            dropdown_state.hovered = true
            hover_stack_add(dropdown_state)
        } else {
            dropdown_state.hovered = false
        }
    }

    rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, state.config.BUTTON_BORDER_COLOUR)
    rl.DrawRectangle(cast(i32)x + border, cast(i32)y + border, cast(i32)width - (border * 2), cast(i32)height - (border * 2), state.config.BUTTON_COLOUR)
    if is_current_hover(dropdown_state) {
        rl.DrawRectangle(cast(i32)x, cast(i32)y, cast(i32)width, cast(i32)height, rl.ColorAlpha(state.config.BUTTON_HOVER_COLOUR, 0.2))
    }
    
    title_width := getTextWidth(dropdown_state.title, TEXT_SIZE)
    fit_text(dropdown_state.title, width, &TEXT_SIZE)
    rl.GuiLabel({x + (width / 2) - (cast(f32)title_width / 2), y + cast(f32)border, cast(f32)title_width, height - (cast(f32)border * 2)}, dropdown_state.title)
  context.allocator = initial_allocator
}

_draw_dropdown_select :: proc(bounds: rl.Rectangle, dropdown_state: ^DropdownSelectState) {
    using state.gui_properties
    initial_allocator := context.allocator
    context.allocator = static_alloc
    x := bounds.x
    y := bounds.y
    width := bounds.width
    height := bounds.height

    cursor_x : f32 = x
    cursor_y : f32 = y

    initial_text_size := TEXT_SIZE

    border : i32 : 2
    line_height : i32 : 50
    max_items : i32 : 4

    mouse_pos := rl.GetMousePosition()

    dropdown_height : f32 = cast(f32)(max_items * line_height) if (cast(i32)len(dropdown_state.labels) >= max_items) else cast(f32)(cast(i32)len(dropdown_state.labels) * line_height)

    if y <= (state.window_height / 2) {
        cursor_y += cast(f32)line_height
    } else {
        cursor_y -= dropdown_height
    }

    if dropdown_state.active {
        if rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle{bounds.x, cursor_y if (y > (state.window_height / 2)) else bounds.y, bounds.width, bounds.height + dropdown_height}) {
            dropdown_state.hovered = true
            hover_stack_add(dropdown_state)
        } else {
            dropdown_state.hovered = false
        }

        rl.DrawRectangle(cast(i32)x, cast(i32)cursor_y, cast(i32)width, cast(i32)dropdown_height, state.config.BUTTON_BORDER_COLOUR)
        rl.DrawRectangle(cast(i32)x + border, cast(i32)cursor_y + border, cast(i32)width - (border * 2), cast(i32)dropdown_height - (border * 2), state.config.DROPDOWN_COLOUR)
        dropdownRec = {x, cursor_y, width, dropdown_height}
        

        cursor_y += dropdownScroll.y

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
            rl.GuiCheckBox({x + cast(f32)border, cursor_y + (cast(f32)line_height * 0.3), cast(f32)line_height * 0.4 - cast(f32)border, cast(f32)line_height * 0.4}, label_string, &dropdown_state.selected[i])
            rl.GuiLine({x, cursor_y + (cast(f32)line_height), dropdownContentRec.width, cast(f32)border}, "")
            TEXT_SIZE = initial_text_size
            cursor_y += cast(f32)line_height
        }

        if (cast(i32)len(dropdown_state.labels) > max_items) {
            rl.EndScissorMode()
        } else {
            dropdownScroll.y = 0
        }
        rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    }

    if is_current_hover(dropdown_state) {
        if rl.CheckCollisionPointRec(mouse_pos, bounds) {
            if rl.IsMouseButtonReleased(.LEFT) {
                if !dropdown_state.active {
                    for _, dropdown_active in dropdown_state.btn_list {
                        dropdown_active^ = false
                    }
                    dropdown_state.active = true
                } else {
                    dropdown_state.active = false
                    return
                }
                if (dropdown_state.active) {
                    dropdownContentRec = {x, cursor_y, width, 0}
                    dropdownView = {0, 0, 0, 0}
                    dropdownScroll = {0, 0}
                    return
                }
            }
        }
    }
  context.allocator = initial_allocator
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

TabControlState :: struct {
  using guiControl: GuiControl,
  options: []cstring,
  selected: i32,
}

InitTabControlState :: proc(tab_state: ^TabControlState, options: []cstring) {
  tab_state.id = GUI_ID
  GUI_ID += 1
  tab_state.options = options
}

GuiTabControl :: proc(bounds: rl.Rectangle, tabState: ^TabControlState) -> i32 {
  cursor_x := bounds.x
  cursor_y := bounds.y

  button_width := bounds.width / cast(f32)len(tabState.options) + 1

  tab_bounds: [dynamic]rl.Rectangle
  defer delete(tab_bounds)

  for _, i in tabState.options {
    switch i {
    case 0:
      if cast(i32)i == tabState.selected {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y-5, button_width+5, state.gui_properties.LINE_HEIGHT+5})
      } else {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y, button_width, state.gui_properties.LINE_HEIGHT})
      }
    case 1 ..< len(tabState.options)-1:
      if cast(i32)i == tabState.selected {
        append(&tab_bounds, rl.Rectangle{cursor_x-5, cursor_y-5, button_width+10, state.gui_properties.LINE_HEIGHT+5})
      } else {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y, button_width, state.gui_properties.LINE_HEIGHT})
      }
    case len(tabState.options)-1:
      if cast(i32)i == tabState.selected {
        append(&tab_bounds, rl.Rectangle{cursor_x-5, cursor_y-5, button_width+5, state.gui_properties.LINE_HEIGHT+5})
      } else {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y, button_width, state.gui_properties.LINE_HEIGHT})
      }
    }
    cursor_x += button_width - (cast(f32)len(tabState.options) / (cast(f32)len(tabState.options) - 1))
  }
  
  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)

  for bounds, i in tab_bounds {
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
      tabState.hovered = true
      hover_stack_add(tabState)
    } else {
      tabState.hovered = false
    }

    defer if cast(i32)i == tabState.selected {
      rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
      rl.DrawRectangle(cast(i32)bounds.x+5, cast(i32)bounds.y+5, cast(i32)bounds.width-10, cast(i32)bounds.height-10, state.config.BUTTON_COLOUR)
      rl.GuiLabel(bounds, tabState.options[i])
    }

    if cast(i32)i != tabState.selected {
      rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
      rl.DrawRectangle(cast(i32)bounds.x+5, cast(i32)bounds.y+5, cast(i32)bounds.width-10, cast(i32)bounds.height-10, state.config.BUTTON_COLOUR)
      rl.GuiLabel(bounds, tabState.options[i])
      
      if is_current_hover(tabState) {
        if rl.IsMouseButtonPressed(.LEFT) {
          if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
            tabState.selected = cast(i32)i 
          }
        }
      }
    }
  }

  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

  return tabState.selected
}

GuiMessageBoxState :: struct {
  using guiControl: GuiControl,
  title: cstring,
  message: cstring,
}

init_message_box :: proc(message_box_state: ^GuiMessageBoxState, title: cstring, message: cstring) {
  message_box_state.id = GUI_ID
  GUI_ID += 1
  
  message_box_state.title = title
  message_box_state.message = message
}

GuiMessageBox :: proc(bounds: rl.Rectangle, message_box_state: ^GuiMessageBoxState) -> i32 {
  initial_text_size := state.gui_properties.TEXT_SIZE
  defer rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, initial_text_size)

  if rl.CheckCollisionPointRec(rl.GetMousePosition(), bounds) {
    message_box_state.hovered = true
    hover_stack_add(message_box_state)
  } else {
    message_box_state.hovered = false
  }

  state.gui_properties.TEXT_SIZE = state.gui_properties.TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, state.gui_properties.TEXT_SIZE)

  output := rl.GuiMessageBox(bounds, message_box_state.title, message_box_state.message, "Close")

  if is_current_hover(message_box_state) {
    return output
  } else {
    return -1
  }
}

GuiMessageBoxQueueState :: struct {
  messages: [dynamic]GuiMessageBoxState
}

addMessage :: proc(message_queue: ^GuiMessageBoxQueueState, message_box: GuiMessageBoxState) {
  append(&message_queue.messages, message_box)
}

remove_message :: proc(message_queue: ^GuiMessageBoxQueueState, message_box: ^GuiMessageBoxState) {
  for test_message_box, i in message_queue.messages {
    if test_message_box.id == message_box.id {
      ordered_remove(&message_queue.messages, i)
      message_box.hovered = false
    }
  }
}

GuiMessageBoxQueue :: proc(message_queue_state: ^GuiMessageBoxQueueState) {
  cursor_x : f32 = state.window_width - 350
  cursor_y : f32 = 50

  message_loop: for &message_box, i in message_queue_state.messages {
    if GuiMessageBox({cursor_x, cursor_y, 300, 100}, &message_box) != -1 {
      remove_message(message_queue_state, &message_box)
    }
    cursor_y += 110

    if i >= 4 {
      break message_loop
    }
  }
}

GuiEntityStats :: proc(bounds: rl.Rectangle, entity: ^Entity, initiative: ^TextInputState=nil) {
  using state.gui_properties

  if entity != nil {
    cursor_x := bounds.x
    cursor_y := bounds.y

    start_x := bounds.x

    defer state.cursor_x = cursor_x
    defer state.cursor_y = cursor_y

    width := bounds.width
    height := bounds.height

    initial_text_size := TEXT_SIZE

    //Display info for selected entity.
    rl.GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.alias)
    cursor_y += LINE_HEIGHT

    if initiative != nil {
      rl.GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, "Initiative: ")
      cursor_x += width / 2

      GuiTextInput({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, initiative)
      entity.initiative = to_i32(initiative.text)
      cursor_x = start_x
      cursor_y += LINE_HEIGHT
    }

    rl.GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, entity.size)
    cursor_x += width / 2
    rl.GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, entity.race)
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, rl.GuiIconText(.ICON_SHIELD, cstr(entity.AC)))
    cursor_x += width / 2
    rl.GuiLabel({cursor_x, cursor_y, width / 2, LINE_HEIGHT}, rl.GuiIconText(.ICON_HEART, cstr(entity.HP)))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.speed)
    cursor_y += LINE_HEIGHT
    
    fit_text("Stat", width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Stat")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += width / 4
    fit_text("Score", width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Score")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += width / 4
    fit_text("Modifier", width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Modifier")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x += width / 4
    fit_text("Save", width / 4, &TEXT_SIZE)
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "Save")
    TEXT_SIZE = initial_text_size
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "STR: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.STR))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.STR_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.STR_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "DEX: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.DEX))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.DEX_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.DEX_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "CON: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CON))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CON_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CON_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "INT: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.INT))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.INT_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.INT_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "WIS: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.WIS))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.WIS_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.WIS_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, "CHA: ")
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CHA))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.CHA_mod))
    cursor_x += width / 4
    rl.GuiLabel({cursor_x, cursor_y, width / 4, LINE_HEIGHT}, cstr(entity.STR_save))
    cursor_x = start_x
    cursor_y += LINE_HEIGHT

    vulnerabilities : []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_vulnerabilities)
    resistances : []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_resistances)
    immunities : []string = gen_vulnerability_resistance_or_immunity_string(entity.dmg_immunities)
    
    if len(vulnerabilities) > 0 {
      fit_text("Vulnerabilities:", width / 3, &TEXT_SIZE)
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Vulnerabilities:")
      cursor_x += width / 3
      TEXT_SIZE = TEXT_SIZE_DEFAULT
    }
    if len(resistances) > 0 {
      fit_text("Resistances:", width / 3, &TEXT_SIZE)
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Resistances:")
      cursor_x += width / 3
      TEXT_SIZE = TEXT_SIZE_DEFAULT
    }
    if len(immunities) > 0 {
      fit_text("Immunities:", width / 3, &TEXT_SIZE)
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, "Immunities:")
      cursor_x = start_x
      cursor_y += LINE_HEIGHT
    }

    TEXT_SIZE = TEXT_SIZE_DEFAULT
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)

    vulnerability_y, resistance_y, immunity_y: f32
    prev_y := cursor_y

    for vulnerability in vulnerabilities {
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(vulnerability))
      cursor_y += LINE_HEIGHT
    }
    vulnerability_y = cursor_y
    if len(vulnerabilities) > 0 {
      cursor_x += width / 3
      cursor_y = prev_y
    }
    
    for resistance in resistances {
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(resistance))
      cursor_y += LINE_HEIGHT
    }
    resistance_y = cursor_y
    if len(resistances) > 0 {
      cursor_x += width / 3
      cursor_y = prev_y
    }

    for immunity in immunities {
      rl.GuiLabel({cursor_x, cursor_y, width / 3, LINE_HEIGHT}, cstr(immunity))
      cursor_y += LINE_HEIGHT
    }
    immunity_y = cursor_y
    if len(immunities) > 0 {
      cursor_x = start_x
    }
    
    if ((len(resistances) >= len(immunities)) && (len(resistances) >= len(vulnerabilities))) {
      cursor_y = resistance_y
    } else if ((len(immunities) >= len(resistances)) && (len(immunities) >= len(vulnerabilities))) {
      cursor_y = immunity_y
    } else {
      cursor_y = vulnerability_y
    }

    if entity.skills != "" {
      rl.GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, "Skills:")
      cursor_y += LINE_HEIGHT
      skills := strings.split(cast(string)entity.skills, ", ")
      for skill in skills {
        rl.GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, cstr(skill))
        cursor_y += LINE_HEIGHT
      }
    }
    rl.GuiLabel({cursor_x, cursor_y, width, LINE_HEIGHT}, entity.CR)
    cursor_y += LINE_HEIGHT
/*
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_WORD)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_TOP)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_LINE_SPACING, 25)
    //Some sort of tab control for displaying stuff
    text_size := rl.GuiGetStyle(.TEXTBOX, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE)
    text_spacing := rl.GuiGetStyle(.TEXTBOX, cast(i32)rl.GuiDefaultProperty.TEXT_SPACING)
    padding := rl.GuiGetStyle(.TEXTBOX, cast(i32)rl.GuiControlProperty.TEXT_PADDING)

    //log.infof("Text padding: %v", padding)
    
    font_size: i32 = 25
    rl.GuiSetStyle(.TEXTBOX, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, font_size)

    switch GuiTabControl({cursor_x, cursor_y, width, LINE_HEIGHT}, &state.entity_stats_tab_state) {
    case 0: //Traits
      if entity.traits != "" {
        cursor_y += LINE_HEIGHT

        lines_needed := getTextLinesNeeded(entity.traits, width - (cast(f32)padding * 2), font_size)

        rl.GuiTextBox({cursor_x, cursor_y, width, cast(f32)lines_needed * 28}, entity.traits, font_size, false)
        cursor_y += cast(f32)lines_needed * 28
      }
    case 1: //Actions
      if entity.actions != "" {
        cursor_y += LINE_HEIGHT

        lines_needed := getTextLinesNeeded(entity.actions, width - (cast(f32)padding * 2), font_size)

        rl.GuiTextBox({cursor_x, cursor_y, width, cast(f32)lines_needed * 25}, entity.actions, font_size, false)
        cursor_y += cast(f32)lines_needed * 25
      }
    case 2: //Legendary actions
      if entity.legendary_actions != "" {
        cursor_y += LINE_HEIGHT

        lines_needed := getTextLinesNeeded(entity.legendary_actions, width - (cast(f32)padding * 2), font_size)

        rl.GuiTextBox({cursor_x, cursor_y, width, cast(f32)lines_needed * 25}, entity.legendary_actions, font_size, false)
        cursor_y += cast(f32)lines_needed * 25
      }
    }
*/
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_WRAP_MODE, cast(i32)rl.GuiTextWrapMode.TEXT_WRAP_NONE)
    rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_ALIGNMENT_VERTICAL, cast(i32)rl.GuiTextAlignmentVertical.TEXT_ALIGN_MIDDLE)
  }
}
