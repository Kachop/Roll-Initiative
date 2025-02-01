package main

import "core:strings"
import rl "vendor:raylib"

GuiFileDialogState :: struct {
  first_load: bool,
  dir_nav_list: [dynamic]cstring,
  current_dir_index: u32,
  current_dir: cstring,
  files_list: [dynamic]cstring,
  dirs_list: [dynamic]cstring,
  selected_file: cstring,
  panelRec: rl.Rectangle,
  panelContentRec: rl.Rectangle,
  panelView: rl.Rectangle,
  panelScroll: rl.Vector2,
}

InitFileDialog :: proc(fileDialogState: ^GuiFileDialogState) {
  fileDialogState.first_load = true
  fileDialogState.dir_nav_list = [dynamic]cstring{}
  fileDialogState.current_dir_index = 0
  fileDialogState.current_dir = current_dir
  fileDialogState.files_list = [dynamic]cstring{}
  fileDialogState.dirs_list = [dynamic]cstring{}
  fileDialogState.selected_file = nil
  fileDialogState.panelRec = {0, 0, 0, 0}
  fileDialogState.panelContentRec = {}
  fileDialogState.panelView = {0, 0, 0, 0}
  fileDialogState.panelScroll = {0, 0}

  getCurrentDirFiles(fileDialogState)
  append(&fileDialogState.dir_nav_list, current_dir)
}

