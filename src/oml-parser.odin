package oml

import "core:log"
import "core:mem"
import "core:strings"
import "core:encoding/xml"

OML_Parser :: struct {
	using parser: Parser,
	xdoc: ^xml.Document,
	doc: ^Document,
	index: int,
	current_node: xml.Element,
	style_queue: [dynamic]string
}

Any_Node :: union {
  ^DivElement,
  ^TextElement,
  ^Element,
  ^DocumentElement,
  ^CanvasElement,
  ^InputElement,
  ^ButtonElement,
  ^ImageElement,
  ^LinkElement,
  ^Node,
}

Element :: struct {
  using node: Node,
}

DocumentElement :: struct {
  using e: Element,
}

DivElement :: struct {
  using elem: Element,
}

TextElement :: struct {
  using elem: Element,
}

ImageElement :: struct {
  using elem: Element,
  source: string,
}

ButtonElement :: struct {
  using elem: Element,
}
LinkElement :: struct {
  using elem: Element,
  source: string,
  type: string
}

InputElement :: struct {
  using elem: Element,
}

CanvasElement :: struct {
  using elem: Element,
}

Dirty_Type :: enum {
  None,
  Layout,
  Paint,
  Style,
  Composite,
}

Dirty_Flags :: bit_set[Dirty_Type]

Box :: struct {
	x,y,w,h: f32,
	content_x, content_y, content_w, content_h: f32
}

Render_Info :: struct {
  refs: int,
  // every element made is automatically dirtied to force the renderer to paint it
  // then this value is reset
  dirty: Dirty_Flags,
  cur_box: Box,
  old_box: Box
}

Node_Cached :: struct {
  font_id: int,
}

Color :: struct {
  r: int,
  g: int,
  b: int,
  a: int,
}

Sizing_Type :: enum {
  Absolute,
  Percent,
  Auto,
}

Sizing_Value :: struct {
  type: Sizing_Type,
  val: f32
}

Style_Sizing :: struct {
  width: Sizing_Value,
  height: Sizing_Value,

  min_width: Sizing_Value,
  min_height: Sizing_Value,

  max_width: Sizing_Value,
  max_height: Sizing_Value,

  aspect_ratio: [2]f32
}

Text_Wrap_Type :: enum {
  Break_Word,
  Break_Newline,
  Break_Force,
}

Style_Text :: struct {
  font_family: string,
  font_size: int,
  font_weight: int,
}

Style_Side_Sizes :: struct {
  top: Sizing_Value,
  right: Sizing_Value,
  bottom: Sizing_Value,
  left: Sizing_Value,
}

Style_Inline_Sizes :: struct {
  left: Sizing_Value,
  right: Sizing_Value
}

Style_Block_Sizes :: struct {
  top: Sizing_Value,
  right: Sizing_Value
}

Style_Border :: struct {
  width: Style_Side_Sizes,
  color: Color
}

Contain_Type :: enum {
  None,
  Size,
  Layout,
  Paint,
  Strict,
}

Overflow_Type :: enum {
  Visible,
  Clip,
  Hidden,
  Scroll
}

Style_Clipping :: struct {
  contain: Contain_Type,
  overflow_x: Overflow_Type,
  overflow_y: Overflow_Type,
}

X_Align_Type :: enum {
  Left,
  Right,
  Center,
}
Y_Align_Type :: enum {
  Top,
  Center,
  Bottom,
}

Display_Type :: enum {
  Block,
  Flex,
  Grid,
  None,
}

Direction :: enum {
  Horizontal,
  Vertical
}

Style_Layout :: struct {
  padding: Style_Side_Sizes,
  padding_inline: Style_Inline_Sizes,
  padding_block: Style_Block_Sizes,

  margin: Style_Side_Sizes,
  margin_inline: Style_Inline_Sizes,
  margin_block: Style_Block_Sizes,

  display: Display_Type,
  direction: Direction,

  align_items: Y_Align_Type,
  align_self: Y_Align_Type,
  justify_content: X_Align_Type,
  justify_self: X_Align_Type,

  gap: f32
}

Node_Style :: struct {
  sizing: Style_Sizing,
  text: Style_Text,
  layout: Style_Layout,
  border: Style_Border,
  clip: Style_Clipping,
}

Node :: struct {
  render: Render_Info, // info for rendering a node
  derived: Any_Node, // type that is inheriting the node
  parent: ^Node, // node parent
  id: string,
  class: [dynamic]string,
  text: string,
  children: [dynamic]^Node,
  style: ^Node_Style, // styles that are applied to the node, based off of style precedence
  applied_styles: map[string]^Node_Style // styles that are currently affecting the node
}

open_file :: proc(p: ^OML_Parser) -> (err: xml.Error) {
	p.xdoc, err = xml.load_from_file(p.file.src, allocator = p.allocator)
	return
}

Node_Types :: enum {
  Document,
  Node,
  Element,
  TextElement,
  DivElement,
  ImageElement,
  ButtonElement,
  InputElement,
  CanvasElement,

  Count,
}

Node_Type : [Node_Types.Count]typeid = {
  DocumentElement,
  Node,
  Element,
  TextElement,
  DivElement,
  ImageElement,
  ButtonElement,
  InputElement,
  CanvasElement,
}

