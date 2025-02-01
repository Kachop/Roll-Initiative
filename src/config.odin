package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:encoding/json"
import "core:net"
import rl "vendor:raylib"

Config :: struct {
  ENTITY_FILE_PATH: string,
  CUSTOM_ENTITY_PATH: string,
  CUSTOM_ENTITY_FILE: string,
  CUSTOM_ENTITY_FILE_PATH: string,
  WEBPAGE_FILE_PATH: string,
  COMBAT_FILES_PATH: string,

  IP_ADDRESS: net.IP4_Address,
  PORT: int,

  BACKGROUND_COLOUR: rl.Color,
  PANEL_BACKGROUND_COLOUR: rl.Color,
  HEADER_COLOUR: rl.Color,

  BUTTON_BORDER_COLOUR: rl.Color,
  BUTTON_COLOUR: rl.Color,
  BUTTON_HOVER_COLOUR: rl.Color,

  DROPDOWN_COLOUR: rl.Color,
  DROPDOWN_SELECTED_COLOUR: rl.Color,
  DROPDOWN_HOVER_COLOUR: rl.Color,
}

LOAD_CONFIG :: proc(config: ^Config) {
  file_data, ok := os.read_entire_file(fmt.tprint(app_dir, "config.json", sep=FILE_SEPERATOR))
  if (ok) {
    config_json, err := json.parse(file_data)
    if (err == .None) {
      config_fields := config_json.(json.Object)

      config.ENTITY_FILE_PATH = config_fields["entity_file_path"].(string) if ("entity_file_path" in config_fields) else ""
      config.CUSTOM_ENTITY_PATH = "Custom entities"
      config.CUSTOM_ENTITY_FILE = config_fields["custom_entity_file_path"].(string) if ("custom_entity_file_path" in config_fields) else ""
      config.CUSTOM_ENTITY_FILE_PATH = fmt.tprint(config.CUSTOM_ENTITY_PATH, config.CUSTOM_ENTITY_FILE, sep=FILE_SEPERATOR)
      config.WEBPAGE_FILE_PATH = config_fields["webpage_file_path"].(string) if ("webpage_file_path" in config_fields) else ""
      config.COMBAT_FILES_PATH = config_fields["combat_files_path"].(string) if ("combat_files_path" in config_fields) else ""
    } else {
      fmt.println("Error parsing JSON file, ", err)
    }
  } else {
    fmt.println("Error reading config file")
  }

  config.PORT = 3000

  config.BACKGROUND_COLOUR = rl.WHITE
  config.PANEL_BACKGROUND_COLOUR = rl.WHITE
  config.HEADER_COLOUR = rl.GRAY
  config.BUTTON_COLOUR = rl.LIGHTGRAY
  config.BUTTON_BORDER_COLOUR = rl.GRAY
  config.BUTTON_HOVER_COLOUR = rl.BLUE
  config.DROPDOWN_COLOUR = rl.WHITE
  config.DROPDOWN_HOVER_COLOUR = rl.BLUE
  config.DROPDOWN_SELECTED_COLOUR = rl.DARKBLUE
}

SAVE_CONFIG :: proc(config: Config) {
  //Save the current config to file.  
  file_string : string = "{\n\t"
  file_string = fmt.tprintf("%v\"entity_file_path\": \"%v\",\n\t", file_string, config.ENTITY_FILE_PATH)
  file_string = fmt.tprintf("%v\"custom_entities_path\": \"%v\",\n\t", file_string, config.CUSTOM_ENTITY_PATH)
  file_string = fmt.tprintf("%v\"custom_entity_file_path\": \"%v\",\n\t", file_string, config.CUSTOM_ENTITY_FILE)
  file_string = fmt.tprintf("%v\"webpage_file_path\": \"%v\",\n\t", file_string, config.WEBPAGE_FILE_PATH)
  file_string = fmt.tprintf("%v\"combat_files_path\": \"%v\",\n}", file_string, config.COMBAT_FILES_PATH)
  rl.SaveFileText("config.json", raw_data(file_string))
}
