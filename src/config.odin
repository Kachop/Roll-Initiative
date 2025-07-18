package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:net"
import "core:os"
import rl "vendor:raylib"

Config :: struct {
	ENTITY_FILE_PATH:        string,
	CUSTOM_ENTITIES_DIR:     string,
	CUSTOM_ENTITY_FILE:      string,
	CUSTOM_ENTITY_FILE_PATH: string,
	WEBPAGE_FILE_PATH:       string,
	COMBAT_FILES_DIR:        string,
	IP_ADDRESS:              net.IP4_Address,
	PORT:                    int,
}

LOAD_CONFIG :: proc(config: ^Config) {
	log.infof("LOADING CONFIG FILE @: %v%v%v", state.app_dir, FILE_SEPERATOR, "config.json")
	defer log.info("SUCCESSFULLY LOADED CONFIG.")

	if os.exists(fmt.tprint(state.app_dir, FILE_SEPERATOR, "config.json", sep = "")) {
		file_data, ok := os.read_entire_file(
			fmt.tprint(state.app_dir, FILE_SEPERATOR, "config.json", sep = ""),
			allocator = context.temp_allocator,
		)
		if (ok) {
			config_json, err := json.parse(file_data)
			if (err == .None) {
				config_fields := config_json.(json.Object)
				config.ENTITY_FILE_PATH =
					config_fields["entity_file"].(string) if ("entity_file" in config_fields) else ""
				config.CUSTOM_ENTITIES_DIR =
					config_fields["custom_entities_dir"].(string) if ("custom_entities_dir" in config_fields) else ""
				config.CUSTOM_ENTITY_FILE =
					config_fields["custom_entity_file"].(string) if ("custom_entity_file" in config_fields) else ""
				config.CUSTOM_ENTITY_FILE_PATH = fmt.aprint(
					config.CUSTOM_ENTITIES_DIR,
					config.CUSTOM_ENTITY_FILE,
					sep = "",
				)
				config.WEBPAGE_FILE_PATH =
					config_fields["webpage_file"].(string) if ("webpage_file" in config_fields) else ""
				config.COMBAT_FILES_DIR =
					config_fields["combat_files_dir"].(string) if ("combat_files_dir" in config_fields) else ""
			} else {
				log.debugf("ERROR PARSING JSON FILE: %v", err)
			}
		} else {
			log.debugf("ERROR READING CONFIG FILE")
		}
	} else { 	//Make fresh config file.
		config.ENTITY_FILE_PATH = fmt.aprint(
			state.app_dir,
			FILE_SEPERATOR,
			"srd_5e_monsters.json",
			sep = "",
		)
		config.CUSTOM_ENTITIES_DIR = fmt.aprint(
			state.app_dir,
			FILE_SEPERATOR,
			"Custom entities",
			FILE_SEPERATOR,
			sep = "",
		)
		config.CUSTOM_ENTITY_FILE = fmt.aprint("")
		config.CUSTOM_ENTITY_FILE_PATH = fmt.aprint(
			config.CUSTOM_ENTITIES_DIR,
			config.CUSTOM_ENTITY_FILE,
			sep = FILE_SEPERATOR,
		)
		config.WEBPAGE_FILE_PATH = fmt.aprint(
			state.app_dir,
			FILE_SEPERATOR,
			"index.html",
			sep = "",
		)
		config.COMBAT_FILES_DIR = fmt.aprint(
			state.app_dir,
			FILE_SEPERATOR,
			"combats",
			FILE_SEPERATOR,
			sep = "",
		)
		SAVE_CONFIG(config)
		LOAD_CONFIG(config)
	}
	config.PORT = 3000
}

unload_config :: proc(config: ^Config) {
}

SAVE_CONFIG :: proc(config: ^Config) {
	//Save the current config to file.
	if ODIN_OS == .Windows {
		//Add extra \ to save file paths properly
		config.ENTITY_FILE_PATH = double_escape_backslashes(config.ENTITY_FILE_PATH)
		config.CUSTOM_ENTITIES_DIR = double_escape_backslashes(config.CUSTOM_ENTITIES_DIR)
		config.CUSTOM_ENTITY_FILE = double_escape_backslashes(config.CUSTOM_ENTITY_FILE)
		config.WEBPAGE_FILE_PATH = double_escape_backslashes(config.WEBPAGE_FILE_PATH)
		config.COMBAT_FILES_DIR = double_escape_backslashes(config.COMBAT_FILES_DIR)
	}
	file_string: string = "{\n\t"
	file_string = fmt.tprintf(
		"%v\"entity_file\": \"%v\",\n\t",
		file_string,
		config.ENTITY_FILE_PATH,
	)
	file_string = fmt.tprintf(
		"%v\"custom_entities_dir\": \"%v\",\n\t",
		file_string,
		config.CUSTOM_ENTITIES_DIR,
	)
	file_string = fmt.tprintf(
		"%v\"custom_entity_file\": \"%v\",\n\t",
		file_string,
		config.CUSTOM_ENTITY_FILE,
	)
	file_string = fmt.tprintf(
		"%v\"webpage_file\": \"%v\",\n\t",
		file_string,
		config.WEBPAGE_FILE_PATH,
	)
	file_string = fmt.tprintf(
		"%v\"combat_files_dir\": \"%v\",\n}",
		file_string,
		config.COMBAT_FILES_DIR,
	)
	rl.SaveFileText("config.json", raw_data(file_string))
}

double_escape_backslashes :: proc(str: string) -> (result: string) {
	start_idx: int = 0
	end_idx: int = 0
	for char, i in str {
		if char == '\\' {
			end_idx = i
			if start_idx == 0 {
				result = fmt.aprint(result, str[start_idx:end_idx + 1], "\\", sep = "")
			} else {
				result = fmt.aprint(result, str[start_idx + 1:end_idx + 1], "\\", sep = "")
			}
			start_idx = i
		}
	}
	if (end_idx == 0) {
		result = str
		return
	}
	if (end_idx != len(str)) {
		result = fmt.aprint(result, str[start_idx + 1:], sep = "")
	}
	return
}

