package renderer

import q "core:container/queue"
import "core:fmt"
import "core:log"
import "base:runtime"
import "core:mem"
import "vendor:sdl3"
import oml "../"

Scale :: struct {
	x: f32,
	y: f32
}

Window_Data :: struct {
	name: cstring `Erdene`,
	flags: sdl3.WindowFlags `{.RESIZABLE}`,
}

SDL_Data :: struct {
	window_data: Window_Data,
	window: ^sdl3.Window,
	device: ^sdl3.GPUDevice,
	render: ^sdl3.Renderer,
	texture:^sdl3.Texture
}

Render_Properties :: struct {
	viewport: 	Scale `Scale{x = 640, y = 480}`,
	window: 		Scale,
	vsync: 			bool,
	fps_cap: 		int
}

Mouse_Info :: struct {
	x, y: f32,
	state: sdl3.MouseButtonFlags
	// Mousebuttons that are pressed down	
}

Process_Info :: struct {
	mouse: Mouse_Info
}

Render_Task :: struct {
	
}

Renderer :: struct {
	allocator: 	mem.Allocator,
	arena: 			mem.Allocator,
	_arena: 		^mem.Dynamic_Arena,

	sdl: 				SDL_Data,
	document: 	^oml.Document,
	process: 		Process_Info,
	info:				Render_Properties,
	deltas:     oml.Box,
	queue:      q.Queue(Render_Task)
}

init :: proc(/* r: ^Renderer */) -> ^Renderer {
	log.logf(.Debug, "Initializing renderer")
	r := new(Renderer)
	set_window_size(r, 640, 480)
	
	r.allocator = runtime.heap_allocator()
	r.document = new(oml.Document)
	// mem.dynamic_arena_init(r._arena, r.allocator, r.allocator)
	// r.arena = mem.dynamic_arena_allocator(r._arena)
	log.logf(.Debug, "Size, %f, %f", viewport_size(r))
	init_rend(r)
	r.sdl.texture = create_texture(r)
	return r
}


get_size :: proc(r: ^Renderer) -> (i32, i32) {
	return i32(r.info.viewport.x), i32(r.info.viewport.y)
}
viewport_size :: #force_inline proc(r: ^Renderer) -> (width, height: f32) {
	return r.info.viewport.x, r.info.viewport.y
}

create_texture :: proc(r: ^Renderer) -> ^sdl3.Texture {
	if r.sdl.render == nil do return nil

	texture := sdl3.CreateTexture(r.sdl.render, .RGBA32, .TARGET, get_size(r))
	if texture == nil {
		err := sdl3.GetError()
		if err != nil do log.errorf("Failed to create render texture: %s", string(err))
		else do log.error("Failed to create render texture")
	}
	return texture
}

rebuild_texture :: proc(r: ^Renderer) {
	tex := r.sdl.texture
	r.sdl.texture = create_texture(r)
	sdl3.DestroyTexture(tex)
	// free(tex)
}

get_renderer :: proc() {

}


init_rend :: proc(r: ^Renderer) {
	ok := sdl3.Init({.VIDEO})
	if !ok do panic("Failed to init SDL3")

	r.sdl.window = sdl3.CreateWindow(r.sdl.window_data.name, get_size(r), {.RESIZABLE})
	// TODO: make these a dedicated function
	if r.sdl.window == nil do panic(fmt.tprintf("Failed to create window: %s", string(sdl3.GetError())))

	r.sdl.render = sdl3.CreateRenderer(r.sdl.window, nil)
	if r.sdl.render == nil do panic(fmt.tprintf("Failed to create renderer: %s", string(sdl3.GetError())))

	sdl3.SetRenderLogicalPresentation(r.sdl.render, get_size(r), sdl3.RendererLogicalPresentation.DISABLED)
	sdl3.RenderPresent(r.sdl.render)
}

set_window_size :: proc(r: ^Renderer, w,h: f32) {
	r.info.viewport.x = w
	r.info.viewport.y = h
}

draw_screen :: proc(r: ^Renderer) {
	sdl3.RenderClear(r.sdl.render)

	if r.sdl.texture != nil {
		w, h := viewport_size(r)
		dst := sdl3.FRect{0, 0, w, h}
		sdl3.RenderTexture(r.sdl.render, r.sdl.texture, nil, &dst)
	}

	sdl3.RenderPresent(r.sdl.render)
}

clear_screen :: proc(r: ^Renderer) {
	sdl3.RenderClear(r.sdl.render)
}

shutdown :: proc(r: ^Renderer) {
  sdl3.DestroyWindow(r.sdl.window)
  sdl3.DestroyRenderer(r.sdl.render)
  sdl3.DestroyTexture(r.sdl.texture)
  sdl3.Quit()
  free_all(r.arena)
  free_all(r.allocator)
  free_all(r.document.arena)
  free_all(r.document.allocator)
  free_all(context.allocator)
}

event_callback :: proc "c" (func: proc(event: sdl3.Event)) {
  context = runtime.default_context()
} 

iter_callback :: proc "c" () { 
  
}

init_callback :: proc "c" () {
  
}

exit_callback :: proc "c" () {
  
}