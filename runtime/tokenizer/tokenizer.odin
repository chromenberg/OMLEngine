package tokenizer

import "core:unicode"
import "core:log"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:mem"

Tokenizer :: struct {
	allocator: mem.Allocator,
	file: string,
	source: string,

	// we could get away with using a pointer to ensure no weird leaks
	// however trying to print this would result in some issues
	tokens: [dynamic]Token,
	// the offset the cursor has relative to the current "line"
	line_offset: int,
	line_count: int,
	read_offset: int,
	// the total offset of the cursor
	offset: int,
	current: rune,
}

is_token :: proc(text: string) -> bool{
	for token in TOKENS {
		if text == token do return true
	}
	return false
}

create_token :: proc(t: ^Tokenizer, text: string, line: int, column: int) {
	token : Token
	token.kind = get_kind(text)
	token.pos.line = line
	token.pos.column = column
	append(&t.tokens, token)
}

advance_rune :: proc(t: ^Tokenizer) {
	fmt.println(t.read_offset, len(t.source))
	if t.read_offset < len(t.source) {
		t.offset = t.read_offset

		if t.current == '\n' {
			// the current line is this far into the string
			t.line_offset = t.offset
			t.line_count += 1
		}

		r, width := rune(t.source[t.read_offset]), 1

		t.read_offset += width
		t.current = r
	} else {
		t.offset = len(t.source)

		if t.current == '\n' {
			// the current line is this far into the string
			t.line_offset = t.offset
			t.line_count += 1
		}

		// no more chars left
		t.current = -1
	}
}

skip_whitespace :: proc(t: ^Tokenizer) {
	for {
		switch t.current {
			case ' ', '\t', '\r', '\n':
				fmt.println("skip")
				advance_rune(t)
			case:
				return
		}
	}
}

is_letter :: proc(r: rune) -> bool {
	if r < utf8.RUNE_SELF {
		switch r {
		case '_', '-':
			return true
		case 'A'..='Z', 'a'..='z':
			return true
		}
	}
	return unicode.is_letter(r)
}
is_digit :: proc(r: rune) -> bool {
	if '0' <= r && r <= '9' {
		return true
	}
	return unicode.is_digit(r)
}

read_string :: proc(t: ^Tokenizer) -> string {
	offset := t.offset-1

	// keep reading until we find another string literal token
	for {
		current := t.current
		// if newline or ran out of chars then string not terminated
		if current == '\n' || current < 0 {
			log.errorf("string literal @[line:column] was not terminated")
			break
		}
		advance_rune(t)
		if current == '"' {
			break
		}
	}

	return string(t.source[offset : t.offset])
}

read_identifier :: proc(t: ^Tokenizer) -> string {
	offset := t.offset

	for is_letter(t.current) || is_digit(t.current) {
		advance_rune(t)
	}

	return string(t.source[offset:t.offset])
}

is_class :: proc(t: ^Tokenizer) -> bool {
	if !is_letter(t.current) || !is_digit(t.current) || t.current != '_' {
		return false
	}
	return !is_letter(t.current) || !is_digit(t.current) || t.current != '_'
}

scan :: proc(t: ^Tokenizer) -> Token {
	skip_whitespace(t)

	offset := t.offset
	kind: TOKEN_KIND
	text: string
	pos := offset_to_pos(t, offset)

	switch current := t.current; true {
		case is_letter(current):
			text = read_identifier(t)
			kind = .Identifier
		case:
			advance_rune(t)
			switch current {
				case -1:  kind = .EOF
				case '"': 
				  kind = .String
					text = read_string(t)
				case '{': kind = .Open_Brace
				case '}': kind = .Close_Brace
				case '(': kind = .Open_Paren
				case ')': kind = .Close_Paren
				case '[': kind = .Open_Bracket
				case ']': kind = .Close_Bracket
				case ';': kind = .Semicolon
				case ':': kind = .Colon
					// these need a check
				case '.': kind = .Period
				case '#': kind = .Hash
			}
	}

	if text == "" {
		text = string(t.source[offset : t.offset])
	}
	
	token := Token{kind, text, pos}
	if token.kind != .Invalid {
		append(&t.tokens, token)
	}

	return token
}

init :: proc(t: ^Tokenizer, source: Maybe(string)) {
  if source != nil {
    t.file = source.(string)
  }
	file_bytes, read_err := os.read_entire_file(t.file, context.allocator)
	file_data := strings.clone_from_bytes(file_bytes, context.allocator)
	defer delete(file_data)
	delete(file_bytes)
	t.source = file_data
	
}
