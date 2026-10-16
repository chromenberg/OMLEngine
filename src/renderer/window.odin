package renderer

import "core:strings"
import "vendor:sdl3"



get_renderer :: proc() {
	
}


init_rend :: proc(r: ^Renderer) {	
	ok := sdl3.Init({.VIDEO})
	r.sdl.window = sdl3.CreateWindow(strings.clone_to_cstring(r.sdl.window_data.name), i32(r.info.viewport.x), i32(r.info.viewport.y), r.sdl.window_data.flags)
	r.sdl.device = sdl3.CreateGPUDevice({.SPIRV}, false, "Renderer")
	r.sdl.render = sdl3.CreateGPURenderer(r.sdl.device, r.sdl.window)
	
}

draw :: proc(r: ^Renderer) {
	sdl3.RenderPresent(r.sdl.render)	
}