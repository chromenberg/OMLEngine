package oml
// The type of a node as parsed in an OML document
import "shared:clay"
import lua "vendor:lua/5.4"
import "core:mem"
import "base:runtime"
import "ocss"
import "vendor:raylib"

NodeType :: enum {
  Root,
  Head,
  Link,
  Body,
  Rect,
  Text,
  Button,
  InputBox,
  Input
}

ColorType :: enum {
  RGB,
  RGBA,
  HEX,
}

Color :: struct {
  type: ColorType
}

// RGB color data, inherits from base Color data
RGBColor :: struct {
  using _: Color,
  r: u8,
  g: u8,
  b: u8,
}

// RGBA color data, inherits from RGBColor and extends an alpha channel
RGBAColor :: struct {
  using _: RGBColor,
  a: u8,
}

Padding :: struct {
  top: int,
  right: int,
  bottom: int,
  left: int,
}
PaddingBlock :: struct {
  top: int,
  bottom: int,
}
PaddingInline :: struct {
  left: int,
  right: int,
}

SizingInfo :: struct {
  width: int,
  height: int,

  min_width: int,
  min_height: int,

  max_width: int,
  max_height: int,
}

Alignment :: enum {
  None,
  Center,
  Start,
  End,
}

LayoutAlignment :: struct {
  // how left or right are the children aligned
  x: Alignment,
  y: Alignment
}

FontData :: struct {
  size: int,
  weight: int,
  family: string,
}

// data for css
StyleData :: struct {
  color             : Color,
  background_color  : Color,
  padding           : Padding,
  padding_block     : PaddingBlock,
  padding_inline    : PaddingInline,
  sizing            : SizingInfo,
  border_radius     : f32,
  childAlignment    : LayoutAlignment,
  font              : FontData,
}

NodeStyle :: struct {
  class_name: string,
  data: ^ocss.Style_Rule
}

Event_Proc :: #type proc "c" (id: clay.ElementId, pointerData: clay.PointerData, userData: rawptr)

Events :: struct {
  onHover: Event_Proc
}

INode :: struct {
  // The type of the node according to the node enum
  type: NodeType,
  // the typeid of the node that inherits this node
  type_id: typeid,
  has_children: bool,

  // the element name (rect, text, ...) used to match element selectors
  tag: string,
  // classes the node has
  classes: []string,
  // the style computed by merging every matching ocss rule into this node
  styles: ^ocss.Style_Rule,
  id: string,
  // the text content of an element (e.g. the body of <text>)
  text: string,

}

// Holds fields relating to what the garbage collector will track,
// 
// if an element has 0 references for long enough then the node will be removed
// assuming the node has no parents or children
// 
// This is mostly not needed right now, as this would be a language-side thing
GC_Data :: struct {
	refs: int
}

Interactable :: struct {
	event_list: ^Event,
	hovered: bool,
} 

Node :: struct {
  using base: INode,
  events: Interactable,
  using gc: GC_Data,
  parent: ^Node,
  children: [dynamic]^Node,
  tmp_visited: bool `false`
}

RectNode      :: distinct Node
RootNode      :: distinct Node
TextNode      :: distinct Node
ButtonNode    :: distinct Node
InputNode     :: distinct Node
InputBoxNode  :: distinct Node

LinkNodeType :: enum {
  style
}
LinkNode :: struct {
  using node: Node,
  link_type: LinkNodeType,
  source: string
}

StyleClass :: NodeStyle
// A style id is still referenced by a name and style data, so we can go off the class data
StyleId :: StyleClass

// Contains the parsed version of an OML document
Document :: struct {
  arena     : mem.Arena,
  allocator : runtime.Allocator,
  backing   : []byte,
  // All nodes parsed from an OML file
  tree : ^Node,
  body : ^Node,
  head : ^Node,

  // queued ocss imports
  style_imports: [dynamic]string,
  // ocss styles
  styles: [dynamic]^ocss.Style_Sheet,

  script_imports: [dynamic]string,
  scripts: [dynamic]^Loaded_Script,

  font_imports: [dynamic]^RL_Font,
  fonts: [dynamic]^RL_Font
}

Loaded_Script :: struct {
  name: cstring,
  lua_state: ^lua.State
}

RL_Font :: struct {
  fontID: u16,
  fontSize: u16,
  weight: string,
  source: string,
  font: raylib.Font
}