GuiFileDialog :: proc(rec: rl.Rectangle, fileDialogState: ^GuiFileDialogState) -> bool {
  using state.gui_properties
  
  cursor_x : f32 = rec.x
  cursor_y : f32 = rec.y
  
  TEXT_SIZE = TEXT_SIZE_DEFAULT
  rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
 
  if (rl.GuiButton({cursor_x, cursor_y, NAVBAR_SIZE, NAVBAR_SIZE}, rl.GuiIconText(.ICON_ARROW_LEFT, ""))) {
    //Have functionality to traverse up one directory at a time.
    current_dir_split := strings.split(string(fileDialogState.current_dir), "/")
    outer_directory := strings.clone_to_cstring(strings.join(current_dir_split[:len(current_dir_split)-1], "/"))

    inject_at(&fileDialogState.dir_nav_list, fileDialogState.current_dir_index, outer_directory)
    fileDialogState.current_dir = outer_directory
    getCurrentDirFiles(fileDialogState)
  }
  cursor_x += NAVBAR_SIZE + NAVBAR_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, NAVBAR_SIZE, NAVBAR_SIZE}, rl.GuiIconText(.ICON_ARROW_RIGHT, ""))) {
    if (fileDialogState.current_dir_index < (cast(u32)len(fileDialogState.dir_nav_list) - 1)) {
      fileDialogState.current_dir = fileDialogState.dir_nav_list[fileDialogState.current_dir_index + 1]
      fileDialogState.current_dir_index += 1
      getCurrentDirFiles(fileDialogState)
    }
  }
  cursor_x += NAVBAR_SIZE + NAVBAR_PADDING
  
  path_text_length := rec.width - cursor_x - (NAVBAR_SIZE * 3) - NAVBAR_PADDING
  rl.GuiLabel({cursor_x, cursor_y, path_text_length, NAVBAR_SIZE}, fileDialogState.current_dir)
  cursor_x += path_text_length + NAVBAR_PADDING

  if (rl.GuiButton({cursor_x, cursor_y, (NAVBAR_SIZE * 3), NAVBAR_SIZE}, "Select")) {
    //Check selected file and return true.
    //For logic with this element interacting with the outer program.
    if (rl.FileExists(fileDialogState.selected_file)) {
      if (rl.GetFileExtension(fileDialogState.selected_file) == cstring(".combat")) {
        fileDialogState.first_load = true
        return true
      }
    }
  }
  cursor_x = rec.x
  cursor_y += NAVBAR_SIZE + NAVBAR_PADDING

  panel_width := rec.width
  panel_height := state.window_height - cursor_y - PADDING_BOTTOM

  if (fileDialogState.first_load) {
    //State reset in case of going in and out of loading screen.
    fileDialogState.selected_file = nil
    fileDialogState.first_load = false
    fileDialogState.panelContentRec = {
      cursor_x,
      cursor_y,
      panel_width,
      0}
  }

  rl.GuiPanel({
      cursor_x,
      cursor_y,
      panel_width,
      panel_height,
    }, "Files")

  fileDialogState.panelRec = {
    cursor_x,
    cursor_y + 23,
    panel_width,
    panel_height - 23,
  }
  
  cursor_x += PADDING_ICONS
  cursor_y += PADDING_ICONS + 23 + fileDialogState.panelScroll.y

  //Break the current width and height into a grid, draw all folders files in current directory

  icons_per_row := cast(i32)(fileDialogState.panelContentRec.width / (ICON_SIZE + PADDING_ICONS))
  num_rows_max := cast(i32)((fileDialogState.panelRec.height - PADDING_TOP - PADDING_BOTTOM) / (ICON_SIZE + PADDING_ICONS))

  file_counter : u32 = 0
  dir_count : u32 = cast(u32)len(fileDialogState.dirs_list)
  file_count : u32 = cast(u32)len(fileDialogState.files_list)

  num_rows_needed := (cast(f32)(dir_count + file_count) / cast(f32)icons_per_row)

  if (num_rows_needed / cast(f32)cast(i32)(num_rows_needed)) > 1 {
    num_rows_needed = cast(f32)cast(i32)(num_rows_needed) + 1
  }

  dynamic_icon_padding := cast(f32)((cast(i32)fileDialogState.panelContentRec.width % (icons_per_row * cast(i32)ICON_SIZE)) / (icons_per_row + 1))

  if (dynamic_icon_padding < PADDING_ICONS) {
    dynamic_icon_padding = PADDING_ICONS
  }
  
  if (cast(i32)num_rows_needed > num_rows_max) {
    fileDialogState.panelContentRec.width = panel_width - 14
    fileDialogState.panelContentRec.height = (num_rows_needed * ICON_SIZE + PADDING_ICONS) + (PADDING_ICONS * 2) + 69
    rl.GuiScrollPanel(fileDialogState.panelRec, nil, fileDialogState.panelContentRec, &fileDialogState.panelScroll, &fileDialogState.panelView)

    rl.BeginScissorMode(cast(i32)fileDialogState.panelView.x, cast(i32)fileDialogState.panelView.y, cast(i32)fileDialogState.panelView.width, cast(i32)fileDialogState.panelView.height)
  } else {
    fileDialogState.panelContentRec.width = panel_width
  }

  draw_loop: for _ in 0..<num_rows_needed {
    for _ in 0..<icons_per_row {
      //Draw each file icon, with padding
      if file_counter < dir_count + file_count {
        filename : cstring = ""
        if (file_counter < dir_count) {
          path_split := strings.split(string(fileDialogState.dirs_list[file_counter]), FILE_SEPERATOR)
          filename = strings.clone_to_cstring(path_split[len(path_split)-1])

          if (rl.GuiButton({cursor_x, cursor_y, ICON_SIZE, ICON_SIZE}, rl.GuiIconText(.ICON_FOLDER, filename))) {
            //Folder clicked, change this to be current folder.
            inject_at(&fileDialogState.dir_nav_list, fileDialogState.current_dir_index, fileDialogState.dirs_list[file_counter])
            fileDialogState.current_dir = fileDialogState.dirs_list[file_counter]
            getCurrentDirFiles(fileDialogState)
            break draw_loop
          }
          state.gui_properties.TEXT_SIZE = 20
          rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
        } else {
          path_split := strings.split(string(fileDialogState.files_list[file_counter - dir_count]), FILE_SEPERATOR)
          filename = strings.clone_to_cstring(path_split[len(path_split)-1])

          if (rl.GuiButton({cursor_x, cursor_y, ICON_SIZE, ICON_SIZE}, rl.GuiIconText(.ICON_FILETYPE_TEXT, filename))) {
            fileDialogState.selected_file = fileDialogState.files_list[file_counter - dir_count]
          }
          TEXT_SIZE = 20
          rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, TEXT_SIZE)
        }
        cursor_x += ICON_SIZE + dynamic_icon_padding
        file_counter += 1
      }
    }
    cursor_x = rec.x + PADDING_ICONS
    cursor_y += ICON_SIZE + PADDING_ICONS
  }
  if (cast(i32)num_rows_needed > num_rows_max) {
    rl.EndScissorMode()
  } else {
    fileDialogState.panelScroll.y = 0
  }
  return false
}

getCurrentDirFiles :: proc(fileDialogState: ^GuiFileDialogState) {
  file_list := rl.LoadDirectoryFiles(fileDialogState.current_dir)
  clear(&fileDialogState.dirs_list)
  clear(&fileDialogState.files_list)

  for i in 0..<file_list.count {
    if (rl.IsPathFile(file_list.paths[i])) {
      append(&fileDialogState.files_list, file_list.paths[i])
    } else {
      append(&fileDialogState.dirs_list, file_list.paths[i])
    }
  }
}
