package renderer

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

Renderer :: struct {
	allocator: 	mem.Allocator,
	arena: 			mem.Allocator,
	_arena: 		^mem.Dynamic_Arena,

	sdl: 				SDL_Data,
	document: 	^oml.Document,
	info:				Render_Properties,
	deltas:     oml.Box
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

draw_frame :: proc(r: ^Renderer) {

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
	// tex := r.sdl.texture
	// r.sdl.texture = create_texture(r)
	// sdl3.DestroyTexture(tex)
	// free(tex)
}