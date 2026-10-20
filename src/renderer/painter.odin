package renderer

import "core:log"
import "vendor:sdl3"
import oml "../"



build_ops :: proc(n: ^oml.Node) {
	if n == nil do return

	clear(&n.render.ops)

	if !n.style.visible do return

	box := n.render.cur_box
	if box.w <= 0 || box.h <= 0 do return

	if n.style.has_bg {
		color := calc_opacity(n.style.background_color, n.style.opacity)
		kind := oml.Op_Kind.Rect
		if n.style.radius > 0 do kind = .Rounded_Rect
		// the render op needs to be created using the Documents arena allocator
		// this causes a memory leak for every element that has a render operation created
		append(&n.render.ops, oml.Render_Op{
			kind = kind,
			box = box,
			radius = n.style.radius,
			color = n.style.background_color,
		})
	}

	if n.style.has_border {
		color := calc_opacity(n.style.border.color, n.style.opacity)
		thickness := n.style.border.width.top.val
		if thickness <= 0 do thickness = 1
		append(&n.render.ops, oml.Render_Op{
			kind = .Border,
			box = box,
			radius = n.style.radius,
			thickness = thickness,
			color = color,
		})
	}
}

calc_opacity :: proc(c: oml.Color, opacity: f32) -> oml.Color {
	// mult existing opacity by opacity
	return {c.r, c.g, c.b, c.a * clamp(opacity, 0, 1)}
}

calculate_dirty :: proc(r: ^Renderer) {
	doc := r.document

	if .Layout in doc.tree.render.dirty {

	}
}

cmp_bounds :: proc(a, b: oml.Box) -> bool {
	return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h
}

get_deltas :: proc(n: ^oml.Node, b: ^oml.Box, deltas_changed: ^bool) {
	if n == nil {
		log.logf(.Error, "Attempted to calculate deltas of a node that does not exist")
		return
	}

	if !cmp_bounds(n.render.old_box, n.render.cur_box) {
		set_deltas(b, n.render.old_box)
		set_deltas(b, n.render.cur_box)
		n.render.dirty += {.Paint} // node needs a repaint because size has changed
		deltas_changed^ = true
		n.render.old_box = n.render.cur_box // consume this change
	}
	if .Paint in n.render.dirty {
		set_deltas(b, n.render.cur_box)
		deltas_changed^ = true
	}

	for c in n.children do get_deltas(c, b, deltas_changed)
}

set_deltas :: proc(b: ^oml.Box, r: oml.Box) {
	if r.w <= 0 || r.h <= 0 do return // if width and height of the boxx are 0 then we dont need anything
	if b.w <= 0 || b.h <= 0 {
		b^ = r // if the delta data is 0 then it is the first one
		return
	}

	// combine the existing damage box with this box.
	x0 := min(b.x, r.x)
	y0 := min(b.y, r.y)
	x1 := max(b.x + b.w, r.x + r.w)
	y1 := max(b.y + b.h, r.y + r.h)

	b^ = {
		x = x0,
		y = y0,
		w = x1 - x0,
		h = y1 - y0,
	}
}

paint :: proc(r: ^Renderer, deltas: oml.Box/* , bg: oml.Color */) {
	if r.sdl.render == nil || r.sdl.texture == nil do return

	w, h := viewport_size(r)

	x0 := max(deltas.x, 0)
	y0 := max(deltas.y, 0)
	x1 := min(deltas.x + deltas.w, w)
	y1 := min(deltas.y + deltas.h, h)
	if x1 <= x0 || y1 <= y0 do return // nothing to paint

	// set sdl3 to target rendering to that specific texture and reset at the end
	sdl3.SetRenderTarget(r.sdl.render, r.sdl.texture)
	defer sdl3.SetRenderTarget(r.sdl.render, nil)

	// clip the contents by the change in bounds
	clip := sdl3.Rect{i32(x0), i32(y0), i32(x1 - x0), i32(y1 - y0)}
	sdl3.SetRenderClipRect(r.sdl.render, &clip)
	defer sdl3.SetRenderClipRect(r.sdl.render, nil)

	// renderclear doenst do clipping so a rectangle has to be used instead
	// sdl3.SetRenderDrawColor(r.sdl.render, u8(bg.r), u8(bg.g), u8(bg.b), u8(bg.a))
	// fill := sdl3.FRect{x0, y0, x1 - x0, y1 - y0}
	// sdl3.RenderFillRect(r.sdl.render, &fill)

	paint_nodes(r, r.document.tree, deltas)
}

intersects :: proc(a, b: oml.Box) -> bool {
	return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
}

paint_nodes :: proc(r: ^Renderer, n: ^oml.Node, deltas: oml.Box) {
	if n == nil do return

	for op in n.render.ops {
		if intersects(op.box, deltas) do draw_op(r, op)
	}
	for c in n.children do paint_nodes(r, c, deltas)
}

draw_op :: proc(r: ^Renderer, op: oml.Render_Op) {
	rect : sdl3.FRect = {op.box.x, op.box.y, op.box.w, op.box.h}

	#partial switch op.kind {
	case .Rect, .Rounded_Rect:
		sdl3.SetRenderDrawColor(r.sdl.render, u8(op.color.r), u8(op.color.g), u8(op.color.b), u8(op.color.a))
		sdl3.RenderFillRect(r.sdl.render, &rect)
	case .Border:
		sdl3.SetRenderDrawColor(r.sdl.render, u8(op.color.r), u8(op.color.g), u8(op.color.b), u8(op.color.a))
		sdl3.RenderRect(r.sdl.render, &rect)
	}
}

// Repaint and Reflow are linked for some reason, a reflow also causes a repaint (in most occasions) but a repaint cannot cause a reflow
update_dirty :: proc(n: ^oml.Node) {
	if n == nil do return

	if .Paint in n.render.dirty { // if we need a repaint then rebuild styles
		build_ops(n)
		n.render.dirty -= {.Paint}
	}
	for c in n.children do update_dirty(c)
}
