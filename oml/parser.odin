package oml

import "core:log"
import "core:reflect"
import "core:strings"
import "base:runtime"
import "core:os"
import "core:encoding/xml"
import "core:mem"
import "core:fmt"

// Every type is returned as a node, where the specific type is determined inside the node using either
// the typeid or the type
create_node :: proc(type: string, doc: ^Document) -> ^Node {
  new_node := new(Node, doc.allocator)
  new_node.children = make([dynamic]^Node, doc.allocator)

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
  fmt.println("has no parent and no node")

  doc.tree = create_node(xml_doc.elements[0].ident, doc)
  // First level iteration, has no parent but has a current node
  deserialize(xml_doc, doc, nil, doc.tree, 0)
  free_all(xml_doc.allocator)
  // |doc.tree = tree
}

get_xml_node :: proc(xml_doc: ^xml.Document, id: int) -> xml.Element {
  return xml_doc.elements[id]
}
get_id :: proc(xml_doc: ^xml.Document, index: u32) -> string {
  str, _ :=xml.find_attribute_val_by_key(xml_doc, index, "id")
  fmt.println(str)
  return str
}

get_attribute_by_key :: proc(node: xml.Element, key: string) -> (_key: string, _val: Maybe(string)) {
	for attribute in node.attribs {
		if attribute.key == key do return attribute.key, attribute.val
	}
	return key, nil
}

is_style_import :: proc(node: xml.Element) -> bool {
	key, val := get_attribute_by_key(node, "type")
	// TODO: Not hardcode this as much
	return val == "style" && node.ident == "link"
}

get_style_data :: proc(doc: ^Document, selector: string) -> ^StyleData {
  // selector includes the key symbol
  //
  // .<name> - class
  // #<name> - id
  // <name> - element
  return nil
}

// Gets the class attribute from the OML node and adds them to the node
deserialize_classes :: proc(xml_doc: ^xml.Document, doc: ^Document, node: ^Node, index: u32) {
  classes, _ :=xml.find_attribute_val_by_key(xml_doc, index, "class")
  class_arr := strings.split(classes, " ", doc.allocator)

  for class in class_arr {
    data := new(NodeStyle, doc.allocator)
    data.class_name = class
    data.data = get_style_data(doc, class)

    append(&node.classes, data)
  }
}

update_tree :: proc(xml_doc: ^xml.Document, doc: ^Document, current: ^Node, id: u32, ident: string) -> ^Node {
	 new_node := create_node(ident, doc)
  new_node.id = get_id(xml_doc, id)
  deserialize_classes(xml_doc, doc, new_node, id)
  new_node.parent = current
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

import "ocss/parser"
import_style :: proc(child_node: xml.Element) -> bool {
	// Halt all parsing of the current OML Document
 	key, src := get_attribute_by_key(child_node, "source")
  if src == nil do return false

  log.infof("Importing %v", src)

  p: parser.Parser
  // p.path = src.(string)
 	parser.parse(&p, src.(string))
  ast := parser.extract_ast(&p)
  
  parser.format_ast(&ast, {.Simple, .Bars})
  log.infof("Imported %v", src.(string))
  // delete(ast.rules)
  return true
}

// Deserializes an OML node into its odin representation
deserialize :: proc(xml_doc: ^xml.Document, doc: ^Document, parent: ^Node, current: ^Node, current_id: int) {
  node := get_xml_node(xml_doc, current_id)
  for child in node.value {
    switch v in child {
      case string:
      case xml.Element_ID:
        child_node := get_xml_node(xml_doc, int(child.(xml.Element_ID)))

        if is_style_import(child_node) {
	       	log.infof("Found <%v> trying to import stylesheet.", child_node.ident)
	       	if import_style(child_node) {
						
					}
						
        }

        new_node := update_tree(
	        xml_doc,
					doc,
					current,
					child.(xml.Element_ID),
					child_node.ident
        )

        deserialize(xml_doc, doc, current, new_node, int(child.(xml.Element_ID)))
    }
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

  assemble_document(xml_doc, doc)
  log.infof("Parsed %v", filename)
}
