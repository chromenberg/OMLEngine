package oml

import "core:fmt"
import "shared:clay"

build_element :: proc(doc: ^Document, node: ^Node) {
	switch node.type_id {
		case TextNode:
			clay.Text(
				node.text,
				node.styles != nil ? node.styles.text : DEFAULT_TEXT_CONFIG
			)
		case ImageNode:
			config: clay.ElementDeclaration
			if node.styles != nil {
				config = node.styles.properties
			}

			if node.image.state == .Ready { // load image when ready
				config.image.imageData = rawptr(&node.image.texture)
			}
			
			elem_id := clay.ID(node.id)
			if len(node.id) != 0 {
				if clay.UI(elem_id)(config) {
					dispatch_events(node)
					clay.GetScrollContainerData(elem_id)

					render_traverse(doc, node)
				}
			} else {
				if clay.UI()(config) {
					dispatch_events(node)
					render_traverse(doc, node)
				}
			}
		case RectNode:
			if len(node.id) != 0 {

				if node.image.state == .Ready {
				  node.styles.properties.image.imageData = rawptr(&node.image.texture)
				}
				config := node.styles != nil ? node.styles.properties : {}

				open := clay.UI(clay.ID(node.id))
				if config.clip.horizontal || config.clip.vertical {
					config.clip.childOffset = clay.GetScrollOffset()
				}
				if open(config) {
    		  // dispatch then render
					dispatch_events(node)
					render_traverse(doc, node)
				}

			} else {

				config := node.styles != nil ? node.styles.properties : {}
				open := clay.UI()
				if config.clip.horizontal || config.clip.vertical {
					config.clip.childOffset = clay.GetScrollOffset()
				}
				if open(config) {
					dispatch_events(node)
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

render_body :: proc(doc: ^Document) {
	body := doc.body
	if body == nil do return

	config: clay.ElementDeclaration
	if body.styles != nil {
		config = body.styles.properties
	} else {
		config.layout.sizing = {clay.SizingGrow(), clay.SizingGrow()}
	}

	if clay.UI()(config) {
	  // dispatch then render
		dispatch_events(body)
		render_traverse(doc, body)
	}
}

render :: proc(doc: ^Document, delta: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	render_body(doc)
	return clay.EndLayout(delta)
}
