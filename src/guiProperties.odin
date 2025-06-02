package main

import rl "vendor:raylib"

GuiProperties :: struct {
  LINE_HEIGHT         : f32,
  PADDING_TOP         : f32,
  PADDING_LEFT        : f32,
  PADDING_RIGHT       : f32,
  PADDING_BOTTOM      : f32,
  PADDING_ICONS       : f32,
  TITLE_BUTTON_WIDTH  : f32,
  TITLE_BUTTON_HEIGHT : f32,
  TITLE_BUTTON_PADDING: f32,
  MENU_BUTTON_WIDTH   : f32,
  MENU_BUTTON_HEIGHT  : f32,
  MENU_BUTTON_PADDING : f32,
  NAVBAR_SIZE         : f32,
  NAVBAR_PADDING      : f32,
  PANEL_PADDING       : f32,
  ICON_SIZE           : f32,
  FONT                : rl.Font,
  TEXT_SIZE_TITLE     : i32,
  TEXT_SIZE_DEFAULT   : i32,
  TEXT_SIZE           : i32,
  TEXT_INPUT_WIDTH    : f32,
  TEXT_INPUT_HEIGHT   : f32,
  LINE_WIDTH          : f32,

  
  BACKGROUND_COLOUR       : rl.Color,
  PANEL_BACKGROUND_COLOUR : rl.Color,
  HEADER_COLOUR           : rl.Color,

  BUTTON_BORDER_COLOUR    : rl.Color,
  BUTTON_COLOUR           : rl.Color,
  BUTTON_HOVER_COLOUR     : rl.Color,
  BUTTON_ACTIVE_COLOUR    : rl.Color,

  DROPDOWN_COLOUR         : rl.Color,
  DROPDOWN_SELECTED_COLOUR: rl.Color,
  DROPDOWN_HOVER_COLOUR   : rl.Color,
}

getDefaultProperties :: proc() -> GuiProperties {
  props := GuiProperties{
    LINE_HEIGHT          = 50,
    PADDING_TOP          = 30,
    PADDING_LEFT         = 30,
    PADDING_RIGHT        = 30,
    PADDING_BOTTOM       = 30,
    PADDING_ICONS        = 30,
    TITLE_BUTTON_PADDING = 20,
    MENU_BUTTON_WIDTH    = 100,
    MENU_BUTTON_HEIGHT   = 100,
    MENU_BUTTON_PADDING  = 20,
    NAVBAR_SIZE          = 50,
    NAVBAR_PADDING       = 10,
    PANEL_PADDING        = 10,
    ICON_SIZE            = 150,
    FONT                 = rl.GuiGetFont(),
    TEXT_SIZE_TITLE      = 60,
    TEXT_SIZE_DEFAULT    = 25,
    TEXT_SIZE            = 25,
    TEXT_INPUT_WIDTH     = 250,
    TEXT_INPUT_HEIGHT    = 50,
    LINE_WIDTH           = 5,

    BACKGROUND_COLOUR        = rl.WHITE,
    PANEL_BACKGROUND_COLOUR  = rl.WHITE,
    HEADER_COLOUR            = rl.GRAY,
    BUTTON_COLOUR            = rl.LIGHTGRAY,
    BUTTON_BORDER_COLOUR     = rl.GRAY,
    BUTTON_HOVER_COLOUR      = rl.ColorAlpha(rl.SKYBLUE, 0.2),
    BUTTON_ACTIVE_COLOUR     = rl.ColorAlpha(rl.BLUE, 0.2),
    DROPDOWN_COLOUR          = rl.WHITE,
    DROPDOWN_HOVER_COLOUR    = rl.ColorAlpha(rl.SKYBLUE, 0.2),
    DROPDOWN_SELECTED_COLOUR = rl.ColorAlpha(rl.DARKBLUE, 0.2),
  }
  return props
}
