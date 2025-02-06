package main

import "core:fmt"
import "core:log"
import "core:net"
import "core:strings"
import "core:os/os2"
import "core:encoding/json"
import http "shared:odin-http"

/*
Web server to display current running combat to players.
Uses SSE to keep clients upto date with the state of things.
Client will recieve JSON object of combat, will lay it out automatically and style it.
*/

ServerState :: struct {
    running: bool,
    json_data: string,
}

serverState := ServerState{
  true,
  "{}",
}

get_ip_windows :: proc() -> (ip_string: string, err: os2.Error) {
  fmt.println("Setting server ADDR: WINDOWS")
  r, w := os2.pipe() or_return
  defer os2.close(r)

  p: os2.Process; {
    defer os2.close(w)

    p = os2.process_start({
      command = {"ipconfig"},
      stdout = w,
    }) or_return
  }
  output := os2.read_entire_file(r, context.temp_allocator) or_return
  //TODO: Parse the Windows JSON output
  return 
}

get_ip_linux :: proc() -> (ip_string: string, err: os2.Error) {
  fmt.println("Setting server ADDR: LINUX")
  r, w := os2.pipe() or_return
  defer os2.close(r)
  
  p: os2.Process; {
    defer os2.close(w)

    p = os2.process_start({
      command = {"ip", "-br", "-j", "a"},
      stdout = w,
    }) or_return
  }
  output := os2.read_entire_file(r, context.temp_allocator) or_return
  
  json_data, ok := json.parse(output)
  //Look through the JSON data for the correct IP addr
  for ip_info in json_data.(json.Array) {
    fields := ip_info.(json.Object)
    if fields["operstate"].(string) == "UP" {
      ip_string = fields["addr_info"].(json.Array)[0].(json.Object)["local"].(string)
      state.config.IP_ADDRESS = str_to_ipaddr(ip_string)
    }
  }
  return
}

str_to_ipaddr :: proc(addr: string) -> (result: net.IP4_Address) {
  values := strings.split(addr, ".")
  result = net.IP4_Address{
    cast(u8)to_i32(values[0]),
    cast(u8)to_i32(values[1]),
    cast(u8)to_i32(values[2]),
    cast(u8)to_i32(values[3]),
  }
  return
}

run_combat_server :: proc() {
	context.logger = log.create_console_logger(.Info)

	s: http.Server
	// Register a graceful shutdown when the program receives a SIGINT signal.
	http.server_shutdown_on_interrupt(&s)

	// Set up routing
	router: http.Router
	http.router_init(&router)
	defer http.router_destroy(&router)

  http.route_get(&router, "/", http.handler(index))
  http.route_get(&router, "/data", http.handler(event))

  routed := http.router_handler(&router)

	log.info("Listening on ", state.config.IP_ADDRESS, ":", state.config.PORT)

	err := http.listen_and_serve(&s, routed, net.Endpoint{address = state.config.IP_ADDRESS, port = state.config.PORT})
	fmt.assertf(err == nil, "server stopped with error: %v", err)
}

index :: proc(req: ^http.Request, res: ^http.Response) {
	http.respond_file(res, state.config.WEBPAGE_FILE_PATH)
}

event :: proc(req: ^http.Request, res: ^http.Response) {
    //Crab the current combat state and convert it to JSON and send to the site.
    data := fmt.tprintf("data:%v\n\n", serverState.json_data)

    respond_sse(res, data)
}

respond_sse :: proc(r: ^http.Response, text: string, status: http.Status = .OK, loc := #caller_location) {
    r.status = status
    http.headers_set_content_type(&r.headers, "text/event-stream")
    //http.headers_set_unsafe(&r.headers, "Connection", "keep-alive")
    //http.headers_set_unsafe(&r.headers, "Keep-Alive", "timeout=1")
    http.body_set(r, text, loc)
    http.respond(r, loc)
}
