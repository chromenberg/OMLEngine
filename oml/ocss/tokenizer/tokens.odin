package tokenizer

TOKEN_KIND :: enum u32 {
	Invalid, 
	EOF,
	Comment,
	
	Literal_Start,
		Identifier,
		Whitespace,
		Number,
		String,
		// TODO: Hex? Pixel?
		// maybe other value types css has
	Literal_End,
	
	Operator_Start,
		Hash,
		Comma,					// ,
		Period,					// .

		Open_Paren,			// (
		Close_Paren,		// )
		Open_Bracket,		// [
		Close_Bracket,	// ]
		Open_Brace,			// {
		Close_Brace,		// }
		
		Colon,					// :
		Semicolon,			// ;
	Operator_End,

	Keyword_Start,
		Rule,
	Keyword_End,
	
	COUNT
}

TOKENS := [TOKEN_KIND.COUNT]string{
	"Invalid",
	"EOF",
	"Comment",

	"", // .Literal_Start
		"identifier",
		" ",
		"number",
		"string",
	"", // .Literal_End

	"", // .Operator_Start
		"#",
		",",
		".",
			
		"(",
		")",
		"[",
		"]",
		"{",
		"}",
		":",
		";",
	"", // .Operator_End

	"", // .Keyword_Start
		"rule",
	"", // .Keyword_End
}

Token :: struct {
	kind: TOKEN_KIND,
	text: string,
	pos: 	Pos
}

Pos :: struct {
	file:   string,
	offset: int, // 0
	line:   int, // 1
	column: int, // 1
}

is_literal :: proc(kind: TOKEN_KIND) -> bool {
	return .Literal_Start < kind && kind < .Literal_End 
}

is_operator :: proc(kind: TOKEN_KIND) -> bool {
	return .Operator_Start < kind && kind < .Operator_End 
}

is_keyword :: proc(kind: TOKEN_KIND) -> bool {
	return .Keyword_Start < kind && kind < .Keyword_End 
}

is_newline :: proc(tok: Token) -> bool {
	return tok.kind == .Semicolon && tok.text == "\n"
}

get_kind :: proc(text: string) -> TOKEN_KIND {
	// probably very inefficient
	for kind in TOKEN_KIND {
		if TOKENS[kind] == text do return kind
	}
	return .Invalid
}

offset_to_pos :: proc(t: ^Tokenizer, offset: int) -> Pos {
	line := t.line_count
	column := t.offset - t.line_offset + 1

	return Pos {
		file = t.file,
		column = column,
		line = line,
		offset = offset
	}
}