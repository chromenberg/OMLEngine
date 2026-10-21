package renderer

import oml "../"

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

content_offset :: proc(n: ^oml.Node) -> (inset_h, inset_v: f32) {
	border := n.style.border.width
	padding := n.style.layout.padding

	inset_h = border.left.val + border.right.val + padding.left.val + padding.right.val
	inset_v = border.top.val + border.bottom.val + padding.top.val + padding.bottom.val

	return inset_h, inset_v
}

// TODO: test this and make sure its working properly
calculate_layout :: proc(n: ^oml.Node, x, y, width_avail, height_avail: f32) {
	if n == nil do return

	inset_h, inset_v := content_offset(n)
	// calc the width using the width and how much space is left
	node_w := max(calculate_size(n.style.sizing.width, width_avail), 0)
	content_w := max(node_w - inset_h, 0)

	// update the nodes bounds
	n.render.cur_box.x = x
	n.render.cur_box.y = y
	n.render.cur_box.w = node_w

	// these are the X and Y positions child elements need to be drawn at
	// TODO: shorten the length needed to get a value
	content_x := x + n.style.border.width.left.val + n.style.layout.padding.left.val
	content_y := y + n.style.border.width.top.val + n.style.layout.padding.top.val

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
	for child in n.children {
		// to get the available width, subtract the parent width by the childs margins
		width_avail := parent_width - get_layout(child).margin.left.val - get_layout(child).margin.right.val
		child_height_avail := height_avail - get_layout(child).margin.top.val - get_layout(child).margin.bottom.val
		// add the "offset", accumulated offset of the previous elements
		calculate_layout(child, child_x, child_y + offset + get_layout(child).margin.top.val, width_avail, child_height_avail)

		// add the total box sizing of this node to the offset
		offset += get_layout(child).margin.top.val + child.render.cur_box.h + get_layout(child).margin.bottom.val
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
		margins := child.style.layout.margin.left.val + child.style.layout.margin.right.val
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
		margin_left := child.style.layout.margin.left.val
		margin_right := child.style.layout.margin.right.val
		margin_top := child.style.layout.margin.top.val
		margin_bottom := child.style.layout.margin.bottom.val
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
			parent_height
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
