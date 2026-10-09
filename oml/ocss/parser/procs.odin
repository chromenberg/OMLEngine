package parser

import "core:fmt"
import tok "../tokenizer"
import ast "../ast"

AST_Flag :: enum {
	Simple,
	Detailed,
	NodeOnly,
	Bars,
}
AST_Flags :: bit_set[AST_Flag]

// format_ast prints the abstract tree, one node per line.
//
// Flags:
//   .Simple   - concise summary (default when .Detailed is not set)
//   .Detailed - include source positions and token kind details
//   .NodeOnly - do not recurse into child nodes
//   .Bars     - draw tree connectors (│, ├─, └─) instead of plain indentation
format_ast :: proc(tree: ^Abstract_Tree, flags: AST_Flags) {
	if tree == nil {
		fmt.println("<nil tree>")
		return
	}

	detailed := .Detailed in flags
	bars := .Bars in flags

	if tree.path != "" {
		fmt.printfln("%s (%s)", tree.name, tree.path)
	} else {
		fmt.printfln("%s", tree.name)
	}

	for rule, i in tree.rules {
		print_ast_node(rule, flags, "", i == len(tree.rules)-1, detailed, bars)
	}
}

@(private="file")
print_ast_node :: proc(node: ^ast.Node, flags: AST_Flags, prefix: string, is_last, detailed, bars: bool) {
	print_branch(prefix, is_last, bars)
	if node == nil {
		fmt.println("<nil>")
		return
	}
	print_node_info(node, detailed)
	fmt.println()

	if .NodeOnly in flags {
		return
	}

	next_prefix := child_prefix(prefix, is_last, bars)

	switch n in node.derived {
	case ^ast.Rule:
		child_count := len(n.selectors) + (n.inner != nil ? 1 : 0)
		i := 0
		for sel in n.selectors {
			print_selector_list(sel, flags, next_prefix, i == child_count-1, detailed, bars)
			i += 1
		}
		if n.inner != nil {
			print_block(n.inner, flags, next_prefix, true, detailed, bars)
		}

	case ^ast.Selector_List:
		for child, i in n.inner {
			print_ast_node(child, flags, next_prefix, i == len(n.inner)-1, detailed, bars)
		}

	case ^ast.Grouped_Selector:
		for sel, i in n.selectors {
			print_selector(sel, flags, next_prefix, i == len(n.selectors)-1, detailed, bars)
		}

	case ^ast.Block:
		for child, i in n.inner {
			print_ast_node(child, flags, next_prefix, i == len(n.inner)-1, detailed, bars)
		}

	case ^ast.Selector:
		// leaf node, no children

	case ^ast.Declaration:
		// leaf node, no children
	}
}

@(private="file")
print_selector_list :: proc(list: ^ast.Selector_List, flags: AST_Flags, prefix: string, is_last, detailed, bars: bool) {
	print_ast_node(list, flags, prefix, is_last, detailed, bars)
}

@(private="file")
print_grouped_selector :: proc(group: ^ast.Grouped_Selector, flags: AST_Flags, prefix: string, is_last, detailed, bars: bool) {
	print_ast_node(group, flags, prefix, is_last, detailed, bars)
}

@(private="file")
print_selector :: proc(sel: ^ast.Selector, flags: AST_Flags, prefix: string, is_last, detailed, bars: bool) {
	print_ast_node(sel, flags, prefix, is_last, detailed, bars)
}

@(private="file")
print_block :: proc(block: ^ast.Block, flags: AST_Flags, prefix: string, is_last, detailed, bars: bool) {
	print_ast_node(block, flags, prefix, is_last, detailed, bars)
}

@(private="file")
print_branch :: proc(prefix: string, is_last, bars: bool) {
	if bars {
		if is_last {
			fmt.printf("%s└─ ", prefix)
		} else {
			fmt.printf("%s├─ ", prefix)
		}
	} else {
		fmt.printf("%s- ", prefix)
	}
}

@(private="file")
child_prefix :: proc(prefix: string, is_last, bars: bool) -> string {
	if bars {
		if is_last {
			return fmt.tprintf("%s   ", prefix)
		} else {
			return fmt.tprintf("%s│  ", prefix)
		}
	}
	return fmt.tprintf("%s  ", prefix)
}

@(private="file")
print_node_info :: proc(node: ^ast.Node, detailed: bool) {
	switch n in node.derived {
	case ^ast.Rule:             print_rule_info(n, detailed)
	case ^ast.Selector_List:    print_selector_list_info(n, detailed)
	case ^ast.Grouped_Selector: print_grouped_selector_info(n, detailed)
	case ^ast.Selector:         print_selector_info(n, detailed)
	case ^ast.Block:            print_block_info(n, detailed)
	case ^ast.Declaration:      print_declaration_info(n, detailed)
	}
}

@(private="file")
print_pos :: proc(pos, end: tok.Pos) {
	fmt.printf(" [%d:%d-%d:%d]", pos.line, pos.column, end.line, end.column)
}

@(private="file")
print_rule_info :: proc(r: ^ast.Rule, detailed: bool) {
	if detailed {
		fmt.printf("Rule(selectors=%d)", len(r.selectors))
		print_pos(r.pos, r.end)
	} else {
		fmt.printf("Rule")
	}
}

@(private="file")
print_selector_list_info :: proc(s: ^ast.Selector_List, detailed: bool) {
	if detailed {
		fmt.printf("Selector_List(selectors=%d)", len(s.inner))
		print_pos(s.pos, s.end)
	} else {
		fmt.printf("Selector_List")
	}
}

@(private="file")
print_grouped_selector_info :: proc(g: ^ast.Grouped_Selector, detailed: bool) {
	if detailed {
		fmt.printf("Grouped_Selector(selectors=%d)", len(g.selectors))
		print_pos(g.pos, g.end)
	} else {
		fmt.printf("Grouped_Selector")
	}
}

@(private="file")
print_selector_info :: proc(s: ^ast.Selector, detailed: bool) {
	if detailed {
		fmt.printf("Selector(kind=%s, name=%s %q)", selector_kind_string(s.kind), tok.TOKENS[s.name.kind], s.name.text)
		print_pos(s.pos, s.end)
	} else {
		fmt.printf("Selector(%s %q)", selector_kind_string(s.kind), s.name.text)
	}
}

@(private="file")
print_block_info :: proc(b: ^ast.Block, detailed: bool) {
	if detailed {
		fmt.printf("Block(nodes=%d)", len(b.inner))
		print_pos(b.pos, b.end)
	} else {
		fmt.printf("Block")
	}
}

@(private="file")
print_declaration_info :: proc(d: ^ast.Declaration, detailed: bool) {
	if detailed {
		fmt.printf("Declaration(name=%s %q, value=%s %q)", tok.TOKENS[d.name.kind], d.name.text, tok.TOKENS[d.value.kind], d.value.text)
		print_pos(d.pos, d.end)
	} else {
		fmt.printf("Declaration(%s: %s)", d.name.text, d.value.text)
	}
}

@(private="file")
selector_kind_string :: proc(kind: ast.Selector_Kind) -> string {
	switch kind {
	case .Id:      return "id"
	case .Class:   return "class"
	case .Element: return "element"
	}
	return "unknown"
}

extract_ast :: proc(p: ^Parser) -> Abstract_Tree {
	tree := new_clone(p.doc)
	// fmt.printfln("%#v", tree)
	// free_all(p.allocator)
	return Abstract_Tree{
		name = p.tok.file,
		rules = p.doc
	}
}
