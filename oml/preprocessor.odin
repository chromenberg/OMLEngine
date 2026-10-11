package oml

import "core:fmt"
import "shared:clay"

// Fallback text config for text elements that match no stylesheet rule.
// Styled text elements get theirs from the computed rule (which already fills
// in the same defaults).
DEFAULT_TEXT_CONFIG :: clay.TextElementConfig{
	textColor = clay.Color{40,40,40,255},
	fontId = 0,
	fontSize = 16,
}

build_element :: proc(doc: ^Document, node: ^Node) {
	switch node.type_id {
		case TextNode:
			clay.Text(
				node.text,
				node.styles != nil ? node.styles.text : DEFAULT_TEXT_CONFIG
			)
		case RectNode:
			if len(node.id) != 0 {

				if clay.UI(clay.ID(node.id))(
				  node.styles != nil ? node.styles.properties : {}
				) {
					render_traverse(doc, node)
				}

			} else {

				if clay.UI()(
					node.styles != nil ? node.styles.properties : {}
				) {
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
