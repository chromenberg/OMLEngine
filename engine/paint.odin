// Paint + raster.
//
// build_display() turns one node's style + box into a flat Display_List.
// raster() replays those lists into the persistent layer texture, clipped to a
// damage rect, so untouched screen regions keep last frame's pixels.
//
// raylib/OpenGL is the throwaway backend. Replace raster()/composite() with a
// Rust/Vulkan consumer of Display_List when handing rendering over.
package main

import "core:strings"
import "vendor:raylib"

color_to_rl :: proc(c: Color) -> raylib.Color {
	return {c.r, c.g, c.b, c.a}
}

rect_to_rl :: proc(r: Rect) -> raylib.Rectangle {
	return {r.x, r.y, r.w, r.h}
}

apply_opacity :: proc(c: Color, o: f32) -> Color {
	return {c.r, c.g, c.b, u8(f32(c.a) * clamp(o, 0, 1))}
}

// raylib wants roundness in 0..1, not pixels.
roundness_for :: proc(radius: f32, r: Rect) -> f32 {
	m := min(r.w, r.h) / 2
	if m <= 0 do return 0
	return clamp(radius / m, 0, 1)
}

// ---------------------------------------------------------------------------
// Display list building (CPU, retained)
// ---------------------------------------------------------------------------

build_display :: proc(n: ^Node) {
	clear(&n.display.ops)
	if !n.style.visible do return

	b := n.box
	tr := n.style.translate
	r := Rect{b.x + tr[0], b.y + tr[1], b.w, b.h}

	if n.style.has_background {
		col := apply_opacity(n.style.background, n.style.opacity)
		if n.style.radius > 0 {
			append(&n.display.ops, Draw_Op{kind = .Rounded_Rect, rect = r, radius = n.style.radius, color = col})
		} else {
			append(&n.display.ops, Draw_Op{kind = .Rect, rect = r, color = col})
		}
	}

	if n.style.has_border {
		col := apply_opacity(n.style.border_color, n.style.opacity)
		thick := max(n.style.border.top, 1)
		append(&n.display.ops, Draw_Op{kind = .Border, rect = r, radius = n.style.radius, thick = thick, color = col})
	}

	if len(n.style.text) > 0 {
		col := apply_opacity(n.style.text_color, n.style.opacity)
		append(
			&n.display.ops,
			Draw_Op {
				kind = .Text,
				rect = {b.content_x + tr[0], b.content_y + tr[1], 0, 0},
				text = n.style.text,
				size = n.style.font_size,
				color = col,
			},
		)
	}
}

// Rebuild only the display lists flagged dirty, then clear the flag.
rebuild_dirty :: proc(n: ^Node) {
	if .Paint in n.dirty {
		build_display(n)
		n.dirty -= {.Paint}
	}
	for c in n.children do rebuild_dirty(c)
}

// ---------------------------------------------------------------------------
// Raster (GPU) + composite
// ---------------------------------------------------------------------------

// Draws the whole tree, but each op is culled against the damage rect and the
// whole pass is scissored, so only damaged pixels are touched.
raster :: proc(root: ^Node, layer: raylib.RenderTexture2D, damage: Rect, bg: Color) {
	w := layer.texture.width
	h := layer.texture.height

	// Clamp damage to the layer so the scissor stays valid.
	x0 := max(damage.x, 0)
	y0 := max(damage.y, 0)
	x1 := min(damage.x + damage.w, f32(w))
	y1 := min(damage.y + damage.h, f32(h))
	if x1 <= x0 || y1 <= y0 do return

	raylib.BeginTextureMode(layer)
	defer raylib.EndTextureMode()

	raylib.BeginScissorMode(i32(x0), i32(y0), i32(x1 - x0), i32(y1 - y0))
	defer raylib.EndScissorMode()

	// Erase the damaged region (raylib's ClearBackground ignores the scissor,
	// so fill it with a rect instead).
	raylib.DrawRectangleRec(rect_to_rl({x0, y0, x1 - x0, y1 - y0}), color_to_rl(bg))

	draw_nodes(root, damage)
}

draw_nodes :: proc(n: ^Node, damage: Rect) {
	for op in n.display.ops {
		if rects_intersect(op.rect, damage) do draw_op(op)
	}
	for c in n.children do draw_nodes(c, damage)
}

draw_op :: proc(op: Draw_Op) {
	rec := rect_to_rl(op.rect)
	switch op.kind {
	case .Rect:
		raylib.DrawRectangleRec(rec, color_to_rl(op.color))
	case .Rounded_Rect:
		raylib.DrawRectangleRounded(rec, roundness_for(op.radius, op.rect), 8, color_to_rl(op.color))
	case .Border:
		if op.radius > 0 {
			raylib.DrawRectangleRoundedLinesEx(
				rec,
				roundness_for(op.radius, op.rect),
				8,
				max(op.thick, 1),
				color_to_rl(op.color),
			)
		} else {
			raylib.DrawRectangleLinesEx(rec, max(op.thick, 1), color_to_rl(op.color))
		}
	case .Text:
		cs := strings.clone_to_cstring(op.text, context.temp_allocator)
		raylib.DrawTextEx(raylib.GetFontDefault(), cs, {op.rect.x, op.rect.y}, op.size, 1, color_to_rl(op.color))
	}
}

// Blit the persistent layer to the screen. The negative source height flips the
// render texture back upright.
composite :: proc(layer: raylib.RenderTexture2D, w, h: f32) {
	raylib.BeginDrawing()
	defer raylib.EndDrawing()

	raylib.ClearBackground(raylib.BLACK)
	src := raylib.Rectangle{0, 0, f32(layer.texture.width), -f32(layer.texture.height)}
	raylib.DrawTextureRec(layer.texture, src, {0, 0}, raylib.WHITE)
}
