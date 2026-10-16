package renderer

import "core:strings"
import "vendor:sdl3"



get_renderer :: proc() {
	
}


init_rend :: proc(r: ^Renderer) {	
	ok := sdl3.Init({.VIDEO})
	r.window = sdl3.CreateWindow(strings.clone_to_cstring(r.window_data.name), 640, 480, r.window_data.flags)
	r.device = sdl3.CreateGPUDevice({.SPIRV}, false, "Renderer")
	r.render = sdl3.CreateGPURenderer(r.device, r.window)
	
	// sdl3.RenderPresent(r.render)
}

draw :: proc(r: ^Renderer) {
	
}