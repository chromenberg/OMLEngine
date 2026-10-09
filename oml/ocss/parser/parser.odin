package parser

import "base:runtime"
import "core:fmt"
import "core:mem"

import "../tokenizer"
import "../ast"

Warn_Handler :: #type proc(pos: tokenizer.Pos, fmt: string, args: ..any)
Error_Handler :: #type proc(pos: tokenizer.Pos, fmt: string, args: ..any)

Parser :: struct {
	path: string,
	tok: tokenizer.Tokenizer,
	
	warn: Warn_Handler,
	err: Error_Handler,
	err_count: int,
	
	prev_token: tokenizer.Token,
	curr_token: tokenizer.Token,

	curr_func: ^ast.Node,
}

default_warn_handler :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {
  fmt.eprintf("[%d:%d] Warning:", pos.line,pos.column)
  fmt.eprintfln(msg, ..args)
}

default_err_handler :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {
  fmt.eprintf("[%d:%d] Error:", pos.line,pos.column)
  fmt.eprintfln(msg, ..args)
}

warn :: proc(p: ^Parser, pos: tokenizer.Pos, msg: string, args: ..any) {
  if p.warn != nil {
    p.warn(pos, msg, ..args)
  }
}

err :: proc(p: ^Parser, pos: tokenizer.Pos, msg: string, args: ..any) {
  if p.err != nil {
    p.err(pos, msg, ..args)
  }
}

next_token :: proc(p: ^Parser) -> bool {
  p.curr_token = tokenizer.scan(&p.tok)
  if p.curr_token.kind == .EOF {
    return false
  }
  return true
}

advance_token :: proc(p: ^Parser) -> tokenizer.Token {
  p.prev_token = p.curr_token // move the current token back
  prev := p.prev_token

  if next_token(p) {
    #partial switch p.curr_token.kind {
      case .Semicolon:
        advance_token(p)
    }
  }
  return prev
}

get_end_pos :: proc(tok: tokenizer.Token) -> tokenizer.Pos {
  pos := tok.pos
  pos.offset += len(tok.text)
  pos.column += len(tok.text)
  return pos
}


// expect the next token to be a certain kind
expect :: proc(p: ^Parser, kind: tokenizer.TOKEN_KIND) -> tokenizer.Token {
  prev := p.curr_token
  // token was not what was wanted
  if prev.kind != kind {
    err(p, prev.pos, "Expected to get %s, got %s", kind, prev.kind)
  }
  // move to next token
  advance_token(p)
  return prev
}

at_eof :: proc(p: ^Parser) -> bool {
	return p.cursor.kind == .EOF
}

peek :: proc(p: ^Parser, lookahead := 0) -> tokenizer.Token {
	prev_parser := p^
	p.peeking = true

	defer {
		// rollback parser
		p^ = prev_parser
		p.peeking = false
	}

	for i := 0; i <= lookahead; i += 1 {
		advance_token(p)
	}
	return p.cursor
}

skip_possible_newline :: proc(p: ^Parser) -> bool {
	if tokenizer.is_newline(p.cursor) {
		advance_token(p)
		return true
	}
	return false
}

skip_possible_newline_for_literal :: proc(p: ^Parser) -> bool {
	curr_pos := p.cursor.pos
	if tokenizer.is_newline(p.cursor) {
		next := peek(p)
		if next.pos.line <= curr_pos.line+1 {
			#partial switch next.kind {
			case .Open_Brace:
				advance_token(p)
				return true
			}
		}
	}
	return false
}

  for p.curr_token.kind != .Close_Brace && p.curr_token.kind != .EOF {
    // elem := parse_value(p)
  }

  return elems[:]
}
parse_selector :: proc(p: ^Parser) -> ^ast.Selector {
	advance_token(p)
	#partial switch p.cursor.kind {
		case .Period:
			// we want .<ident> to occur
			ident := expect(p, .Identifier)
			fmt.println(".")
			selector := ast.new(ast.Selector, p.cursor.pos, get_end_pos(ident))
			selector.kind = ast.Selector_Kind.Class
			selector.name = ident

			return selector
		case .Hash:
			// we want .<ident> to occur
			ident := expect(p, .Identifier)
			fmt.println("#")

			selector := ast.new(ast.Selector, p.cursor.pos, get_end_pos(ident))
			selector.kind = ast.Selector_Kind.Id
			selector.name = ident

			return selector
		case .Identifier:
			selector := ast.new(ast.Selector, p.cursor.pos, get_end_pos(p.cursor))
			fmt.println("iden")

			selector.kind = ast.Selector_Kind.Element
			selector.name = p.cursor

			return selector
	}
	fmt.println(".")

	return nil
}

parse_selector_list :: proc(p: ^Parser) -> ^ast.Selector_List {
	start := p.cursor
	selectors := ast.new(ast.Selector_List, start.pos, get_end_pos(p.cursor))

	for p.cursor.kind != .Open_Brace && p.cursor.kind != .EOF {
		selector := parse_selector(p)
		fmt.println(selector)
		append(&selectors.inner, selector)
	}

	return selectors
}

parse_property :: proc(p: ^Parser) -> ^ast.Declaration {
	start := p.cursor

	ident := expect(p, .Identifier)	// Prop name
	c := expect(p, .Colon) 			//
	// for p.cursor.kind != .Semicolon && p.cursor.kind != .EOF {
	// }
	value := p.cursor
	advance_token(p)
	semi := expect(p, .Semicolon)
	prop := ast.new(ast.Declaration, start.pos, get_end_pos(p.cursor))
	
	prop.name = ident
	prop.value = value

	return prop
}

parse_expression :: proc(p: ^Parser, lhs: bool) -> ^ast.Expr {
  return parse_binary_expression(p, lhs, 0+1)
}

token_precedence :: proc(p: ^Parser, kind: tokenizer.TOKEN_KIND) -> int {
  #partial switch kind {
    case .Add, .Sub:
      return 6
    case .Mul, .Div, .Mod:
      return 7
  }
  return 0
}

parse_expression_list :: proc(p: ^Parser, lhs: bool) -> []^ast.Expr {
  expressions: [dynamic]^ast.Expr
  for {
    expression := parse_expression(p, lhs)
    append(&expressions, expression)
    if p.curr_token.kind != .Comma || p.curr_token.kind == .EOF {
      break
    }
    advance_token(p)
  }
  return expressions[:]
}

parse_file :: proc(p: ^Parser, file: string) -> bool {
  p.path = file
  tokenizer.init(&p.tok, p.path)
  if p.tok.current <= 0 {
    // tokenizer is still tokenizing or failed to complete and set cursor to -1
    return true
  }
  return false
} 

