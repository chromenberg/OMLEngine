package ast

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
  
}

Any_Expr :: union {
  
}

Any_Stmt :: union {
  
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

// Expressions

// Declarations

Value_Decl :: struct {
  
}

