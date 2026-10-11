package oml

import "core:log"
import "core:strings"
import "core:fmt"
import "core:mem"
import "core:encoding/xml"
import "base:runtime"

import "ocss"
import "ocss/parser"

// Every type is returned as a node, where the specific type is determined inside the node using either
// the typeid or the type
create_node :: proc(type: string, doc: ^Document) -> ^Node {
  new_node := new(Node, doc.allocator)
  new_node.children = make([dynamic]^Node, doc.allocator)
  // Remember the element name so element selectors can be matched when the trees merge.
  new_node.tag = strings.clone(type, doc.allocator)

  switch type {
    case "odin":
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
    case "rect":
      new_node.type = .Rect
      new_node.has_children = true
      new_node.type_id = RectNode
    case "text":
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
    script := new(Loaded_Script)
    script.name = strings.clone_to_cstring(src, doc.allocator)

    append(&doc.scripts, script)
  }
}


update_tree :: proc(xml_doc: ^xml.Document, doc: ^Document, current: ^Node, id: xml.Element_ID, ident: string) -> ^Node {
	new_node := create_node(ident, doc)
  new_node.parent = current

  element := get_xml_node(xml_doc, id)

  // The xml document is freed once the dom is built, so copy the id/class
  // attributes into the document arena.
  _, node_id := get_attribute_by_key(element, "id")
  if node_id != nil {
    new_node.id = strings.clone(node_id.(string), doc.allocator)
  }

  _, node_class := get_attribute_by_key(element, "class")
  if node_class != nil {
    new_node.classes = split_classes(node_class.(string), doc.allocator)
  }

  append(&current.children, new_node)

  if new_node.type == .Head {
   	doc.head = new_node
  }
  if new_node.type == .Body {
   	doc.body = new_node
  }

  // recurse, shifting the current node to be the parent, and the child to be the current
  return new_node
}

// Deserializes an OML node into its odin representation
deserialize :: proc(xml_doc: ^xml.Document, doc: ^Document, current: ^Node, current_id: xml.Element_ID) {
  node := get_xml_node(xml_doc, current_id)
  for child in node.value {
    switch v in child {
      case string:
      case xml.Element_ID:
        child_id := child.(xml.Element_ID)
        child_node := get_xml_node(xml_doc, child_id)

        if is_style_import(child_node) {
	       	log.infof("Found <%v> trying to import stylesheet.", child_node.ident)
	       	queue_style_import(doc, child_node)
        }

        if is_script_import(child_node) {
          log.infof("Found <%v> trying to import script.", child_node.ident)
          load_lua(doc, child_node)
        }

        new_node := update_tree(xml_doc, doc, current, child_id, child_node.ident)
        deserialize(xml_doc, doc, new_node, child_id)
    }
  }
}

// Parses every queued ocss source into its own stylesheet and collects them on
// the document, in the order they were imported.
load_styles :: proc(doc: ^Document) {
  for source in doc.style_imports {
    log.infof("Importing %v", source)

    p := new(parser.Parser, doc.allocator)
    parser.parse(p, source, doc.allocator)

    append(&doc.styles, ocss.create_style_sheet(p, doc.allocator))

    log.infof("Imported %v", source)
  }
}

// Walks the dom and gives every node the clay config computed by merging all
// matching stylesheet rules into it.
merge_styles :: proc(doc: ^Document) {
  if doc.tree == nil do return
  merge_node(doc, doc.tree)
}

merge_node :: proc(doc: ^Document, node: ^Node) {
  node.styles = ocss.resolve_style(doc.styles[:], node.tag, node.id, node.classes, doc.allocator)

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

  // Allocate the document collections on the arena so they share its lifetime.
  doc.style_imports = make([dynamic]string, doc.allocator)
  doc.styles = make([dynamic]^ocss.Style_Sheet, doc.allocator)

  assemble_document(xml_doc, doc)

  // The dom is complete: parse the queued stylesheets, then merge them in.
  load_styles(doc)
  merge_styles(doc)
  load_scripts(doc)
  
  
  log.infof("Parsed %v", filename)
}
