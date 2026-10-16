package renderer

import "base:runtime"
import "core:mem"
import "vendor:sdl3"
import oml "../"

Scale :: struct {
	x: f32,
	y: f32
}

Window_Data :: struct {
	name: string `Erdene`,
	flags: sdl3.WindowFlags `{.VULKAN, .RESIZABLE}`,
}

SDL_Data :: struct {
	window_data: Window_Data,
	window: ^sdl3.Window,
	device: ^sdl3.GPUDevice,
	render: ^sdl3.Renderer,
}

Render_Properties :: struct {
	viewport: 	Scale `{x = 640, y = 480}`,
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
	info:				Render_Properties
}

init :: proc(/* r: ^Renderer */) -> ^Renderer {
	r := new(Renderer)
	r.allocator = runtime.heap_allocator()
	r.document = new(oml.Document)
	// mem.dynamic_arena_init(r._arena, r.allocator, r.allocator)
	// r.arena = mem.dynamic_arena_allocator(r._arena)

	init_rend(r)

	return r
}

draw_frame :: proc(r: ^Renderer) {

}


viewport_size :: #force_inline proc(r: ^Renderer) -> (width, height: f32) {
	return r.info.viewport.x, r.info.viewport.y
}