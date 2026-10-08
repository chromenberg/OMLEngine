package parser

import "base:runtime"
import "core:fmt"
import "core:mem"
import tok "../tokenizer"

Parser :: struct {
	allocator  : mem.Allocator,
	path			 : string,
	tokenizer  : ^tok.Tokenizer,
	lookahead  : tok.Token,
	current 	 : tok.Token,
	index			 : int,
	parse_state: Parser_State,
	states 		 : [dynamic]Rule_State,
	state			 : Rule_State,
	stack			 : [dynamic]tok.Token,
	model			 : [dynamic]Structure,
	finish     : bool `false`
}

Parser_State :: enum {
	ERROR,
	SHIFT,
	REDUCE,
	STOP
}

Rule_State :: enum {
	In_Paren,
	In_Brace,
	In_Bracket,
	In_Declaration,
	In_Property,
}

ParserRule :: []bit_set[tok.TOKEN_KIND]

Parser_Rule_Kind:: enum u32 {
	Property_Requirement,

	COUNT,
}

Parser_Low_Level_Rule_Kinds :: enum {
	Declaration,
	Property
}

Parser_Rules := [Parser_Rule_Kind.COUNT]ParserRule{
	{{.Period, .Hash}, {.Identifier}},
}

advance_token :: proc(p: ^Parser) {
	if p.index >= len(p.tokenizer.tokens) {
		p.finish = true
		return
	}
	p.current = p.lookahead
	p.index += 1
	if p.index+1 < len(p.tokenizer.tokens) {
		p.lookahead = p.tokenizer.tokens[p.index+1]
	} else {
		// p.lookahead =
	}

}

add_to_stack :: proc(p: ^Parser, state: Rule_State) {
	p.state = state
	append(&p.states, state)
}
remove_from_stack :: proc(p: ^Parser) {
	if p.states[len(p.states)] != p.state do panic("Malformed .ocss file data")
	pop(&p.states)
}
peek_states :: proc(p: ^Parser) -> Rule_State {
	return p.states[len(p.states)-1]
}
is_state :: proc(p: ^Parser, state: Rule_State) -> bool {
	return state == p.state && len(p.states)>0
}

scan_rules :: proc(p: ^Parser) {
	done:=false
	for rule, i in Parser_Rules {
		fmt.println(rule, p.current.kind, p.lookahead.kind)
		if len(rule) == 0 || done do continue
	}
}

reduce_stack :: proc(p: ^Parser) {
	s: Structure
	for {
		if len(p.stack) == 0 do break
		sem: Semantic
		sem.data = pop(&p.stack)
		append(&s.data, sem)
	}

}

update_states :: proc(p: ^Parser) {
	#partial switch p.current.kind {
		case .Open_Paren:
			add_to_stack(p, .In_Paren)
		case .Close_Paren:
			remove_from_stack(p)
	}
}

scan_tokens :: proc(p: ^Parser) {
	index := p.index
	current := p.current
	lookahead := p.lookahead

	update_states(p)
	append(&p.stack, p.current)

	fmt.println(current, p.state)

	if current.kind == .EOF {
		p.finish=true
		return
	}



	advance_token(p)
}

Semantic_Kind :: enum {

}

Semantic :: struct {
	data: tok.Token,
	type: Semantic_Kind,
}

Structure_Kind :: enum {
	Declaration,
	Property,
	Value,
}

Structure :: struct {
	kind: Parser_Rule_Kind,
	data: [dynamic]Semantic,
	parent: ^Structure,
	child: [dynamic]^Structure,
}

parse :: proc(p: ^Parser) {
	p.allocator = runtime.heap_allocator()
	p.tokenizer = new(tok.Tokenizer)
	p.tokenizer.file = p.path
	defer free(p.tokenizer)

	tok.tokenize_file(p.tokenizer)

	tokens := p.tokenizer.tokens
	p.index = 0
	p.current = tokens[p.index]
	p.lookahead = tokens[p.index+1]

	for !p.finish {
		scan_tokens(p)
	}
}
