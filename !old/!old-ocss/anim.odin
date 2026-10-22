// Native animation system.
//
// Animations are owned by the engine and stepped every frame. They write back
// through the same dirty path a Lua setter would, so the renderer never knows
// where a change came from. Lua would only ever call animate()/set_style();
// there are no per-frame callbacks across the FFI boundary.
package main

Easing :: enum {
	Linear,
	Ease_In,
	Ease_Out,
	Ease_In_Out,
}

Anim_Prop :: enum {
	Width,
	Height,
	Opacity,
	Translate_X,
	Translate_Y,
	Background,
}

Animation :: struct {
	prop:     Anim_Prop,
	from:     f32,
	to:       f32,
	duration: f32, // seconds
	delay:    f32, // seconds
	easing:   Easing,
	loop:     bool,

	// Which dirty grade this property costs is decided by its type:
	// Width/Height -> layout, everything else -> paint.
	// (A promoted layer + transform would make translate/opacity Composite-only.)

	elapsed:    f32,
	finished:   bool,
	color_from: Color,
	color_to:   Color,
}

// Queues an animation on a node.
animate :: proc(n: ^Node, a: Animation) {
	append(&n.animations, a)
}

ease :: proc(e: Easing, t: f32) -> f32 {
	t := clamp(t, 0, 1)
	switch e {
	case .Linear:
		return t
	case .Ease_In:
		return t * t
	case .Ease_Out:
		return 1 - (1 - t) * (1 - t)
	case .Ease_In_Out:
		return t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t)
	}
	return t
}

lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

lerp_color :: proc(a, b: Color, t: f32) -> Color {
	return {
		u8(lerp(f32(a.r), f32(b.r), t)),
		u8(lerp(f32(a.g), f32(b.g), t)),
		u8(lerp(f32(a.b), f32(b.b), t)),
		u8(lerp(f32(a.a), f32(b.a), t)),
	}
}

step_animations :: proc(scene: ^Scene, root: ^Node, dt: f32) {
	step_node(scene, root, dt)
}

step_node :: proc(scene: ^Scene, n: ^Node, dt: f32) {
	for &a in n.animations {
		if a.finished do continue

		a.elapsed += dt
		if a.elapsed < a.delay do continue

		span := max(a.duration, 0.0001)
		t := (a.elapsed - a.delay) / span

		if t >= 1 {
			t = 1
			if a.loop {
				a.elapsed = a.delay // restart
			} else {
				a.finished = true
			}
		}

		apply_anim(scene, n, &a, ease(a.easing, t))
	}

	for c in n.children do step_node(scene, c, dt)
}

apply_anim :: proc(scene: ^Scene, n: ^Node, a: ^Animation, e: f32) {
	switch a.prop {
	case .Width:
		n.style.width = {.Fixed, lerp(a.from, a.to, e)}
		mark_dirty(scene, n, {.Layout})
	case .Height:
		n.style.height = {.Fixed, lerp(a.from, a.to, e)}
		mark_dirty(scene, n, {.Layout})
	case .Opacity:
		n.style.opacity = lerp(a.from, a.to, e)
		mark_dirty(scene, n, {.Paint})
	case .Translate_X:
		n.style.translate[0] = lerp(a.from, a.to, e)
		mark_dirty(scene, n, {.Paint})
	case .Translate_Y:
		n.style.translate[1] = lerp(a.from, a.to, e)
		mark_dirty(scene, n, {.Paint})
	case .Background:
		n.style.background = lerp_color(a.color_from, a.color_to, e)
		mark_dirty(scene, n, {.Paint})
	}
}
