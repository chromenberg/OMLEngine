// Frame loop + demo scene.
//
// Frame order:
//   1. step animations   -> animations write style, marking dirty
//   2. layout (if dirty) -> boxes recompute; diff vs snapshot for damage
//   3. collect damage    -> union of changed + paint-dirty node boxes
//   4. rebuild dirty display lists, raster the damage region (scissored)
//   5. composite layer to screen
package main

import "core:fmt"
import "core:os"
import "vendor:raylib"

WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 640

main :: proc() {
	// --smoke just runs a few frames and exits (used to sanity-check it builds).
	smoke := len(os.args) > 1 && os.args[1] == "--smoke"

	raylib.SetConfigFlags(raylib.ConfigFlags{.WINDOW_RESIZABLE, .VSYNC_HINT})
	raylib.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "OMLEngine scratch renderer")
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	scene: Scene
	scene.root = build_demo()
	scene.dirty = {.Style, .Layout, .Paint}

	view_w := f32(raylib.GetScreenWidth())
	view_h := f32(raylib.GetScreenHeight())
	layer := raylib.LoadRenderTexture(i32(view_w), i32(view_h))
	defer raylib.UnloadRenderTexture(layer)

	bg := Color{14, 14, 20, 255}
	need_full_repaint := true

	prev_time := raylib.GetTime()
	frame := 0

	for !raylib.WindowShouldClose() {
		now := raylib.GetTime()
		dt := f32(now - prev_time)
		prev_time = now
		free_all(context.temp_allocator)

		if raylib.IsWindowResized() {
			w := f32(raylib.GetScreenWidth())
			h := f32(raylib.GetScreenHeight())
			if w >= 1 && h >= 1 && (w != view_w || h != view_h) {
				view_w, view_h = w, h
				raylib.UnloadRenderTexture(layer)
				layer = raylib.LoadRenderTexture(i32(view_w), i32(view_h))
				scene.dirty += {.Layout}
				need_full_repaint = true
			}
		}

		if need_full_repaint {
			mark_all_paint(scene.root)
			need_full_repaint = false
		}

		// 1. animations write style through mark_dirty
		step_animations(&scene, scene.root, dt)

		// 2. layout
		if .Layout in scene.dirty {
			layout_tree(scene.root, view_w, view_h)
		}

		// 3. damage
		damage := Rect{}
		has_damage := false
		collect_damage(scene.root, &damage, &has_damage)

		// 4. record + raster only the damaged region
		if has_damage {
			rebuild_dirty(scene.root)
			raster(scene.root, layer, damage, bg)
		}

		// 5. composite
		composite(layer, view_w, view_h)

		clear_dirty(scene.root)
		scene.dirty = {}
		frame += 1
		if smoke && frame >= 4 do break
	}

	// Smoke check: pull the layer back off the GPU and write it out so the
	// render path can be verified without a human looking at the window.
	if smoke {
		img := raylib.LoadImageFromTexture(layer.texture)
		raylib.ImageFlipVertical(&img) // render textures come back bottom-up
		w, h := img.width, img.height

		// sample: centre of the first card body, and the progress bar
		hdr := raylib.GetImageColor(img, 120, 200)
		card := raylib.GetImageColor(img, 40, 316)
		fmt.printfln(
			"smoke: %vx%v header=%v,%v,%v,%v card=%v,%v,%v,%v exported=%v",
			w,
			h,
			hdr.r,
			hdr.g,
			hdr.b,
			hdr.a,
			card.r,
			card.g,
			card.b,
			card.a,
			raylib.ExportImage(img, "smoke.png"),
		)
		raylib.UnloadImage(img)
	}
}

// ---------------------------------------------------------------------------
// Damage bookkeeping
// ---------------------------------------------------------------------------

