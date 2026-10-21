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

// Resolves a length that has no percentage base to resolve against, like a gap or a corner
// radius. `8`, `8px` and `8.5px` all read as 8, the type is kept only by `parse_type`.
parse_length :: proc(value: string) -> f32 {
	length: Sizing_Value
	parse_type(&length, value)
	return length.val
}

// TODO: Remake this
parse_sides :: proc(sides: ^Style_Side_Sizes, value: string) -> bool {
	values := strings.fields(value, context.temp_allocator)
	if len(values) == 0 || len(values) > 4 do return false

	// a single value applies to every side, the shorter shorthands override from there
	top, right, bottom, left := values[0], values[0], values[0], values[0]
	switch len(values) {
	case 2:
		right, left = values[1], values[1]
	case 3:
		right, left = values[1], values[1]
		bottom = values[2]
	case 4:
		right, bottom, left = values[1], values[2], values[3]
	}

	parse_type(&sides.top,    top)
	parse_type(&sides.right,  right)
	parse_type(&sides.bottom, bottom)
	parse_type(&sides.left,   left)
	return true
}

// Parses opacity
parse_opacity :: proc(value: string) -> f32 {
	text := strings.trim_space(value)

	if strings.ends_with(text, "%") {
		if percent, ok := strconv.parse_f32(text[:len(text) - 1]); ok do return percent / 100
		return 1
	}

	if opacity, ok := strconv.parse_f32(text); ok do return opacity
	return 1
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
		parse_sides(&n.style.layout.padding, d.value)

	case "margin":
		parse_sides(&n.style.layout.margin, d.value)

	case "direction":
		switch d.value {
		case "row", "horizontal":   n.style.layout.direction = .Horizontal
		case "column", "vertical": n.style.layout.direction = .Vertical
		}

	case "gap":
		n.style.layout.gap = parse_length(d.value)

	case "background-color":
		n.style.has_bg = true
		n.style.background_color = parse_color(d.value)

	case "color":
		n.style.color = parse_color(d.value)

	case "border-width":
		parse_sides(&n.style.border.width, d.value)
		n.style.has_border = true

	case "border-color":
		n.style.border.color = parse_color(d.value)
		n.style.has_border = true

	case "corner-radius":
		n.style.radius = parse_length(d.value)

	case "opacity":
		n.style.opacity = parse_opacity(d.value)
	}
}

all_names_match :: proc(n: ^Node, s: [dynamic]^CSS_Simple_Selector) -> bool {
	for sel in s {
		if !simple_selector_matches(n, sel) do return false
	}
	return true
}

simple_selector_matches :: proc(n: ^Node, sel: ^CSS_Simple_Selector) -> bool {
	// TODO: Add a hook that calls back to the document when theres an error
	// This can be used for logging in a console, or in future, and embedded console accessible within the renderer
	// This will silently error making a fucking nightmare to debug if this causes an error
	if n == nil || sel == nil do return false

	#partial switch sel.kind {
	case .Universal:
		return true
	case .Type:
		// Match against tagname
		return n.tag == sel.name
	case .Class:
		// if the selector name is empty then why are we matching it
		if len(sel.name) == 0 do return false

		// If a single class matches then we return true
		for c in n.class {
			if sel.name == c do return true
		}
		return false
	case .Id:
		// empty ids should not work for either selector or node
		if len(n.id) == 0 || len(sel.name) == 0 do return false
		return sel.name == n.id
	}

	// Other cases handled here
	// [attr="value"] | [attr=*"value"]
	// :hover

	return false
}

// Search the nodes parents children (siblings) until we find the current node, the return the node before that
previous_sibling :: proc(n: ^Node) -> ^Node {
	p := n.parent
	if p == nil do return nil

	prev: ^Node = nil
	for child in p.children {
		if child == n do return prev
		prev = child
	}
	return nil
}

// Matches right to left, `index` is the compound selector that has to match `n`
// Recursively searches for matches
matches_selector_at :: proc(n: ^Node, s: ^CSS_Selector, index: int) -> bool {
	if n == nil do return false
	if !all_names_match(n, s.parts[index].simples) do return false
	if index == 0 do return true

	#partial switch s.parts[index - 1].combinator {
	case .Child:
		return matches_selector_at(n.parent, s, index - 1)
	case .Descendant:
		// while the node parent is not nil, we update the `parent` value to be
		// the next elements parent and redo the search
		for parent := n.parent; parent != nil; parent = parent.parent {
			if matches_selector_at(parent, s, index - 1) do return true
		}
		return false
	case .Adjacent:
		return matches_selector_at(previous_sibling(n), s, index - 1)
	case .Sibling:
		for sibling := previous_sibling(n); sibling != nil; sibling = previous_sibling(sibling) {
			if matches_selector_at(sibling, s, index - 1) do return true
		}
		return false
	}

	return false
}

matches_selector :: proc(n: ^Node, s: ^CSS_Selector) -> bool {
	if n == nil || s == nil || len(s.parts) == 0 do return false
	return matches_selector_at(n, s, len(s.parts) - 1)
}

find_styles :: proc(d: ^Document, n: ^Node) {
	if n == nil do return

	for sheet in d.loaded_styles { // for every stylesheet
		for rule in sheet.rules { // for every rule in every stylesheet
			for selec in rule.selectors { // for every selector in every rule in every stylesheet
				// a rule applies at most once, even when several of its selectors match
				if matches_selector(n, selec) { // if we match a selector, then for
					for decl in rule.declarations { // every property in every rule in every stylesheet
						set_declaration(n, decl) // apply the property to the node
					}
					break
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
