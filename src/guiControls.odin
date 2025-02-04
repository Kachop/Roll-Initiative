package main

import "core:fmt"
import rl "vendor:raylib"

TabControlState :: struct {
  options: []cstring,
  selected: i32,
}

InitTabControlState :: proc(tab_state: ^TabControlState, options: []cstring) {
  tab_state.options = options
}

GuiTabControl :: proc(bounds: rl.Rectangle, tabState: ^TabControlState) -> i32 {
  cursor_x := bounds.x
  cursor_y := bounds.y
  selected_x := 0
  selected_y := 0

  button_width := bounds.width / cast(f32)len(tabState.options)

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
      cursor_x += button_width
    case 1..<len(tabState.options)-1:
      if cast(i32)i == tabState.selected {
        append(&tab_bounds, rl.Rectangle{cursor_x-5, cursor_y-5, button_width+10, state.gui_properties.LINE_HEIGHT+5})
      } else {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y, button_width, state.gui_properties.LINE_HEIGHT})
      }
      cursor_x += button_width
    case len(tabState.options)-1:
      if cast(i32)i == tabState.selected {
        append(&tab_bounds, rl.Rectangle{cursor_x-5, cursor_y-5, button_width+5, state.gui_properties.LINE_HEIGHT+5})
      } else {
        append(&tab_bounds, rl.Rectangle{cursor_x, cursor_y, button_width, state.gui_properties.LINE_HEIGHT})
      }
      cursor_x += button_width
    }
  }
  
  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_CENTER)

  for bounds, i in tab_bounds {
    defer if cast(i32)i == tabState.selected {
      rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
      rl.DrawRectangle(cast(i32)bounds.x+5, cast(i32)bounds.y+5, cast(i32)bounds.width-10, cast(i32)bounds.height-10, state.config.BUTTON_COLOUR)
      rl.GuiLabel(bounds, tabState.options[i])
    }

    if cast(i32)i != tabState.selected {
      rl.DrawRectangle(cast(i32)bounds.x, cast(i32)bounds.y, cast(i32)bounds.width, cast(i32)bounds.height, state.config.BUTTON_BORDER_COLOUR)
      rl.DrawRectangle(cast(i32)bounds.x+5, cast(i32)bounds.y+5, cast(i32)bounds.width-10, cast(i32)bounds.height-10, state.config.BUTTON_COLOUR)
      rl.GuiLabel(bounds, tabState.options[i])

      if rl.IsMouseButtonPressed(.LEFT) {
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), {bounds.x, bounds.y, bounds.width, bounds.height}) {
          tabState.selected = cast(i32)i 
        }
      }
    }
  }

  rl.GuiSetStyle(.LABEL, cast(i32)rl.GuiControlProperty.TEXT_ALIGNMENT, cast(i32)rl.GuiTextAlignment.TEXT_ALIGN_LEFT)

  return tabState.selected
}