// A node whose box moved needs its old and new rects erased, and its own
// display list rebuilt (its geometry is baked into the ops).
collect_damage :: proc(n: ^Node, d: ^Rect, has: ^bool) {
	if !rect_eq(box_rect(n.prev_box), box_rect(n.box)) {
		damage_include(d, box_rect(n.prev_box))
		damage_include(d, box_rect(n.box))
		n.dirty += {.Paint}
		has^ = true
	}
	if .Paint in n.dirty {
		damage_include(d, box_rect(n.box))
		has^ = true
	}
	for c in n.children do collect_damage(c, d, has)
}

damage_include :: proc(d: ^Rect, r: Rect) {
	if r.w <= 0 || r.h <= 0 do return
	if d.w <= 0 || d.h <= 0 {
		d^ = r
		return
	}
	x0 := min(d.x, r.x)
	y0 := min(d.y, r.y)
	x1 := max(d.x + d.w, r.x + r.w)
	y1 := max(d.y + d.h, r.y + r.h)
	d^ = {x0, y0, x1 - x0, y1 - y0}
}

mark_all_paint :: proc(n: ^Node) {
	n.dirty += {.Paint}
	for c in n.children do mark_all_paint(c)
}

clear_dirty :: proc(n: ^Node) {
	n.dirty = {}
	for c in n.children do clear_dirty(c)
}

// ---------------------------------------------------------------------------
// Demo scene
// ---------------------------------------------------------------------------

build_demo :: proc() -> ^Node {
	root := new_node()
	root.id = "root"
	root.style.direction = .Column
	root.style.gap = 16
	root.style.padding = {24, 24, 24, 24}
	root.style.has_background = true
	root.style.background = {18, 18, 26, 255}

	header := new_node()
	header.id = "header"
	header.style.text = "OMLEngine scratch renderer"
	header.style.font_size = 26
	header.style.text_color = {230, 230, 240, 255}
	header.style.width = {.Grow, 0}
	header.style.height = {.Fixed, 34}
	add_child(root, header)

	row := new_node()
	row.id = "row"
	row.style.direction = .Row
	row.style.gap = 16
	row.style.width = {.Grow, 0}
	row.style.height = {.Fixed, 220}
	add_child(root, row)

	for _ in 0 ..< 3 {
		card := new_node()
		card.style.direction = .Column
		card.style.padding = {12, 12, 12, 12}
		card.style.gap = 8
		card.style.width = {.Grow, 0}
		card.style.height = {.Grow, 0}
		card.style.has_background = true
		card.style.background = {38, 38, 58, 255}
		card.style.radius = 10
		card.style.has_border = true
		card.style.border = {1, 1, 1, 1}
		card.style.border_color = {51, 51, 74, 255}
		add_child(row, card)
	}

	// Middle card pulses: paint-only (opacity), never touches layout.
	mid := row.children[1]
	animate(
		mid,
		Animation{prop = .Opacity, from = 1, to = 0.25, duration = 1.0, easing = .Ease_In_Out, loop = true},
	)

	// A progress bar grows: width animation -> layout dirty every frame.
	bar := new_node()
	bar.id = "bar"
	bar.style.width = {.Fixed, 60}
	bar.style.height = {.Fixed, 14}
	bar.style.radius = 7
	bar.style.has_background = true
	bar.style.background = {90, 160, 255, 255}
	add_child(root, bar)
	animate(
		bar,
		Animation{prop = .Width, from = 60, to = 700, duration = 1.6, easing = .Ease_In_Out, loop = true},
	)

	// A third card that shifts horizontally: paint dirty, no layout.
	shift := new_node()
	shift.id = "shift"
	shift.style.width = {.Fixed, 90}
	shift.style.height = {.Fixed, 90}
	shift.style.radius = 12
	shift.style.has_background = true
	shift.style.background = {120, 220, 160, 255}
	add_child(root, shift)
	animate(
		shift,
		Animation{prop = .Translate_X, from = 0, to = 120, duration = 1.2, easing = .Ease_In_Out, loop = true},
	)

	return root
}
