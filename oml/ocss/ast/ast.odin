package ast

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