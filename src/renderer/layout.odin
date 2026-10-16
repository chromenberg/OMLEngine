package renderer

import oml "../"

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

content_offset :: proc(n: ^oml.Node) -> (inset_h, inset_v: f32) {
	border := n.style.border.width
	padding := n.style.layout.padding

	inset_h = border.left.val + border.right.val + padding.left.val + padding.right.val
	inset_v = border.top.val + border.bottom.val + padding.top.val + padding.bottom.val

	return inset_h, inset_v
}

// TODO: test this and make sure its working properly
calculate_layout :: proc(n: ^oml.Node, x, y, width_avail, height_avail: f32) {

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

	content_h:= 10
	
	// switch n.style.layout.direction {

	// }
}

// saves the state of the elements before layout changes occur
//
// used for seeing if the element should be rerendered
snapshot :: proc(n: ^oml.Node) {
	n.render.old_box = n.render.cur_box // store "current" bounds, beofore changes happen
	for child in n.children do snapshot(n) // dfs
}

// Pass in the renderer because it is cleaner when calling
// the renderer also contains all the needed information like width and height
reflow :: proc(r: ^Renderer) {
	snapshot(doc.tree)
	calculate_layout(doc.tree, 0, 0, doc.)
}
