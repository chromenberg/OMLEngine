package renderer

import oml "../"

// TODO: Too many comments, should just remake this but easier to understand and cleaner
// A layout-dirtied element should affect itself, and if

get_layout :: #force_inline proc(n: ^oml.Node) -> oml.Style_Layout {
	return n.style.layout
}
get_border :: #force_inline proc(n: ^oml.Node) -> oml.Style_Border {
	return n.style.border
}
get_sizing :: #force_inline proc(n: ^oml.Node) -> oml.Style_Sizing {
	return n.style.sizing
}
get_clip   :: #force_inline proc(n: ^oml.Node) -> oml.Style_Clipping {
	return n.style.clip
}
get_text   :: #force_inline proc(n: ^oml.Node) -> oml.Style_Text {
	return n.style.text
}


calculate_size :: proc(s: oml.Sizing_Value, avail: f32) -> f32 {
	switch s.type {
	case .Absolute:
		return s.val
	case .Percent:
		// 0% - 100%
		// parent width / val
		return avail * (s.val/100)
	case .Auto:
		return avail
	}
	return avail
}

calculate_height :: proc(s: oml.Sizing_Value, content_height, avail_height: f32) -> f32 {
	switch s.type {
	case .Absolute:
		return s.val
	case .Percent:
		return avail_height * (s.val / 100)
	case .Auto:
		return content_height
	}
	return content_height
}

resolve_length :: proc(s: oml.Sizing_Value, base: f32) -> f32 {
	#partial switch s.type {
	case .Absolute:
		return s.val
	case .Percent:
		return base * (s.val / 100)
	}
	return 0
}

// Resolves the space the border and the padding of a node take up on each axis
content_offset :: proc(n: ^oml.Node, width_avail, height_avail: f32) -> (inset_h, inset_v: f32) {
	border := n.style.border.width
	padding := n.style.layout.padding

	inset_h = resolve_length(border.left, width_avail) + resolve_length(border.right, width_avail) +
		resolve_length(padding.left, width_avail) + resolve_length(padding.right, width_avail)
	inset_v = resolve_length(border.top, height_avail) + resolve_length(border.bottom, height_avail) +
		resolve_length(padding.top, height_avail) + resolve_length(padding.bottom, height_avail)

	return inset_h, inset_v
}

// TODO: test this and make sure its working properly
calculate_layout :: proc(n: ^oml.Node, x, y, width_avail, height_avail: f32) {
	if n == nil do return

	inset_h, inset_v := content_offset(n, width_avail, height_avail)
	// calc the width using the width and how much space is left
	node_w := max(calculate_size(n.style.sizing.width, width_avail), 0)
	content_w := max(node_w - inset_h, 0)

	// update the nodes bounds
	n.render.cur_box.x = x
	n.render.cur_box.y = y
	n.render.cur_box.w = node_w

	// these are the X and Y positions child elements need to be drawn at
	// TODO: shorten the length needed to get a value
	content_x := x + resolve_length(n.style.border.width.left, width_avail) +
		resolve_length(n.style.layout.padding.left, width_avail)
	content_y := y + resolve_length(n.style.border.width.top, height_avail) +
		resolve_length(n.style.layout.padding.top, height_avail)

	n.render.cur_box.content_x = content_x
	n.render.cur_box.content_y = content_y
	n.render.cur_box.content_w = content_w

	// children resolve percentages from the parent box, not available area handed as that wont have inset calcs yet
	inner_h := content_horizontal(n.style.sizing.height, height_avail, inset_v)

	content_h:= f32(0)

	switch n.style.layout.direction {
	case .Vertical:
		content_h = layout_vertical(n, content_x, content_y, content_w, inner_h)
	case .Horizontal:
		content_h = layout_horizontal(n, content_x, content_y, content_w, inner_h)
	}

	outside_height := max(calculate_height(n.style.sizing.height, content_h + inset_v, height_avail), 0)
	n.render.cur_box.h = outside_height
	n.render.cur_box.content_h = max(outside_height - inset_v, 0)
}

