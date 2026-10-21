package renderer

import oml "../"
import "vendor:sdl3"

FPoint :: sdl3.FPoint

update_mouse :: proc(r: ^Renderer) {
	r.process.mouse.state = sdl3.GetMouseState(&r.process.mouse.x, &r.process.mouse.y)
}

get_mouse_pos :: proc(r: ^Renderer) -> (x,y: f32) {
	return r.process.mouse.x, r.process.mouse.y
}
get_mouse_point :: proc(r: ^Renderer) -> FPoint {
	return {r.process.mouse.x, r.process.mouse.y}
}


is_mouse_over :: proc(r: ^Renderer, n: ^oml.Node) -> bool {
	// TODO: Properties like position and scale should be put into a vector4 to allow for swizzling
	x,y,w,h := n.render.cur_box.x, n.render.cur_box.y,n.render.cur_box.w, n.render.cur_box.h
	
	return sdl3.PointInRectFloat(get_mouse_point(r), {x,y,w,h})
}
