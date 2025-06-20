package main

import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:net"
import "core:os/os2"
import "core:strings"
import "core:thread"
import rl "vendor:raylib"

when ODIN_OS == .Windows {
	FILE_SEPERATOR :: "\\"
	BROWSER_COMMAND :: "start"
} else when ODIN_OS == .Linux {
	FILE_SEPERATOR :: "/"
	BROWSER_COMMAND :: "xdg-open"
}

app_title :: "/Roll-Initiative"
VERSION_MAJOR :: 1
VERSION_MINOR :: 3

static_arena: vmem.Arena
entities_arena: vmem.Arena
icons_arena: vmem.Arena
logger_arena: vmem.Arena
server_arena: vmem.Arena
frame_arena: vmem.Arena

static_alloc: mem.Allocator
entities_alloc: mem.Allocator
icons_alloc: mem.Allocator
logger_alloc: mem.Allocator
server_alloc: mem.Allocator
frame_alloc: mem.Allocator

cstr :: fmt.ctprint
str :: fmt.tprint

state: State
server_thread: ^thread.Thread

FRAME := 0

@(init)
init :: proc() {
	//Initialise memory arenas
	arena_err := vmem.arena_init_static(&static_arena, 10 * mem.Megabyte)
	if arena_err == .None {
		static_alloc = vmem.arena_allocator(&static_arena)
	}
	arena_err = vmem.arena_init_static(&entities_arena, 100 * mem.Megabyte)
	if arena_err == .None {
		entities_alloc = vmem.arena_allocator(&entities_arena)
	}
	arena_err = vmem.arena_init_static(&icons_arena, 50 * mem.Megabyte)
	if arena_err == .None {
		icons_alloc = vmem.arena_allocator(&icons_arena)
	}
	arena_err = vmem.arena_init_static(&logger_arena, 10 * mem.Megabyte)
	if arena_err == .None {
		logger_alloc = vmem.arena_allocator(&logger_arena)
	}
	arena_err = vmem.arena_init_static(&server_arena, 100 * mem.Megabyte)
	if arena_err == .None {
		server_alloc = vmem.arena_allocator(&server_arena)
	}
	frame_alloc = vmem.arena_allocator(&frame_arena)

	context.allocator = static_alloc
	context.temp_allocator = frame_alloc

	rl.SetTraceLogLevel(.NONE)
	rl.GuiSetIconScale(2)

	when ODIN_DEBUG {
		context.logger = log.create_console_logger()
	}

	//Initialisation steps
	rl.InitWindow(1080, 720, app_title)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetWindowMinSize(800, 600)
	rl.SetTargetFPS(60)
	rl.SetExitKey(.Q)
	icon_img := rl.LoadImage("icon.png")
	rl.SetWindowIcon(icon_img)
	rl.UnloadImage(icon_img)

	init_state(&state)

	log.infof("App Dir: %v", state.app_dir)

	when ODIN_OS == .Windows {
		state.ip_str, _ = get_ip_windows()
	} else when ODIN_OS == .Linux {
		state.ip_str, _ = get_ip_linux()
	}

	server_thread = thread.create_and_start(run_combat_server)

	log.infof("Started webserver @: http://%v:%v", state.ip_str, state.config.PORT)
	web_addr := fmt.tprintf("http://%v:%v", state.ip_str, state.config.PORT)
	p, err := os2.process_start({command = {BROWSER_COMMAND, web_addr}})

	_, err = os2.process_wait(p)
	log.debugf("Error launching browser: %v", err)
}

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger()
	}

	context.allocator = static_alloc
	context.temp_allocator = frame_alloc

	defer rl.CloseWindow()

	for (!rl.WindowShouldClose()) {
		state.window_width = cast(f32)rl.GetRenderWidth()
		state.window_height = cast(f32)rl.GetRenderHeight()

		state.mouse_pos = rl.GetMousePosition()

		//Draw
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(state.gui_properties.BACKGROUND_COLOUR)
		clean_hover_stack()

		#partial switch s in &state.current_screen_state {
		case TitleScreenState:
			draw_title_screen()
		case SetupScreenState:
			draw_setup_screen()
		case LoadScreenState:
			draw_load_screen()
		case CombatScreenState:
			draw_combat_screen()
		case SettingsScreenState:
			draw_settings_screen()
		case EntityScreenState:
			draw_entity_screen()
		}

		FRAME += 1

		if (FRAME == 60) {
			log.infof("HOVER STACK: %v", state.hover_stack)
			log.infof(
				"Static alloc | Reserved: %v, Used: %v",
				static_arena.total_reserved,
				static_arena.total_used,
			)
			log.infof(
				"Entities alloc | Reserved: %v, Used: %v",
				entities_arena.total_reserved,
				entities_arena.total_used,
			)
			log.infof(
				"Icons alloc | Reserved: %v, Used: %v",
				icons_arena.total_reserved,
				icons_arena.total_used,
			)
			log.infof(
				"Logger alloc | Reserved: %v, Used: %v",
				logger_arena.total_reserved,
				logger_arena.total_used,
			)
			log.infof(
				"Server alloc | Reserved: %v, Used: %v",
				server_arena.total_reserved,
				server_arena.total_used,
			)
			log.infof(
				"Frame alloc | Reserved: %v, Used: %v",
				frame_arena.total_reserved,
				frame_arena.total_used,
			)
			FRAME = 0
		}
		vmem.arena_free_all(&frame_arena)
	}

	d_init_state(&state)
	thread.terminate(server_thread, 0)
	thread.destroy(server_thread)
	vmem.arena_destroy(&frame_arena)
	vmem.arena_destroy(&entities_arena)
	vmem.arena_destroy(&server_arena)
	vmem.arena_destroy(&static_arena)
}
