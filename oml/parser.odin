package oml

import "core:log"
import "core:strconv"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:encoding/xml"
import "base:runtime"

import "ocss"
import "ocss/parser"
import "vendor:raylib"

load_font :: proc(doc: ^Document, font: ^RL_Font) {
  font.font = raylib.LoadFontEx(
    strings.clone_to_cstring(font.source, doc.allocator),
		cast(i32)font.fontSize*cast(i32)font.fontSize, nil, 0
	)

	assign_at(
  	&doc.fonts,
  	font.fontID,
  	font
	)

	raylib.SetTextureFilter(
	  font.font.texture,
		raylib.TextureFilter.TRILINEAR
	)
}

get_font :: proc(doc: ^Document, weight: string, size: u16) -> raylib.Font {
  for font in doc.fonts {
    if font.weight == weight && font.fontSize == size do return font.font
  }
  return {}
}

// Resolves a loaded font by its id. Returns a zero Font when the id was not
// loaded; callers can detect that with `font.baseSize == 0`.
get_font_by_id :: proc(doc: ^Document, id: u16) -> raylib.Font {
  if int(id) < len(doc.fonts) && doc.fonts[id] != nil {
    return doc.fonts[id].font
  }
  return {}
}

// Picks the loaded font that best matches a requested weight + size, returning
// the index into `doc.fonts`. `size == 0` matches any size, and the closest
// size is used when there is no exact match. Returns 0 when nothing matches.
resolve_font_id :: proc(doc: ^Document, weight: string, size: u16) -> u16 {
  // exact weight + size first
  for font, i in doc.fonts {
    if font == nil do continue
    if weight != "" && font.weight != weight do continue
    if size != 0 && font.fontSize != size do continue
    return u16(i)
  }

  // otherwise the closest size among fonts of the requested weight
  best: u16 = 0
  best_diff := -1
  for font, i in doc.fonts {
    if font == nil do continue
    if weight != "" && font.weight != weight do continue
    diff := int(font.fontSize) - int(size)
    if diff < 0 do diff = -diff
    if best_diff < 0 || diff < best_diff {
      best_diff = diff
      best = u16(i)
    }
  }
  return best
}

// Font_Resolver callback: gives ocss a font id from the document's loaded fonts.
resolve_font_id_cb :: proc(user_data: rawptr, weight: string, size: u16) -> u16 {
  doc := cast(^Document)user_data
  if doc == nil do return 0
  return resolve_font_id(doc, weight, size)
}

// Every type is returned as a node, where the specific type is determined inside the node using either
// the typeid or the type
create_node :: proc(type: string, doc: ^Document) -> ^Node {
  new_node := new(Node, doc.allocator)
  new_node.children = make([dynamic]^Node, doc.allocator)
  // Remember the element name so element selectors can be matched when the trees merge.
  new_node.tag = strings.clone(type, doc.allocator)

  switch type {
    case "odin", "html":
      new_node.type = .Root
      new_node.has_children = true
      new_node.type_id = RootNode
    case "body":
      new_node.type = .Body
      new_node.has_children = true
      new_node.type_id = Node
    case "head":
      new_node.type = .Head
      new_node.has_children = true
      new_node.type_id = Node
    case "link":
      new_node.type = .Link
      new_node.has_children = false
      new_node.type_id = LinkNode
    case "script":
      new_node.type = .Script
      new_node.has_children = false
      new_node.type_id = Node
    case "img":
      new_node.type = .Image
      new_node.has_children = false
      new_node.type_id = ImageNode
    case "rect", "div":
      new_node.type = .Rect
      new_node.has_children = true
      new_node.type_id = RectNode
    case "text", "p":
      new_node.type = .Text
      new_node.has_children = true
      new_node.type_id = TextNode
    case "input":
      new_node.type = .Input
      new_node.has_children = false
      new_node.type_id = InputNode
    case "button":
      new_node.type = .Button
      new_node.has_children = true
      new_node.type_id = ButtonNode
    case "inputbox":
      new_node.type = .InputBox
      new_node.has_children = false
      new_node.type_id = InputBoxNode

  }
  return new_node
}

assemble_document :: proc(xml_doc: ^xml.Document, doc: ^Document) {
  doc.tree = create_node(xml_doc.elements[0].ident, doc)
  // First level iteration, has no parent but has a current node
  deserialize(xml_doc, doc, doc.tree, 0)
  free_all(xml_doc.allocator)
  // |doc.tree = tree
}

