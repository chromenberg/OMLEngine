package oml
// The type of a node as parsed in an OML document
import "core:mem"
import "base:runtime"
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
  // A pointer to the style data that was parsed from the ocss file
  // 
  // This is a pointer as style info is shared and can be empty or added later.
  // ocss is parsed instantly when the first link is found,this is so style references in the body cannot 
  // prematurely get data
  data: ^StyleData
}


INode :: struct {
  // The type of the node according to the node enum
  type: NodeType,
  // the typeid of the node that inherits this node
  type_id: typeid,
  has_children: bool,

  // classes the node has
  classes: [dynamic]^NodeStyle,

  id: string
}

Node :: struct {
  using base: INode,
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

Stylesheet :: struct {
  name: string,
  path: string,
  classes: [dynamic]^StyleClass,
  id_map: map[string]^StyleId,
}

// Contains the parsed version of an OML document
Document :: struct {
  arena     : mem.Arena,
  allocator : runtime.Allocator,
  backing   : []byte,
  // All nodes parsed from an OML file
  tree : ^Node,
  body : ^Node,
  head : ^Node,
  styles: [dynamic]^Stylesheet
}