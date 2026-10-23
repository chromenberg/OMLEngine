package renderer

import "core:log"
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

margin_x :: proc(n: ^oml.Node, parent_width: f32) -> f32 {
	return resolve_length(get_layout(n).margin.left, parent_width) +
				 resolve_length(get_layout(n).margin.right, parent_width)
}
margin_y :: proc(n: ^oml.Node, parent_width: f32) -> f32 {
	return resolve_length(get_layout(n).margin.top, parent_width) +
				 resolve_length(get_layout(n).margin.bottom, parent_width)
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


desired_box_size :: proc(n: ^oml.Node, avail: f32) -> f32 {
	return margin_x(n, avail) + desired_width(n, avail)
}

// calculates the width a nodes children wants to have their parent set to
intrinsic_width :: proc(n: ^oml.Node, width_avail: f32) -> f32 {
	if n == nil {
		log.logf(.Warning, "Nil node was passed into intrinsic width calculation")
		return 0
	}

	inset_x, _ := content_offset(n, width_avail, width_avail)

	// Measure text content and use that as the content variable
	// TODO: font backend
	content := f32(0)

	layout := get_layout(n)
	switch layout.direction {
	case .Horizontal:
		for child, i in n.children {
			if i > 0 do content += layout.gap // TODO: repeated too muh
			// recurse until tree ends to get needed size
			content += desired_box_size(child, width_avail)
		}
	case .Vertical:
		for child in n.children {
			// widest child sets max width
			content = max(content, desired_box_size(child, width_avail))
		}
	}

	return content + inset_x
}

desired_width :: proc(n: ^oml.Node, parent_width: f32) -> f32 {
	switch get_sizing(n).width.type {
	case .Absolute: return get_sizing(n).width.val
	case .Percent: return parent_width * (get_sizing(n).width.val / 100)
	case .Auto: return intrinsic_width(n, parent_width) // set the width to the widths of the children
	}
	return 0
}

// calculates vertically oriented elements returns the offset caused by the element
//
// This function is O(n) per call, however large subtrees can make this O(n^2)
// Caching implicit width is ideal
layout_horizontal :: proc(n: ^oml.Node, child_x, child_y, parent_width, parent_height: f32) -> (max_height: f32) {
	layout := get_layout(n)
	gap := layout.gap

	lines := &n.render.lines
	clear(lines) // clear the lines before recalc

	if len(n.children) == 0 do return 0

	first_on_line := 0
	used := f32(0)
	// Calculates when a newline should occur
	for child, i in n.children {
		c_lay := get_layout(child)
		reserved := margin_x(child, parent_width)
		switch get_sizing(child).width.type {
			case .Absolute: reserved += get_sizing(child).width.val
			case .Percent:  reserved += parent_width * (get_sizing(child).width.val / 100)
			case .Auto:
		}

		//											Total used space, factors gaps
		if layout.display == .Flex && layout.flex_wrap && i > first_on_line && (used + gap + reserved) > parent_width {
			append(lines, oml.Line{
				first = n.children[first_on_line],
				first_i = first_on_line,
				last = child,
				last_i = i-1
			})
			first_on_line = i
			used = 0 // reset width because of newline
		} else if i > first_on_line { // if i is not the first line then add gaps
			used += gap
		}

		used += reserved
	}

	append(lines, oml.Line{
		first = n.children[first_on_line],
		first_i = first_on_line,
		last = n.children[len(n.children)-1],
		last_i = len(n.children)-1
	})

	offset_y := f32(0)

	// calculates the width of every lines items
	for line, index in lines {
		fixed_width := f32(0) // width of the line
		fillers := 0

		// for every node in the line
		for i in line.first_i ..= line.last_i {
			child := n.children[i]
			// if its "auto" just make it fill the entire line idk
			if get_sizing(child).width.type == .Auto {
				fillers += 1
				fixed_width += margin_x(child, parent_width)
			} else {
				fixed_width += desired_width(child, parent_width) + margin_x(child, parent_width)
			}
		}

		// how many line gaps so far?
		gaps := gap * f32(max(line.last_i - line.first_i, 0))
		remaining := parent_width - fixed_width - gaps
		filler_width := fillers > 0 ? max(remaining, 0) / f32(fillers) : 0

		offset := f32(0)
		height := f32(0)

		// for each item index in the line
		for i in line.first_i ..= line.last_i {
			child := n.children[i]
			margin := get_layout(child).margin

			margin_left   := resolve_length(margin.left, parent_width)
			margin_right  := resolve_length(margin.right, parent_width)
			margin_top    := resolve_length(margin.top, parent_height)
			margin_bottom := resolve_length(margin.bottom, parent_height)

			width := desired_width(child, parent_width)
			if get_sizing(child).width.type ==.Auto {
				width = max(filler_width - margin_left - margin_right, 0)
				// set flex grower width to the width per grower minus margins
				// if its negative set 0 width because negative width is weird
			}

			if i > line.first_i do offset += gap

			calculate_layout(
				child,
				child_x + offset + margin_left,
				child_y + offset_y + margin_top,
				width,
				parent_height - margin_top - margin_bottom
			)

			offset += margin_left + width + margin_right
			// If height is lower we force the height to be the box size
			height = max(height, margin_top + child.render.cur_box.h + margin_bottom)
		}

		offset_y += height // add the height of the line to the offset
		if index < len(lines) - 1 do offset_y += gap
	}

	return offset_y
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
	// context.allocator = r.allocator
	root := r.document.body
	w, h := viewport_size(r)
	// root.style.sizing.width = {.Absolute, w}
	// root.style.sizing.height = {.Absolute, h}

	snapshot(root)
	// TODO: Layout invalidation for implicit sizes needs to propagate up the tree to the root
	// this allows for caching implicit width
	calculate_layout(root, 0, 0, w, h)
}

bubble_dirty :: proc(n: ^oml.Node) {
	node := n
	for ; node != nil; node = node.parent do node.render.dirty += {.Layout}
}
