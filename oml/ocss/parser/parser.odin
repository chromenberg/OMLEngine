package parser

import "core:mem"
import "core:fmt"
/*
// correct single class
.header {
	color: red;
	background: #ffffff;
}

// correct parent and child
.header .child {
	color: red;
	background: #ffffff;
}

.header {
	color red;
}

.header {
	color: red
	background: 1;
}

#id.header {
	color: green;
}
*/

import "../tokenizer"
import "../ast"

Warn_Handler :: #type proc(pos: tokenizer.Pos, fmt: string, args: ..any)
Error_Handler :: #type proc(pos: tokenizer.Pos, fmt: string, args: ..any)

Parser_Scope :: enum {
	File,
	Rule,
}

Parser :: struct {
	allocator: mem.Allocator,
	tok: tokenizer.Tokenizer,

	trail: tokenizer.Token,
	cursor: tokenizer.Token,

	inside: ^ast.Node,
	doc: [dynamic]^ast.Node,

	peeking: bool,

	warn: Warn_Handler,
	err: Error_Handler,
	err_count: int,
	warn_count: int,
}

Abstract_Tree :: struct {
	path: string,
	name: string,

	rules: [dynamic]^ast.Node,
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
	p.err_count += 1
  if p.err != nil {
    p.err(pos, msg, ..args)
  }

  if p.err_count > 50 {
  	panic("error count exceeded limit")
  }
}

next_token :: proc(p: ^Parser) -> bool {
  p.cursor = tokenizer.scan(&p.tok)
  if p.cursor.kind == .Invalid {
  	err(p, p.cursor.pos, "[%d:%d] Invalid token found | Contents: '%v'",
   			p.cursor.pos.line, p.cursor.pos.column, p.cursor.text)
   	return false
  }
  if p.cursor.kind == .EOF {
    return false
  }
  return true
}

advance_token :: proc(p: ^Parser) -> tokenizer.Token {
  p.trail = p.cursor // move the current token back
  prev := p.trail

	next_token(p)
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
  prev := p.cursor
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


update_inside :: proc(p: ^Parser) {
	// ast.new(ast.Rule, p.cursor.pos)
}
parse_selector :: proc(p: ^Parser) -> ^ast.Selector {
	symbol := p.cursor
 advance_token(p)

	// advance_token(p)
	#partial switch symbol.kind {
		// TODO: Stop this overriding every selector
		// case .Identifier:
		// 	selector := ast.new(ast.Selector, p.cursor.pos, get_end_pos(p.cursor), p.allocator)
		// 	// fmt.println("iden")

		// 	selector.kind = ast.Selector_Kind.Element
		// 	selector.name = p.cursor

		// 	return selector
		case .Period:
			// we want .<ident> to occur

			ident := expect(p, .Identifier)
			// fmt.println(".")
			selector := ast.new(ast.Selector, symbol.pos, get_end_pos(ident), p.allocator)
			selector.kind = ast.Selector_Kind.Class
			selector.name = ident

			return selector
		case .Hash:
			// we want .<ident> to occur
			ident := expect(p, .Identifier)
			// fmt.println("#")

			selector := ast.new(ast.Selector, symbol.pos, get_end_pos(ident), p.allocator)
			selector.kind = ast.Selector_Kind.Id
			selector.name = ident

			return selector
	}
	// fmt.println(".")
	// advance_token(p)

	return nil
}

parse_selector_list :: proc(p: ^Parser) -> ^ast.Selector_List {
	start := p.cursor
	selectors := ast.new(ast.Selector_List, start.pos, get_end_pos(p.cursor), p.allocator)

	for p.cursor.kind != .Open_Brace && p.cursor.kind != .Close_Paren && p.cursor.kind != .EOF {
		selector := parse_selector(p)
		if selector == nil do break
		append(&selectors.inner, selector)
	}

	return selectors
}

parse_property :: proc(p: ^Parser) -> ^ast.Declaration {
	start := p.cursor

	ident := expect(p, .Identifier) // Prop name
	expect(p, .Colon)               // ':'

	value := p.cursor               // first value token
	last := value
	for p.cursor.kind != .Semicolon && p.cursor.kind != .Close_Brace && !at_eof(p) && p.cursor.kind != .Invalid {
		advance_token(p)
		last = p.trail
	}
	value.text = p.tok.source[value.pos.offset:get_end_pos(last).offset]

	end := last
	if p.cursor.kind == .Semicolon {
		end = expect(p, .Semicolon)
	}

	prop := ast.new(ast.Declaration, start.pos, get_end_pos(end), p.allocator)
	prop.name = ident
	prop.value = value

	return prop
}

parse_block :: proc(p: ^Parser) -> ^ast.Block {
	start := p.cursor
	contents : [dynamic]^ast.Node

	for {
		if p.cursor.kind == .Close_Brace || at_eof(p) do break
		prop := parse_property(p)
		if prop != nil {
			append(&contents, prop)
		}
	}

	block := ast.new(ast.Block, start.pos, get_end_pos(p.cursor), p.allocator)
	block.open = start.pos
	block.inner = contents
	block.close = p.cursor.pos

	return block
}

parse_rule :: proc(p: ^Parser) -> ^ast.Rule {
	start := p.cursor
	advance_token(p)
	#partial switch p.cursor.kind {
		case .Open_Paren:
			advance_token(p) // consume '('

			list := parse_selector_list(p)
			expect(p, .Close_Paren)
			expect(p, .Open_Brace)

			block := parse_block(p)
			close_brace := expect(p, .Close_Brace)

			rule := ast.new(ast.Rule, start.pos, get_end_pos(close_brace), p.allocator)

			rule.inner = block
			append(&rule.selectors, list)
			return rule
	}
	return nil
}

parse :: proc(p: ^Parser, file: string) {
	alloc : mem.Scratch

	mem.scratch_allocator_init(&alloc, 2_000)
	p.allocator = mem.scratch_allocator(&alloc)

  tokenizer.init(&p.tok,file)
  if p.tok.current <= 0 {
    // tokenizer is still tokenizing or failed to complete and set cursor to -1
    // fmt.println("still tokenizing")
    return
  }
  advance_token(p)
	for {
		if at_eof(p) do break
		if p.cursor.kind == .Rule {
			rule := parse_rule(p)
			append(&p.doc, rule)
		}

	}
}