// calculates vertically oriented elements, returns the offset caused by the element
layout_vertical :: proc(n: ^oml.Node, child_x, child_y, parent_width, height_avail: f32) -> f32 {
	offset := f32(0)
	gap := n.style.layout.gap
	count := 0

	for child in n.children {
		margin := get_layout(child).margin
		margin_left := resolve_length(margin.left, parent_width)
		margin_right := resolve_length(margin.right, parent_width)
		margin_top := resolve_length(margin.top, height_avail)
		margin_bottom := resolve_length(margin.bottom, height_avail)

		// a gap only sits *between* children, so the first one does not get one
		if count > 0 do offset += gap

		// to get the available width, subtract the parent width by the childs margins
		width_avail := parent_width - margin_left - margin_right
		child_height_avail := height_avail - margin_top - margin_bottom

		// add the "offset", accumulated offset of the previous elements, and the margins this
		// node sits inside of. Horizontally the margin pushes the node in from the content edge.
		calculate_layout(child, child_x + margin_left, child_y + offset + margin_top, width_avail, child_height_avail)

		// add the total box sizing of this node to the offset
		offset += margin_top + child.render.cur_box.h + margin_bottom
		count += 1
	}
	return offset
}

// calculates vertically oriented elements returns the offset caused by the element
layout_horizontal :: proc(n: ^oml.Node, child_x, child_y, parent_width, parent_height: f32) -> (max_height: f32) {
	offset := f32(0)
	count := 0

	const_width := f32(0) // space that is already taken by children with a fixed width
	expand_amount := 0
	for child in n.children {
		margin := child.style.layout.margin
		margins := resolve_length(margin.left, parent_width) + resolve_length(margin.right, parent_width)
		switch child.style.sizing.width.type {
		case .Absolute:
			// every fixed child takes up space, not just the last one
			const_width += child.style.sizing.width.val + margins
		case .Percent:
			const_width += parent_width * (child.style.sizing.width.val / 100) + margins
		case .Auto:
			expand_amount += 1
		}
	}

	gap := n.style.layout.gap
	// a gap only sits *between* children, so there is one less gap than children
	gap_total := gap * f32(max(len(n.children) - 1, 0))
	// remaining space is the parent width
	remaining := parent_width - const_width - gap_total
	// if the width expanded > 0, divide remaining space by the times it expanded
	flex_width := expand_amount > 0 ? max(remaining, 0) / f32(expand_amount) : 0

	for child in n.children {
		margin := child.style.layout.margin
		margin_left := resolve_length(margin.left, parent_width)
		margin_right := resolve_length(margin.right, parent_width)
		margin_top := resolve_length(margin.top, parent_height)
		margin_bottom := resolve_length(margin.bottom, parent_height)

		width := f32(0)
		switch child.style.sizing.width.type {
		case .Absolute:
			width = child.style.sizing.width.val
		case .Percent:
			width = parent_width * (child.style.sizing.width.val / 100)
		case .Auto:
			// subtract the flexbox width by margins
			width = flex_width - (margin_left + margin_right)
		}

		// skip the gap if theres only 1 or less child
		if count > 0 do offset += gap

		// add the accumulated offset caused by all the parent / sibling elements
		calculate_layout(
			child,
			child_x + offset + margin_left,
			child_y + margin_top,
			width,
			parent_height - margin_top - margin_bottom
		)

		// add the total box sizing of this node to the offset
		offset += margin_left + width + margin_right
		count += 1

		// set the max height the box can have
		max_height = max(max_height, margin_top + child.render.cur_box.h + margin_bottom)
	}
	return max_height
}

content_horizontal :: proc(s: oml.Sizing_Value, height, inset: f32) -> f32 {
	switch s.type {
	case .Absolute:
		return max(s.val - inset, 0) // if the heiht would end up less than the inset then just return 0
	case .Percent:
		// divide theheight by the percent and then subtract inset
		return max(height * (s.val / 100) - inset, 0)
	case .Auto:
		return max(height - inset, 0)
	}
	return 0
}

// saves the state of the elements before layout changes occur
//
// used for seeing if the element should be rerendered
snapshot :: proc(n: ^oml.Node) {
	if n == nil do return
	// set the old box to the current box as the current will be changing this reflow
	n.render.old_box = n.render.cur_box
	for child in n.children do snapshot(child)
}

// Pass in the renderer because it is cleaner when calling
// the renderer also contains all the needed information like width and height
reflow :: proc(r: ^Renderer) {
	if r == nil || r.document == nil || r.document.body == nil do return

	root := r.document.body
	w, h := viewport_size(r)
	// root.style.sizing.width = {.Absolute, w}
	// root.style.sizing.height = {.Absolute, h}

	snapshot(root)
	calculate_layout(root, 0, 0, w, h)
}
