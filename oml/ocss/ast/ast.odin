package ast

import "core:mem"
import "base:intrinsics"
import tok "../tokenizer"

// Null Denotation
// if a token has a NUD handler, the token should not expect anything to the left
// 
// like prefix or unary


// left denotation
// tokens with an LED handler should expect to be between or after an expression to the left

BINDING_POWER :: enum {
	Default,
	Comma,
	Assignment,
	Logical,
	Relational,
	Additive,
	Multiplicative,
	Unary,
	Call,
	Member,
	Primary
}

// Need a lookup table for each handler
// Statements
// Null,
// Left
// Binding Power

Any_Node :: union {
  ^Attribute,
  ^Selector,
  ^Selector_List,
  ^Identifier,
  
  ^Basic_Lit,
  ^Unary_Expr,
  ^Binary_Expr,
  ^Style_Expr,
  ^Paren_Expr,

  
  ^Block_Stmt,
  ^Assign_Stmt,
  
  ^Style_Type,

  ^Value_Decl
}

Any_Expr :: union {
  ^Identifier,
  ^Basic_Lit,
  ^Style_Expr,
  ^Paren_Expr,
  ^Unary_Expr,
  ^Binary_Expr,
  
  ^Style_Type,
}

Any_Stmt :: union {
  ^Block_Stmt,
  ^Assign_Stmt,

  ^Value_Decl
}

Node :: struct {
  pos: tok.Pos,
  end: tok.Pos,
  derived: Any_Node
}

// types

// A statement is usually defined by a keyword, like `function`
// 
// `function` is a statement and within are expressions or more statements
Stmt :: struct {
  using stmt_base: Node,
  derived_stmt: Any_Stmt
}

Expr :: struct {
  using expr_base: Node,
  derived_expr: Any_Expr
}

Decl :: struct {
  using decl_base: Stmt
}

// Statements

// 1 + 1
Assign_Stmt :: struct {
  using node: Stmt,
  lhs: []^Expr,
  op: tok.Token,
  rhs: []^Expr
}

Block_Stmt :: struct {
  using node: Stmt,
  open: tok.Pos,
  stmts: []^Stmt,
  close: tok.Pos,
}

// Expressions
// 
// Expressions are anything that can represent something,
// 
// `name()` is an expression for calling a function
// 
// `function name() {}` is a function declaration expression

Identifier :: struct {
  using node: Expr,
  name: string
}

Basic_Lit :: struct {
  using node: Expr,
  token: tok.Token
}

// ( ... )
Paren_Expr :: struct {
  using node: Expr,
  open: tok.Pos,
  expr: ^Expr,
  close: tok.Pos
}


Style_Expr :: struct {
  using node: Expr,
  type: ^Style_Type,
  body: ^Stmt,
}

// only wants an expression to follow
Unary_Expr :: struct {
  using node: Expr,
  op: tok.Token,
  expr: ^Expr
}
Binary_Expr :: struct {
	using node: Expr,
	left:  ^Expr,
	op:    tok.Token,
	right: ^Expr,
}


Style_Type :: struct {
  using node: Expr,
  token: tok.Token,
  selectors: ^Selector_List,
}

Selector_Kind :: enum {
	Element,
	Class,
	Id,
	Data,
}
// a single value for a parameter, return value or arg
Selector :: struct {
  using node: Node,
  name: []^Expr,
  type: Selector_Kind,
  default: ^Expr,
}

// A Field List contains an array of fields, used for function parameters, return values
// or arguments
Selector_List :: struct {
  using node: Node,
  // position where the field list starts
  // 
  // Dictated by an OPEN token
  open: tok.Pos,
  // fields within the field list
  list: []^Selector,
  // Dictated by a CLOSED token
  close: tok.Pos
}

// Declarations

Value_Decl :: struct {
  // i dont actually know what this does, will learn later
  attributes: [dynamic]^Attribute,
  names: []^Expr,
  type: ^Expr,
  values: []^Expr,
}

// Other

Attribute :: struct {
  using node: Node,
  token: tok.TOKEN_KIND,
  open: tok.Pos,
  elems: []^Expr,
  close: tok.Pos
}

// Types


new_from_pos :: proc($T: typeid, pos, end: tok.Pos) -> ^T {
  node, _ := mem.new(T)
  n.pos = pos
  n.end = end
  n.derived = n
  base: ^Node = n

  when intrinsics.type_has_field(T, "derived_expr") {
    n.derived_expr = n
  }
  
  when intrinsics.type_has_field(T, "derived_stmt") {
    n.derived_stmt = n
  }

  return n
}

new_from_pos_and_end :: proc($T: typeid, pos: tok.Pos, end: ^Node) -> ^T {
  return new(T, pos, end != nil ? end.end : pos)
}

new :: proc {
  new_from_pos,
  new_from_pos_and_end
}