get_xml_node :: proc(xml_doc: ^xml.Document, id: xml.Element_ID) -> xml.Element {
  return xml_doc.elements[id]
}

get_attribute_by_key :: proc(node: xml.Element, key: string) -> (_key: string, _val: Maybe(string)) {
	for attribute in node.attribs {
		if attribute.key == key do return attribute.key, attribute.val
	}
	return key, nil
}

is_style_import :: proc(node: xml.Element) -> bool {
	_, val := get_attribute_by_key(node, "type")
	// TODO: Not hardcode this as much
	return val == "style" && node.ident == "link"
}
is_script_import :: proc(node: xml.Element) -> bool {
	_, val := get_attribute_by_key(node, "source")
	// TODO: Not hardcode this as much
	return val != nil && node.ident == "script"
}
is_font_import :: proc(node: xml.Element) -> bool {
	_, val := get_attribute_by_key(node, "type")
	// TODO: Not hardcode this as much
	return val == "font" && node.ident == "link"
}

// Splits a class attribute into individual class names, copied into `allocator`
// so they outlive the xml document.
split_classes :: proc(value: string, allocator: runtime.Allocator) -> []string {
  fields := strings.fields(value, context.temp_allocator)
  classes := make([]string, len(fields), allocator)
  for field, i in fields {
    classes[i] = strings.clone(field, allocator)
  }
  return classes
}

// Queues an ocss import found while walking the dom.
//
// The stylesheet is *not* parsed here: the whole dom is read first, and only
// then are the queued sources parsed and merged in, so the ocss tree can never
// be consulted before it is complete.
queue_style_import :: proc(doc: ^Document, node: xml.Element) -> bool {
  _, source := get_attribute_by_key(node, "source")
  if source == nil do return false

  append(&doc.style_imports, strings.clone(source.(string), doc.allocator))
  log.infof("Queued stylesheet %v", source.(string))
  return true
}

queue_font_import :: proc(doc: ^Document, node: xml.Element) -> bool {
  _, source := get_attribute_by_key(node, "source")
  _, weight := get_attribute_by_key(node, "weight")
  _, size := get_attribute_by_key(node, "size")
  if source == nil do return false
  if weight == nil do return false
  src := strings.clone(source.(string), doc.allocator)
  wht := strings.clone(weight.(string), doc.allocator)

  font := new(RL_Font, doc.allocator)
  font.fontID = u16(len(doc.font_imports))
  font.source = src
  font.weight = wht

  // optional: the pixel size this font is meant to be used at. Falls back to
  // the built-in size table (by import order) when omitted.
  if size != nil {
    if parsed, ok := strconv.parse_int(size.(string)); ok {
      font.fontSize = u16(parsed)
    }
  }

  append(&doc.font_imports, font)

  log.infof("Queued font %v", source.(string))
  return true
}

load_lua :: proc(doc: ^Document, node: xml.Element) -> bool {
  _, source := get_attribute_by_key(node, "source")
  if source == nil do return false

  append(&doc.script_imports, strings.clone(source.(string), doc.allocator))
  log.infof("Queued script %v", source.(string))
  return true
}

// todo: move this somewhere else
import lua "vendor:lua/5.4"
load_scripts :: proc(doc: ^Document) {
  for src in doc.script_imports {
    log.infof("Setting up script import for [%v]", src)
    script := new(Loaded_Script, doc.allocator)
    script.name = strings.clone_to_cstring(src, doc.allocator)

    append(&doc.scripts, script)
  }
}

check_imports :: proc(doc: ^Document, node: xml.Element) {
  if is_style_import(node) {
   	log.infof("Found <%v> trying to import stylesheet.", node.ident)
   	queue_style_import(doc, node)
  }

  if is_script_import(node) {
    log.infof("Found <%v> trying to import script.", node.ident)
    load_lua(doc, node)
  }

  if is_font_import(node) {
    log.infof("Found <%v> trying to import font.", node.ident)
    queue_font_import(doc, node)
  }
}

