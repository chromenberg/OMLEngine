package oml

import "core:fmt"
import "shared:clay"

build_element :: proc(doc: ^Document, node: ^Node) {
	switch node.type_id {
		case TextNode:
			clay.Text("temporary text", {
				textColor = clay.Color{40,40,40,255},
				fontId = 0,
				fontSize = 16
			})
		case RectNode:
			if len(node.id) != 0 {

				if clay.UI(clay.ID(node.id))({
					backgroundColor = clay.Color{100,40,40,255}
				}) {
					render_traverse(doc, node)
				}

			} else {

				if clay.UI(clay.ID(node.id))({
					backgroundColor = clay.Color{40,40,40,255}
				}) {
					render_traverse(doc, node)
				}

			}
	}
}

render_traverse :: proc(doc: ^Document, node: ^Node) {
	if len(node.children) == 0 do return
	for child in node.children {
		if child.tmp_visited do continue

		build_element(doc, child)


	}
}

render :: proc(doc: ^Document, delta: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	render_traverse(doc, doc.body)
	return clay.EndLayout(delta)
}
