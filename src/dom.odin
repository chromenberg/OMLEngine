package oml

import "core:strconv"
import "core:strings"
import "core:fmt"
apply_style :: proc(n: ^Node, r: ^CSS_Rule) {

}

parse_type :: proc(n: ^Sizing_Value, d: string) {
	// fmt.printfln("%v, %v",n, d)
	if strings.ends_with(d, "%") {
		n.val, _ = strconv.parse_f32(d)
		n.type = .Percent
	}
}

set_declaration :: proc(n: ^Node, d: ^CSS_Declaration) {
	// fmt.printfln("%v",d.name)
	
	switch d.name {
	case "width": 
		n.style.sizing.width.val = 234
		parse_type(&n.style.sizing.width, d.value)
	case "height": parse_type(&n.style.sizing.height, d.value)
	case "padding": 
		vals := strings.split(d.value, " ")
		if len(vals) == 1 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[0])
			parse_type(&n.style.layout.padding.right,  vals[0])
		}
		if len(vals) == 2 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[1])
			parse_type(&n.style.layout.padding.right,  vals[1])
		}
		if len(vals) == 4 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[1])
			parse_type(&n.style.layout.padding.left,   vals[2])
			parse_type(&n.style.layout.padding.right,  vals[3])
		}
	case "margin":
		vals := strings.split(d.value, " ")
		if len(vals) == 1 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[0])
			parse_type(&n.style.layout.padding.right,  vals[0])
		}
		if len(vals) == 2 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[1])
			parse_type(&n.style.layout.padding.right,  vals[1])
		}
		if len(vals) == 4 {
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[1])
			parse_type(&n.style.layout.padding.left,   vals[2])
			parse_type(&n.style.layout.padding.right,  vals[3])
		}
	case "direction":
		switch d.value {
		case "horizontal": n.style.layout.direction = .Horizontal
		case "vertical": n.style.layout.direction = .Vertical
		}
	case "gap":
		n.style.layout.gap, _ = strconv.parse_f32(d.value)
	}
}

all_names_match :: proc(n: ^Node, s: [dynamic]^CSS_Simple_Selector) -> bool {
	matches := 0
	for sel in s {
		#partial switch sel.kind {
		case .Class:
			for c in n.class {
				if sel.value == c do matches += 1
			}
		case .Id:
			if sel.value == n.id do matches += 1
		}
	}
	return matches == len(s[:])
}

find_styles :: proc(d: ^Document, n: ^Node) {
	for sheet in d.loaded_styles {
		for node in sheet.rules {
			for selec in node.selectors {
				// fmt.printfln("checking selector: %v : %#v", selec.specificity, selec.parts[:], )
				for comp in selec.parts {
					state := all_names_match(n, comp.simples)
					if state {
						for decl in node.declarations {
							set_declaration(n, decl)
						}
					}
					// fmt.printfln("%#v : %v", node, all_names_match(n, comp.simples))
				}
			}
		}
	}
}

make_render_tree :: proc(d: ^Document) {
	for sheet in d.loaded_styles {
		for node in sheet.rules {

		}
	}
}
