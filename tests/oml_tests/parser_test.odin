package oml_tests

import "core:testing"
import "shared:clay"
import oml "../../oml"

// Loads an oml file and its stylesheets into `doc`.
//
// `doc` must outlive the returned document: the arena allocator stores a
// pointer to `doc.arena`, so returning the document by value would leave it
// dangling. Free with `free_document`.
load_document :: proc(doc: ^oml.Document, path: string) {
  doc.backing = make([]byte, 256 * 1024)
  oml.parse(path, doc)
}

free_document :: proc(doc: ^oml.Document) {
  free_all(doc.allocator)
  delete(doc.backing)
}

// Depth-first search for the first node with the given id.
find_node :: proc(node: ^oml.Node, id: string) -> ^oml.Node {
  if node == nil do return nil
  if node.id == id do return node

  for child in node.children {
    if found := find_node(child, id); found != nil do return found
  }
  return nil
}

// The merged clay config of a node, or nil when nothing matched it.
style_of :: proc(node: ^oml.Node) -> ^clay.ElementDeclaration {
  if node == nil || node.styles == nil do return nil
  return &node.styles.properties
}

@(test)
sizing_spacing_and_radius :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/sizing.oml")
  defer free_document(&doc)

  style := style_of(find_node(doc.tree, "box"))
  if !testing.expect(t, style != nil, "expected #box to be styled") do return

  testing.expect_value(t, style.backgroundColor, clay.Color{16, 32, 48, 255})
  testing.expect_value(t, style.cornerRadius.topLeft, f32(8.5))
  testing.expect_value(t, style.layout.padding, clay.Padding{left = 8, right = 8, top = 4, bottom = 4})
  testing.expect_value(t, style.layout.childGap, u16(6))

  // width: 100px stays 100 after the min 20 / max 300 constraints
  testing.expect_value(t, style.layout.sizing.width.type, clay.SizingType.Fixed)
  testing.expect_value(t, style.layout.sizing.width.constraints.sizeMinMax.min, f32(100))

  // height: 50%
  testing.expect_value(t, style.layout.sizing.height.type, clay.SizingType.Percent)
  testing.expect_value(t, style.layout.sizing.height.constraints.sizePercent, f32(0.5))
}

@(test)
min_max_without_explicit_size :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/sizing.oml")
  defer free_document(&doc)

  style := style_of(find_node(doc.tree, "fitted"))
  if !testing.expect(t, style != nil, "expected #fitted to be styled") do return

  // min-width only: an auto (fit) width carrying the min / max constraints
  testing.expect_value(t, style.layout.sizing.width.type, clay.SizingType.Fit)
  testing.expect_value(t, style.layout.sizing.width.constraints.sizeMinMax.min, f32(30))
  testing.expect_value(t, style.layout.sizing.width.constraints.sizeMinMax.max, f32(0))

  testing.expect_value(t, style.layout.sizing.height.constraints.sizeMinMax.max, f32(90))

  // short hex #abc
  testing.expect_value(t, style.backgroundColor, clay.Color{170, 187, 204, 255})
}

@(test)
cascade_most_recent_wins :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/cascade.oml")
  defer free_document(&doc)

  // #target matches the element, class and both id rules; the last one wins
  target := style_of(find_node(doc.tree, "target"))
  if !testing.expect(t, target != nil, "expected #target to be styled") do return
  testing.expect_value(t, target.backgroundColor, clay.Color{68, 68, 68, 255})

  // #plain only matches the element selector
  plain := style_of(find_node(doc.tree, "plain"))
  if !testing.expect(t, plain != nil, "expected #plain to be styled") do return
  testing.expect_value(t, plain.backgroundColor, clay.Color{17, 17, 17, 255})
}

@(test)
unstyled_nodes_have_no_style :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/sizing.oml")
  defer free_document(&doc)

  node := find_node(doc.tree, "unstyled")
  testing.expect(t, node != nil, "expected to find #unstyled")
  testing.expect(t, node.styles == nil, "a node matching no rule should keep a nil style")
}

