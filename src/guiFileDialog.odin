package main

import "core:strings"
import rl "vendor:raylib"

GuiFileDialog :: proc(bounds: rl.Rectangle) {
  rl.GuiWindowBox(bounds, "Test")
}