update_tree :: proc(xml_doc: ^xml.Document, doc: ^Document, current: ^Node, id: xml.Element_ID, ident: string) -> ^Node {
	new_node := create_node(ident, doc)
  new_node.parent = current

  element := get_xml_node(xml_doc, id)

  _, node_id := get_attribute_by_key(element, "id")
  if node_id != nil {
    new_node.id = strings.clone(node_id.(string), doc.allocator)
  }

  _, node_class := get_attribute_by_key(element, "class")
  if node_class != nil {
    new_node.classes = split_classes(node_class.(string), doc.allocator)
  }

  _, node_src := get_attribute_by_key(element, "src")
  if node_src != nil {
    new_node.source = strings.clone(node_src.(string), doc.allocator)

    loader_request(doc.loader, new_node, node_src.(string))
  }

  append(&current.children, new_node)

  if new_node.type == .Head {
   	doc.head = new_node
  }
  if new_node.type == .Body {
   	doc.body = new_node
  }

  return new_node
}

// Deserializes an OML node into its odin representation
deserialize :: proc(xml_doc: ^xml.Document, doc: ^Document, current: ^Node, current_id: xml.Element_ID) {
  node := get_xml_node(xml_doc, current_id)
  for child in node.value {
    switch v in child {
      case string:

        content := strings.trim_space(v)
        if len(content) > 0 {
          current.text = strings.clone(content, doc.allocator)
        }
      case xml.Element_ID:
        child_id := child.(xml.Element_ID)
        child_node := get_xml_node(xml_doc, child_id)

        check_imports(doc, child_node)

        new_node := update_tree(xml_doc, doc, current, child_id, child_node.ident)
        deserialize(xml_doc, doc, new_node, child_id)
    }
  }
}

FONT_SIZE_COUNTS :: 17
FONT_SIZES : [FONT_SIZE_COUNTS]u16 = {8, 10, 12, 14, 16, 22, 24, 28, 32, 36, 48, 52, 56, 64, 72, 96, 128}

load_fonts :: proc(doc: ^Document) {
  log.infof("Loading fonts. Queue Length: %d", len(doc.font_imports))

  for font, i in doc.font_imports {
    log.infof("Loading font [%s]", font.source)
    if font.fontSize == 0 do font.fontSize = FONT_SIZES[i]
    font.fontID = u16(i)
    load_font(doc, font)

    log.infof("Loaded font source [%v] with size of %d", font.source, FONT_SIZES[i])

  }

  log.infof("Loaded fonts. Fonts loaded (%d sizes): %d", FONT_SIZE_COUNTS, len(doc.font_imports))

}

load_styles :: proc(doc: ^Document) {
  for source in doc.style_imports {
    log.infof("Importing %v", source)

    p := new(parser.Parser, doc.allocator)
    parser.parse(p, source, doc.allocator)

    append(&doc.styles, ocss.create_style_sheet(p, doc.allocator))


    log.infof("Imported %v", source)
  }
}

// recursively merge the Proto-OCSSOM into the DOM
merge_styles :: proc(doc: ^Document) {
  if doc.tree == nil do return
  merge_node(doc, doc.tree)
}

merge_node :: proc(doc: ^Document, node: ^Node) {
  default_grow := node == doc.body // if the node is the body, then make it fill screen
  resolver := ocss.Font_Resolver{ resolve = resolve_font_id_cb, user_data = doc }
  node.styles = ocss.resolve_style(doc.styles[:], &node.data, node.tag, node.id, node.classes, doc.allocator, default_grow, resolver)

  for child in node.children {
    merge_node(doc, child)
  }
}

parse :: proc(filename: string, doc: ^Document) {
  xml_doc, parse_err := xml.load_from_file(filename, allocator = context.temp_allocator)
  if parse_err != nil {
    fmt.printfln("parse error: %v", parse_err)
    return
  }

  mem.arena_init(&doc.arena, doc.backing)
  doc.allocator = mem.arena_allocator(&doc.arena)

  doc.style_imports = make([dynamic]string, doc.allocator)
  doc.styles = make([dynamic]^ocss.Style_Sheet, doc.allocator)
  doc.script_imports = make([dynamic]string, doc.allocator)
  doc.scripts = make([dynamic]^Loaded_Script, doc.allocator)
  doc.font_imports = make([dynamic]^RL_Font, doc.allocator)
  doc.fonts = make([dynamic]^RL_Font, doc.allocator)

  assemble_document(xml_doc, doc)
  load_styles(doc)
  load_fonts(doc)
  merge_styles(doc)
  load_scripts(doc)

  log.infof("Parsed %v", filename)
}
