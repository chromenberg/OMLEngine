package oml

import "core:strconv"
import "core:strings"
import "core:fmt"
apply_style :: proc(n: ^Node, r: ^CSS_Rule) {

}

parse_type :: proc(n: ^Sizing_Value, d: string) {
	value := strings.trim_space(d)

	switch {
	case strings.ends_with(value, "%"):
		n.type = .Percent
		n.val, _ = strconv.parse_f32(value[:len(value)-1])
	case strings.ends_with(value, "px"):
		n.type = .Absolute
		n.val, _ = strconv.parse_f32(value[:len(value)-2])
	case value == "grow":
		n.type = .Auto
		n.val = 0
	case:
		n.type = .Absolute
		n.val, _ = strconv.parse_f32(value)
	}
}

parse_hex_byte :: proc(text: string) -> (u8, bool) {
  value, ok := strconv.parse_int(text, 16)
  if !ok do return 0, false
  return u8(value), true
}

parse_color :: proc(value: string) -> Color {
	hex := strings.trim_space(value)
	if !strings.starts_with(hex, "#") do return {}

	hex = hex[1:]

	switch len(hex) {
	case 3:
		r, r_ok := parse_hex_byte(hex[0:1])
		g, g_ok := parse_hex_byte(hex[1:2])
		b, b_ok := parse_hex_byte(hex[2:3])
		if !r_ok || !g_ok || !b_ok do return {}
		return {f32(r) * 17, f32(g) * 17, f32(b) * 17, 255}

	case 6:
		r, r_ok := parse_hex_byte(hex[0:2])
		g, g_ok := parse_hex_byte(hex[2:4])
		b, b_ok := parse_hex_byte(hex[4:6])
		if !r_ok || !g_ok || !b_ok do return {}
		return {f32(r), f32(g), f32(b), 255}

	case 8:
		r, r_ok := parse_hex_byte(hex[0:2])
		g, g_ok := parse_hex_byte(hex[2:4])
		b, b_ok := parse_hex_byte(hex[4:6])
		a, a_ok := parse_hex_byte(hex[6:8])
		if !r_ok || !g_ok || !b_ok || !a_ok do return {}
		return {f32(r), f32(g), f32(b), f32(a)}
	}

	return {}
}

set_declaration :: proc(n: ^Node, d: ^CSS_Declaration) {
	switch d.name {
	case "width":
		parse_type(&n.style.sizing.width, d.value)
	case "height":
		parse_type(&n.style.sizing.height, d.value)

	case "padding":
		// this needs to be allocated using the documents allocator as this creates a large memory leak
		vals := strings.split(d.value, " ")
		switch len(vals) {
		case 1:
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[0])
			parse_type(&n.style.layout.padding.right,  vals[0])
		case 2:
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.bottom, vals[0])
			parse_type(&n.style.layout.padding.left,   vals[1])
			parse_type(&n.style.layout.padding.right,  vals[1])
		case 4:
			parse_type(&n.style.layout.padding.top,    vals[0])
			parse_type(&n.style.layout.padding.right,  vals[1])
			parse_type(&n.style.layout.padding.bottom, vals[2])
			parse_type(&n.style.layout.padding.left,   vals[3])
		}

	case "margin":
		vals := strings.split(d.value, " ")
		switch len(vals) {
		case 1:
			parse_type(&n.style.layout.margin.top,    vals[0])
			parse_type(&n.style.layout.margin.bottom, vals[0])
			parse_type(&n.style.layout.margin.left,   vals[0])
			parse_type(&n.style.layout.margin.right,  vals[0])
		case 2:
			parse_type(&n.style.layout.margin.top,    vals[0])
			parse_type(&n.style.layout.margin.bottom, vals[0])
			parse_type(&n.style.layout.margin.left,   vals[1])
			parse_type(&n.style.layout.margin.right,  vals[1])
		case 4:
			parse_type(&n.style.layout.margin.top,    vals[0])
			parse_type(&n.style.layout.margin.right,  vals[1])
			parse_type(&n.style.layout.margin.bottom, vals[2])
			parse_type(&n.style.layout.margin.left,   vals[3])
		}

	case "direction":
		switch d.value {
		case "row", "horizontal":   n.style.layout.direction = .Horizontal
		case "column", "vertical": n.style.layout.direction = .Vertical
		}

	case "gap":
		n.style.layout.gap, _ = strconv.parse_f32(d.value)

	case "background-color":
		n.style.has_bg = true
		n.style.background_color = parse_color(d.value)

	case "color":
		n.style.color = parse_color(d.value)

	case "border-width":
		v: Sizing_Value
		parse_type(&v, d.value)
		n.style.border.width = {v, v, v, v}
		n.style.has_border = true

	case "border-color":
		n.style.border.color = parse_color(d.value)
		n.style.has_border = true

	case "corner-radius":
		n.style.radius, _ = strconv.parse_f32(d.value)

	case "opacity":
		n.style.opacity, _ = strconv.parse_f32(d.value)
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
	if n == nil do return

	for sheet in d.loaded_styles {
		for rule in sheet.rules {
			for selec in rule.selectors {
				for comp in selec.parts {
					if all_names_match(n, comp.simples) {
						for decl in rule.declarations {
							set_declaration(n, decl)
						}
					}
				}
			}
		}
	}

	for child in n.children do find_styles(d, child)
}

make_render_tree :: proc(d: ^Document) {
	for sheet in d.loaded_styles {
		for node in sheet.rules {

		}
	}
}
