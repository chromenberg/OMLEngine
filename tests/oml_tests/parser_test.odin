package oml_tests

import "core:testing"
import "shared:clay"
import oml "../../oml"

// Loads an oml file and its stylesheets. Free with `free_document`.
load_document :: proc(path: string) -> oml.Document {
  doc: oml.Document
  doc.backing = make([]byte, 256 * 1024)
  oml.parse(path, &doc)
  return doc
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
  doc := load_document("tests/sizing.oml")
  defer free_document(&doc)

  style := style_of(find_node(doc.tree, "box"))
  testing.expect(t, style != nil, "expected #box to be styled")

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
  doc := load_document("tests/sizing.oml")
  defer free_document(&doc)

  style := style_of(find_node(doc.tree, "fitted"))
  testing.expect(t, style != nil, "expected #fitted to be styled")

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
  doc := load_document("tests/cascade.oml")
  defer free_document(&doc)

  // #target matches the element, class and both id rules; the last one wins
  target := style_of(find_node(doc.tree, "target"))
  testing.expect(t, target != nil, "expected #target to be styled")
  testing.expect_value(t, target.backgroundColor, clay.Color{68, 68, 68, 255})

  // #plain only matches the element selector
  plain := style_of(find_node(doc.tree, "plain"))
  testing.expect(t, plain != nil, "expected #plain to be styled")
  testing.expect_value(t, plain.backgroundColor, clay.Color{17, 17, 17, 255})
}

@(test)
unstyled_nodes_have_no_style :: proc(t: ^testing.T) {
  doc := load_document("tests/sizing.oml")
  defer free_document(&doc)

  node := find_node(doc.tree, "unstyled")
  testing.expect(t, node != nil, "expected to find #unstyled")
  testing.expect(t, node.styles == nil, "a node matching no rule should keep a nil style")
}

@(test)
text_content_and_style :: proc(t: ^testing.T) {
  doc := load_document("tests/text.oml")
  defer free_document(&doc)

  node := find_node(doc.tree, "hello")
  testing.expect(t, node != nil, "expected to find #hello")
  testing.expect_value(t, node.text, "Hello world")

  rule := node.styles
  testing.expect(t, rule != nil, "expected #hello to be styled")
  testing.expect_value(t, rule.text.textColor, clay.Color{255, 0, 0, 255})
  testing.expect_value(t, rule.text.fontSize, u16(24))
  testing.expect_value(t, rule.text.fontId, u16(3))
  testing.expect_value(t, rule.text.letterSpacing, u16(1))
}

@(test)
imports_are_merged_from_disk :: proc(t: ^testing.T) {
  doc := load_document("tests/test.oml")
  defer free_document(&doc)

  style := style_of(find_node(doc.tree, "url_box"))
  testing.expect(t, style != nil, "expected #url_box to be styled")
  testing.expect_value(t, style.backgroundColor, clay.Color{244, 51, 102, 255})
}