// Looks up an attribute by key, copied out of the xml element.
get_attribute :: proc(elem: xml.Element, key: string) -> (value: string, ok: bool) {
  for attrib in elem.attribs {
    if attrib.key == key {
      return attrib.val, true
    }
  }
  return "", false
}

// Splits a class attribute into individual class names
split_classes :: proc(value: string, allocator: mem.Allocator) -> [dynamic]string {
  fields := strings.fields(value, context.temp_allocator)
  classes := make([dynamic]string, 0, len(fields), allocator)
  for field in fields {
    append(&classes, strings.clone(field, allocator))
  }
  return classes
}

// Builds the node and its type
create_node :: proc(p: ^OML_Parser, elem: xml.Element) -> ^Node {
  switch elem.ident {
  case "odin", "html":
    n := new(DocumentElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.e.node
  case "div", "rect":
    n := new(DivElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.elem.node
  case "text", "p":
    n := new(TextElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.elem.node
  case "button":
    n := new(ButtonElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.elem.node
  case "input":
    n := new(InputElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.elem.node
  case "canvas":
    n := new(CanvasElement, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.elem.node
  case "link":
    n := new(LinkElement, p.allocator)
    n.derived = n
    return &n.elem.node
  case "img":
    n := new(ImageElement, p.allocator)
    n.derived = n
    return &n.elem.node
  case:
    n := new(Element, p.allocator)
    n.derived = n
    n.children = make([dynamic]^Node, p.allocator)
    return &n.node
  }
}

node_children :: proc(node: ^Node) -> (children: ^[dynamic]^Node, ok: bool) {
  #partial switch derived in node.derived {
  case ^DocumentElement:
    return &derived.e.node.children, true
  case ^DivElement:
    return &derived.elem.node.children, true
  case ^TextElement:
    return &derived.elem.node.children, true
  case ^ButtonElement:
    return &derived.elem.node.children, true
  case ^InputElement:
    return &derived.elem.node.children, true
  case ^CanvasElement:
    return &derived.elem.node.children, true
  case ^Element:
    return &derived.node.children, true
  case ^Node:
    return &derived.children, true
  case ^ImageElement:
    return nil, false
  }
  return nil, false
}

// Copies the attributes the dom cares about from the xml element onto the node.
set_node_attributes :: proc(p: ^OML_Parser, node: ^Node, elem: xml.Element) {
  if id, ok := get_attribute(elem, "id"); ok {
    node.id = strings.clone(id, p.allocator)
  }
  if class, ok := get_attribute(elem, "class"); ok {
    node.class = split_classes(class, p.allocator)
  }

  if source, ok := get_attribute(elem, "source"); ok {
    #partial switch v in node.derived { // if theres a source attribute on the xml elem and node
    case ^ImageElement:
      v.source = strings.clone(source, p.allocator)
    case ^LinkElement:
      v.source = strings.clone(source, p.allocator) // set source to a new copy of the source so we can dealloc xml without it bitching
      if t, has_type := get_attribute(elem, "type"); has_type {
        v.type = strings.clone(t, p.allocator)
      }

      if v.type == "style" { // if the link is importing a stylesheet
        append(&p.style_queue, v.source) // add to the import queue
      }
    }
  }
}

// Runs for every node that is created
Node_Hook :: proc(p: ^OML_Parser, node: ^Node, elem: xml.Element)

// DFS parsing
parse_node :: proc(p: ^OML_Parser, id: xml.Element_ID, parent: ^Node, hook: Node_Hook) -> ^Node {
  p.index = int(id)
  elem := p.xdoc.elements[id]
  p.current_node = elem

  node := create_node(p, elem)
  node.parent = parent

  node.style = new(Node_Style, p.allocator)
  node.style.sizing.width.type = .Auto
  node.style.sizing.height.type = .Auto
  node.style.layout.direction = .Vertical
  node.applied_styles = make(map[string]^Node_Style, p.allocator)

  set_node_attributes(p, node, elem)

  if hook != nil {
    hook(p, node, elem) // run the node hook if specified, lets other things do tasks when a node is made
  }

  if children, has_children := node_children(node); has_children {
    for value in elem.value {
      switch child in value {
      case string:
        content := strings.trim_space(child)
        if len(content) > 0 {
          node.text = strings.clone(content, p.allocator)
        }
      case xml.Element_ID:
        append(children, parse_node(p, child, node, hook))
      }
    }
  }

  return node
}


parse_oml :: proc(p: ^OML_Parser, hook: Node_Hook = nil) {
	if p.doc == nil {
		log.error("Parser has no document to build into")
		return
	}
	if err := open_file(p); err != .None {
		log.errorf("Failed to open %v: %v", p.file.src, err)
		return
	}
	if len(p.xdoc.elements) == 0 {
		log.errorf("No elements found in %v", p.file.src)
		return
	}

	p.doc.tree = parse_node(p, 0, nil, hook)
	xml.destroy(p.xdoc, p.allocator)

	for file in p.style_queue {
    c := new(CSS_Parser, p.allocator)
    c.doc = p.doc
    c.allocator = p.allocator
    c.arena = p.arena
    c.file.src = file

	  parse_css(c)
    append(&c.doc.loaded_styles, c.sheet)
    // free(c)
	}

	p.xdoc = nil
	log.infof("tree %#v", p.doc.tree.derived)
	log.infof("styles %#v", p.doc.loaded_styles[:])
}
