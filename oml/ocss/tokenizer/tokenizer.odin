/*
  Credits to GingerBill and the Odin team.
  `core:odin/tokenizer` is the reference for making this while learning

  Tokenizer for the .OCSS file format
*/

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
	// fmt.println(t.read_offset, len(t.source))
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

// returns the contents between the start position of a token and the read head pos
stringify :: proc(t: ^Tokenizer, start_pos: int) -> string {
  return string(t.source[start_pos:t.offset])
}

peek_byte :: proc(t: ^Tokenizer, lookahead := 0) -> byte {
  // ensure we are reading within the bounds of the source file
  if t.read_offset+lookahead < len(t.source) {
    return t.source[t.read_offset+lookahead]
  }
  return 0
}

digit_val :: proc(char: rune) -> int {
  switch char {
  case '0'..='9':
    return int(char-'0')
  case 'A'..='F':
    return int(char-'A'+10)
  case 'a'..='f':
    return int(char-'a'+10)
  }

  return 16
}

scan_number :: proc(t: ^Tokenizer, seen_dec: bool) -> (TOKEN_KIND, string) {
  scan_mantissa :: proc(t: ^Tokenizer, base: int) {
    // if the current value is less than the base or is a seperator
    // then we can keep reading
    for digit_val(t.current) < base || t.current == '_' {
      advance_rune(t)
    }
  }

  scan_exponent :: proc(t: ^Tokenizer, kind: ^TOKEN_KIND) {
    if t.current == 'e' || t.current == 'E' {
      kind^ = .Float
      advance_rune(t)
      if t.current == '-' || t.current == '+' {
        advance_rune(t)
      }
      if digit_val(t.current) < 10 {
        scan_mantissa(t, 10)
      }
    }
  }

  scan_fraction :: proc(t: ^Tokenizer, kind: ^TOKEN_KIND) -> (exit_early: bool) {
    // have we found 1..?
    if t.current == '.' && peek_byte(t) == '.' {
      return true
    }
    if t.current == '.' {
      kind^ =.Float
      advance_rune(t)
      scan_mantissa(t, 10)
    }
    return false
  }

  offset := t.offset
  kind := TOKEN_KIND.Number
  seen_point := seen_dec

  if seen_point {
    kind = .Float
    scan_mantissa(t, 10)
    scan_exponent(t, &kind)
  } else {
    //
    if t.current == '0' {
      int_base :: proc(t: ^Tokenizer, kind: ^TOKEN_KIND, base: int) {
        prev := t.offset
        advance_rune(t)
        scan_mantissa(t, base)
        if t.offset - prev <= 1 {
          kind^ = .Invalid
        }
      }

      advance_rune(t)
      switch t.current {
      case: // not handling other types for now
        seen_point = false
        scan_mantissa(t, 10) // still in base-10

        if t.current == '.' { // have we found a float?
          seen_point = true
          if scan_fraction(t, &kind) {
            return kind, stringify(t, offset)
          }
        }

        scan_exponent(t, &kind)
        return kind, stringify(t, offset)
      }
    }
  }

  scan_mantissa(t, 10)

  if scan_fraction(t, &kind) {
    return kind, stringify(t, offset)
  }

  scan_exponent(t, &kind)

  return kind, stringify(t, offset)
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
			if text == "rule" {
				kind = .Rule
			}
		case '0' <= current && current <= '9':
		  kind, text = scan_number(t, false)
		case:
			advance_rune(t)
			switch current {
				case -1:  kind = .EOF
				case '"':
				  kind = .String
					text = read_string(t)
				case '.':
					kind = .Period
					switch t.current {
					case '0'..='9':
					  kind, text = scan_number(t, true)
					}
				case '{': kind = .Open_Brace
				case '}': kind = .Close_Brace
				case '(': kind = .Open_Paren
				case ')': kind = .Close_Paren
				case '[': kind = .Open_Bracket
				case ']': kind = .Close_Bracket
				case ';': kind = .Semicolon
				case ':': kind = .Colon
					// these need a check
				case '#':
					kind = .Hash
				case '%':
					kind = .Percent
				case ' ':
					kind = .Whitespace
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
	fmt.println("init")
  if source != nil {
    t.file = source.(string)
  }
  t.current = ' '
  file_bytes, read_err := os.read_entire_file(t.file, context.allocator)
	defer delete(file_bytes)

	file_data := strings.clone_from_bytes(file_bytes, context.allocator)
	// defer delete(file_data)

	t.source = file_data

	advance_rune(t)
	if t.current == utf8.RUNE_BOM {
		advance_rune(t)
	}
	fmt.println("finished")

}
