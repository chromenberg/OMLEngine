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

parse_value :: proc(p: ^Parser) -> ^ast.Expr {
  return nil
}

// parses a list of elements within a brace
parse_elem_list :: proc(p: ^Parser) -> []^ast.Expr {
  elems: [dynamic]^ast.Expr

  for p.curr_token.kind != .Close_Brace && p.curr_token.kind != .EOF {
    // elem := parse_value(p)
  }

  return elems[:]
}

parse_literal_value :: proc(p: ^Parser, type: ^ast.Expr) {
  elems: []^ast.Expr
  open := expect(p, .Open_Brace)
  if p.curr_token.kind != .Close_Brace {
    elems = parse_elem_list(p)
  }
}

parse_atom_value :: proc(p: ^Parser, value: ^ast.Expr, lhs: bool) -> (operand: ^ast.Expr) {
  operand = value
  loop := true
	is_lhs := lhs

	for loop {
	
	}
	
	return operand
}

// parses into a basic expression
parse_operand :: proc(p: ^Parser, lhs: bool) -> ^ast.Expr {
  #partial switch p.curr_token.kind {
    case .Identifier:
      return parse_identifier(p)
    case .Integer, .Float, .String:
      tok := advance_token(p)
      basic_lit := ast.new(ast.Basic_Lit, tok.pos, get_end_pos(tok))
      basic_lit.token = tok
      return basic_lit
    case:
      return nil
  }
}

parse_unary_expression :: proc(p: ^Parser, lhs: bool) -> ^ast.Expr {
  #partial switch p.curr_token.kind {
    case .Add, .Sub:
      op := advance_token(p)
      expression := parse_unary_expression(p, lhs)
      
      unary_expr := ast.new(ast.Unary_Expr, op.pos, expression)
      unary_expr.op = op
      unary_expr.expr = expression
      
      return unary_expr
    // case .Increment, .Decrement:
    //   op := advance_token(p)
    //   expression := parse_unary_expression(p, lhs)

    //   unary_expr := ast.new(ast.Unary_Expr, op.pos, expression)
    //   unary_expr.op = op
    //   unary_expr.expr = expression
    //   return unary_expr
  }
  return nil
}

parse_binary_expression :: proc(p: ^Parser, lhs: bool, prec_in: int) -> ^ast.Expr {
  start_pos := p.curr_token.pos
  expression := parse_unary_expression(p, lhs)

  for prec := token_precedence(p, p.curr_token.kind); prec >= prec_in; prec -= 1 {
    loop: for {
      op := p.curr_token
      op_prec := token_precedence(p, op.kind)

      if op_prec != prec {
        break loop
      }
      
      right := parse_binary_expression(p, false, prec+1)
      if right == nil {
        err(p, op.pos, "f")
      }
      binary_expr := ast.new(ast.Binary_Expr, expression.pos, get_end_pos(p.prev_token))
      binary_expr.left = expression
      binary_expr.op = op
      binary_expr.right = right

      expression = binary_expr
    }
  }

  return expression
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

