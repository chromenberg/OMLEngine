package ast

import "core:mem"
import "base:intrinsics"
import tok "../tokenizer"

Any_Node :: union {
	^Selector,
	^Selector_List,
	^Grouped_Selector,
	^Rule,
	^Block,
	^Declaration,
}


Node :: struct {
  pos: tok.Pos,
  end: tok.Pos,
  derived: Any_Node
}

Selector_List :: struct {
	using node: Node,
	open: tok.Pos,
	inner: [dynamic]^Node,
	close: tok.Pos,
}

Selector_Kind :: enum {
	Id,
	Class,
	Element
}

Grouped_Selector :: struct {
	using node: Node,
	selectors: [dynamic]^Selector
}

Selector :: struct {
	using node: Node,
	kind: Selector_Kind,
	name: tok.Token
}

Declaration :: struct {
	using node: Node,
	name:       tok.Token,
	value:      tok.Token
}

Block :: struct {
	using node: Node,
	open: tok.Pos,
	inner: [dynamic]^Node,
	close: tok.Pos
}

Rule :: struct {
	using node: Node,
	selectors: [dynamic]^Selector_List, // we can have many selector conditions inherit one rule
	inner: ^Block
}

new_from_pos :: proc($T: typeid, pos, end: tok.Pos, allocator := context.allocator) -> ^T {
  node, _ := mem.new(T, allocator)
  node.pos = pos
  node.end = end
  node.derived = node
  base: ^Node = node

  when intrinsics.type_has_field(T, "derived_expr") {
    node.derived_expr = node
  }
  
  when intrinsics.type_has_field(T, "derived_stmt") {
    node.derived_stmt = node
  }

  return node
}

new_from_pos_and_end :: proc($T: typeid, pos: tok.Pos, end: ^Node, allocator := context.allocator) -> ^T {
  return new(T, pos, end != nil ? end.end : pos, allocator)
}

new :: proc {
  new_from_pos,
  new_from_pos_and_end
}