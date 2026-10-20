package renderer

import "core:fmt"
import "vendor:sdl3"

get_renderer :: proc() {

}


get_size :: proc(r: ^Renderer) -> (i32, i32) {
	return i32(r.info.viewport.x), i32(r.info.viewport.y)
}

init_rend :: proc(r: ^Renderer) {
	ok := sdl3.Init({.VIDEO})
	if !ok do panic("Failed to init SDL3")

	r.sdl.window = sdl3.CreateWindow(r.sdl.window_data.name, get_size(r), {.RESIZABLE})
	// TODO: make these a dedicated function
	if r.sdl.window == nil do panic(fmt.tprintf("Failed to create window: %s", string(sdl3.GetError())))

	r.sdl.render = sdl3.CreateRenderer(r.sdl.window, nil)
	if r.sdl.render == nil do panic(fmt.tprintf("Failed to create renderer: %s", string(sdl3.GetError())))

	sdl3.SetRenderLogicalPresentation(r.sdl.render, get_size(r), .LETTERBOX)
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
	sdl3.RenderClear(r.sdl.render)
}

clear_screen :: proc(r: ^Renderer) {
	sdl3.RenderClear(r.sdl.render)
}
