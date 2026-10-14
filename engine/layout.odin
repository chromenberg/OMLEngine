// CPU layout. Minimal block/row model: enough to produce boxes for the demo.
// Remake this with real formatting contexts (block/inline/flex/grid) later.
package main

// Turns a specified size into a used size given the space offered by the parent.
resolve_size :: proc(s: Size, avail: f32) -> f32 {
	switch s.kind {
	case .Fixed:
		return s.value
	case .Percent:
		return avail * (s.value / 100)
	case .Auto, .Grow:
		return avail
	}
	return avail
}

// Heights resolve bottom-up for auto: content height plus vertical insets.
resolve_height :: proc(s: Size, content_h, avail_h: f32) -> f32 {
	switch s.kind {
	case .Fixed:
		return s.value
	case .Percent:
		return avail_h * (s.value / 100)
	case .Grow:
		return max(avail_h, content_h)
	case .Auto:
		return content_h
	}
	return content_h
}

// Entry point. The root fills the viewport.
layout_tree :: proc(root: ^Node, viewport_w, viewport_h: f32) {
	root.style.width = {.Fixed, viewport_w}
	root.style.height = {.Fixed, viewport_h}
	snapshot_boxes(root)
	layout_node(root, 0, 0, viewport_w, viewport_h)
}

// Records pre-layout geometry so the frame loop can diff old vs new and build a
// damage rect. This is the cheap stand-in for real invalidation bookkeeping.
snapshot_boxes :: proc(n: ^Node) {
	n.prev_box = n.box
	for c in n.children do snapshot_boxes(c)
}

// Places a node at (x, y) and lays out its subtree. available = space offered.
layout_node :: proc(n: ^Node, x, y, avail_w, avail_h: f32) {
	if !n.style.visible {
		n.box = {x, y, 0, 0, x, y, 0, 0}
		return
	}

	h_inset := n.style.border.left + n.style.border.right + n.style.padding.left + n.style.padding.right
	v_inset := n.style.border.top + n.style.border.bottom + n.style.padding.top + n.style.padding.bottom

	outer_w := max(resolve_size(n.style.width, avail_w), 0)
	content_w := max(outer_w - h_inset, 0)

	n.box.x = x
	n.box.y = y
	n.box.w = outer_w

	content_x := x + n.style.border.left + n.style.padding.left
	content_y := y + n.style.border.top + n.style.padding.top

	n.box.content_x = content_x
	n.box.content_y = content_y
	n.box.content_w = content_w

	content_h: f32
	switch n.style.direction {
	case .Column:
		content_h = layout_column(n, content_x, content_y, content_w)
	case .Row:
		// Cross-axis stretch: give children the row's own content height so a
		// Grow/Auto-height child fills it instead of collapsing to content.
		content_h = layout_row(n, content_x, content_y, content_w, cross_content_h(n.style.height, avail_h, v_inset))
	}

	outer_h := max(resolve_height(n.style.height, content_h + v_inset, avail_h), 0)
	n.box.h = outer_h
	n.box.content_h = max(outer_h - v_inset, 0)
}

// Known content height of a node before its children are measured. Used for
// cross-axis stretch in a row.
cross_content_h :: proc(h: Size, avail_h, v_inset: f32) -> f32 {
	switch h.kind {
	case .Fixed:
		return max(h.value - v_inset, 0)
	case .Percent:
		return max(avail_h * (h.value / 100) - v_inset, 0)
	case .Grow:
		return max(avail_h - v_inset, 0)
	case .Auto:
		return 0
	}
	return 0
}

layout_column :: proc(n: ^Node, cx, cy, content_w: f32) -> f32 {
	visible := 0
	for c in n.children do if c.style.visible do visible += 1
	if visible == 0 do return 0

	cursor := f32(0)
	placed := 0
	for c in n.children {
		if !c.style.visible do continue
		child_avail_w := content_w - c.style.margin.left - c.style.margin.right
		layout_node(c, cx + c.style.margin.left, cy + cursor + c.style.margin.top, child_avail_w, 0)
		cursor += c.style.margin.top + c.box.h + c.style.margin.bottom
		placed += 1
		if placed < visible do cursor += n.style.gap
	}
	return cursor
}

layout_row :: proc(n: ^Node, cx, cy, content_w, child_avail_h: f32) -> f32 {
	visible := 0
	for c in n.children do if c.style.visible do visible += 1
	if visible == 0 do return 0

	// Measure fixed tracks, then share the leftover between grow/auto children.
	fixed_w := f32(0)
	grow_count := 0
	for c in n.children {
		if !c.style.visible do continue
		m := c.style.margin.left + c.style.margin.right
		switch c.style.width.kind {
		case .Fixed:
			fixed_w += c.style.width.value + m
		case .Percent:
			fixed_w += content_w * (c.style.width.value / 100) + m
		case .Grow, .Auto:
			grow_count += 1
		}
	}

	gaps := n.style.gap * f32(max(visible - 1, 0))
	leftover := content_w - fixed_w - gaps
	grow_w := grow_count > 0 ? max(leftover, 0) / f32(grow_count) : 0

	cursor := f32(0)
	max_h := f32(0)
	placed := 0
	for c in n.children {
		if !c.style.visible do continue

		cw: f32
		switch c.style.width.kind {
		case .Fixed:
			cw = c.style.width.value
		case .Percent:
			cw = content_w * (c.style.width.value / 100)
		case .Grow, .Auto:
			cw = grow_w - (c.style.margin.left + c.style.margin.right)
		}
		cw = max(cw, 0)

		layout_node(c, cx + cursor + c.style.margin.left, cy + c.style.margin.top, cw, child_avail_h)
		cursor += c.style.margin.left + cw + c.style.margin.right
		placed += 1
		if placed < visible do cursor += n.style.gap
		max_h = max(max_h, c.style.margin.top + c.box.h + c.style.margin.bottom)
	}
	return max_h
}