@(test)
body_direction_and_default_grow :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/direction.oml")
  defer free_document(&doc)

  body := doc.body
  if !testing.expect(t, body != nil, "expected a body") do return
  if !testing.expect(t, body.styles != nil, "expected the body to be styled") do return

  props := body.styles.properties
  testing.expect_value(t, props.layout.layoutDirection, clay.LayoutDirection.TopToBottom)
  testing.expect_value(t, props.layout.childGap, u16(4))

  // axes left unset on the body default to grow (fill the window)
  testing.expect_value(t, props.layout.sizing.width.type, clay.SizingType.Grow)
  testing.expect_value(t, props.layout.sizing.height.type, clay.SizingType.Grow)
}

@(test)
text_content_and_style :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/text.oml")
  defer free_document(&doc)

  node := find_node(doc.tree, "hello")
  if !testing.expect(t, node != nil, "expected to find #hello") do return
  testing.expect_value(t, node.text, "Hello world")

  rule := node.styles
  if !testing.expect(t, rule != nil, "expected #hello to be styled") do return
  testing.expect_value(t, rule.text.textColor, clay.Color{255, 0, 0, 255})
  testing.expect_value(t, rule.text.fontSize, u16(24))
  testing.expect_value(t, rule.text.fontId, u16(3))
  testing.expect_value(t, rule.text.letterSpacing, u16(1))
}

@(test)
node_events_register_emit_remove :: proc(t: ^testing.T) {
  doc: oml.Document
  load_document(&doc, "tests/sizing.oml")
  defer free_document(&doc)

  node := find_node(doc.tree, "box")
  if !testing.expect(t, node != nil, "expected #box") do return

  count := 0
  handler :: proc(n: ^oml.Node, user_data: rawptr) {
    (cast(^int)user_data)^ += 1
  }

  oml.node_on(node, oml.Event_Kind.Hover, handler, &count, doc.allocator)
  oml.emit(node, oml.Event_Kind.Hover)
  oml.emit(node, oml.Event_Kind.Hover)
  testing.expect_value(t, count, 2)

  // a different event kind must not fire the hover listener
  oml.emit(node, oml.Event_Kind.Click)
  testing.expect_value(t, count, 2)

  oml.node_off(node, oml.Event_Kind.Hover)
  oml.emit(node, oml.Event_Kind.Hover)
  testing.expect_value(t, count, 2)

  // name mapping used by the Lua `on` binding
  kind, ok := oml.event_kind_from_name("mouse:over")
  testing.expect(t, ok)
  testing.expect_value(t, kind, oml.Event_Kind.Hover)
  _, bad := oml.event_kind_from_name("not_an_event")
  testing.expect(t, !bad, "unknown event names should not map")
}

// Fonts are chosen from their weight + size. Uses fake fonts so no raylib
// window/font loading is required.
@(test)
font_resolution_by_weight_and_size :: proc(t: ^testing.T) {
  doc: oml.Document

  fonts: [3]oml.RL_Font
  fonts[0].weight = "regular"; fonts[0].fontSize = 16
  fonts[1].weight = "bold";    fonts[1].fontSize = 16
  fonts[2].weight = "bold";    fonts[2].fontSize = 24

  doc.fonts = make([dynamic]^oml.RL_Font, context.allocator)
  defer delete(doc.fonts)
  append(&doc.fonts, &fonts[0], &fonts[1], &fonts[2])

  // exact weight + size
  testing.expect_value(t, oml.resolve_font_id(&doc, "bold", 24), u16(2))
  testing.expect_value(t, oml.resolve_font_id(&doc, "bold", 16), u16(1))
  testing.expect_value(t, oml.resolve_font_id(&doc, "regular", 16), u16(0))

  // size 0 matches any size for that weight
  testing.expect_value(t, oml.resolve_font_id(&doc, "bold", 0), u16(1))

  // closest size among the requested weight (20 is 4 from both; first wins)
  testing.expect_value(t, oml.resolve_font_id(&doc, "bold", 20), u16(1))

  // unknown weight resolves to nothing
  testing.expect_value(t, oml.resolve_font_id(&doc, "italic", 16), u16(0))
}
