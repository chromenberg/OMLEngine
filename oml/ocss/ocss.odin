package ocss

import "core:strconv"
import "core:strings"
import "shared:clay"
import "ast"
import "parser"

// A single selector a rule applies to (`.class`, `#id` or `element`).
Selector :: struct {
  name: string,
  type: ast.Selector_Kind,
}

// One `name: value` pair exactly as written inside a rule block.
Declaration :: struct {
  name:  string,
  value: string,
}

// A single rule of a stylesheet.
//
// Rules are allocated individually so that a pointer to one stays valid even
// when the owning stylesheet collects more rules. The old code stored rules by
// value in a dynamic array and pointed into it, so every append invalidated the
// pointers held by the id/class maps.
Style_Rule :: struct {
  selectors:    [dynamic]Selector,
  declarations: [dynamic]Declaration,
  // The clay element config produced by applying `declarations` in order.
  properties:   clay.ElementDeclaration,
  // The clay text config for this rule, used by text elements.
  text:         clay.TextElementConfig,
}

// A parsed ocss file: the ocss equivalent of the cssom.
//
// It lives on its own, independently of any oml document, and is only merged
// into the dom afterwards. The lookup maps are indexes into the rule tree and
// only ever point at heap allocated rules, so they are never invalidated.
Style_Sheet :: struct {
  name:       string,
  path:       string,
  rules:      [dynamic]^Style_Rule,
  idMap:      map[string]^Style_Rule,
  classMap:   map[string]^Style_Rule,
  elementMap: map[string]^Style_Rule,
}

// Accumulates declarations while styles are merged, then bakes them into a
// single clay config. Sizing needs accumulation because e.g. `width`,
// `min-width` and `max-width` may arrive from different rules and have to be
// combined into one axis.
Style_Builder :: struct {
  layout:     Layout,
  text:       Text,
  background: clay.Color,
  image_url: string,
  border: Border,
  // radius in pixels, converted to clays system using final bounds
  radius:     f32,
}

Border :: struct {
  width: clay.BorderWidth,
  color: clay.Color
}

Text :: struct {
  color:          clay.Color,
  has_color:      bool,
  font_size:      u16,
  has_font_size:  bool,
  font_id:        u16,
  has_font_id:    bool,
  letter_spacing: u16,
  line_height:    u16,
  weight: string,
}

Layout :: struct {
  direction: clay.LayoutDirection,
  gap:       u16,
  align_x:   clay.LayoutAlignmentX,
  align_y:   clay.LayoutAlignmentY,
  padding:   clay.Padding,
  width:     Sizing_Direction,
  height:    Sizing_Direction,
}

Sizing_Direction :: struct {
  type:  clay.SizingType,
  // fixed pixels for .Fixed, or a 0..1 fraction for .Percent
  value: f32,
  min:   f32,
  max:   f32,
  // has an explicit width / height?
  has_value: bool,
}

// Loads selectors from a selector list and adds them to the selector map
//
load_selectors :: proc(
	rule: ^Style_Rule,
	list: ^ast.Selector_List,
	sheet: ^Style_Sheet,
	allocator := context.allocator
) {
  for selector in list.inner {
    #partial switch d in selector.derived {
    case ^ast.Selector:
      selec := Selector {
        name = strings.clone(d.name.text, allocator),
        type = d.kind,
      }
      append(&rule.selectors, selec)

      // Depending on the selector type, we insert its name and the style into its respective map
      // for lookups later
      switch d.kind {
      case .Id:      map_insert(&sheet.idMap, selec.name, rule)
      case .Class:   map_insert(&sheet.classMap, selec.name, rule)
      case .Element: map_insert(&sheet.elementMap, selec.name, rule)
      case .Data:
      }
    }
  }
}

load_selector_list :: proc(rule: ^Style_Rule, data: [dynamic]^ast.Selector_List, sheet: ^Style_Sheet, allocator := context.allocator) {
  for selector_list in data {
    load_selectors(rule, selector_list, sheet, allocator)
  }
}

load_properties :: proc(rule: ^Style_Rule, props: ^ast.Block, allocator := context.allocator) {
  for prop in props.inner {
    typed_prop := prop.derived.(^ast.Declaration)

    append(&rule.declarations, Declaration {
      name  = strings.clone(typed_prop.name.text, allocator),
      value = strings.clone(typed_prop.value.text, allocator),
    })
  }

  // Resolve the rule's own clay config from its declarations.
  builder: Style_Builder
  for declaration in rule.declarations {
    apply_declaration(&builder, declaration)
  }
  rule.properties = finalize(builder)
  rule.text = finalize_text(builder)
}

// Maps one ocss declaration onto the accumulating style builder.
apply_declaration :: proc(style: ^Style_Builder, declaration: Declaration) {
  switch declaration.name {
  case "background-color":
    if color, ok := parse_color(declaration.value); ok do style.background = color
  case "corner-radius":
    if radius, ok := parse_length(declaration.value); ok do style.radius = radius
  case "padding":
    apply_padding(&style.layout, declaration.value)
  case "gap":
    if gap, ok := parse_int(declaration.value); ok do style.layout.gap = u16(gap)
  case "direction":
    switch declaration.value {
    case "left-to-right", "row":    style.layout.direction = .LeftToRight
    case "top-to-bottom", "column": style.layout.direction = .TopToBottom
    }
  case "align-items":
    if align, ok := Alignment_X_Map[declaration.value]; ok do style.layout.align_x = align
  case "justify-content":
    if align, ok := Alignment_Y_Map[declaration.value]; ok do style.layout.align_y = align
  case "width":
    apply_size(&style.layout.width, declaration.value)
  case "height":
    apply_size(&style.layout.height, declaration.value)
  case "min-width":
    if value, ok := parse_length(declaration.value); ok do style.layout.width.min = value
  case "min-height":
    if value, ok := parse_length(declaration.value); ok do style.layout.height.min = value
  case "max-width":
    if value, ok := parse_length(declaration.value); ok do style.layout.width.max = value
  case "max-height":
    if value, ok := parse_length(declaration.value); ok do style.layout.height.max = value
  case "border-color":
    if color, ok := parse_color(declaration.value); ok {
      style.border.color = color
    }
  case "border-width":
    apply_border_width(&style.border, declaration.value)
  // text
  case "color":
    if color, ok := parse_color(declaration.value); ok {
      style.text.color = color
      style.text.has_color = true
    }
  case "font-size":
    if size, ok := parse_length(declaration.value); ok {
      style.text.font_size = u16(size)
      style.text.has_font_size = true
    }
  case "font-id":
    // explicit override; skips weight/size resolution
    if id, ok := parse_int(declaration.value); ok {
      style.text.font_id = u16(id)
      style.text.has_font_id = true
    }
  case "font-weight":
    style.text.weight = declaration.value
  case "letter-spacing":
    if value, ok := parse_int(declaration.value); ok do style.text.letter_spacing = u16(value)
  case "line-height":
    if value, ok := parse_int(declaration.value); ok do style.text.line_height = u16(value)
  case "image-url":
    
  }
}

// Sets the primary sizing of an axis (`width`/`height`).
apply_size :: proc(axis: ^Sizing_Direction, value: string) {
  type, amount, ok := parse_size(value)
  if !ok do return
  axis.type = type
  axis.value = amount
  axis.has_value = true
}

// Defaults for text elements that are styled but set no text property.
DEFAULT_TEXT_COLOR :: clay.Color{40, 40, 40, 255}
DEFAULT_TEXT_SIZE  :: u16(16)
DEFAULT_TEXT_FONT  :: u16(0)

// Lets ocss ask the engine to turn a requested font weight + size into a
// concrete font id. ocss does not know which fonts are loaded, so the engine
// (which owns them) supplies the lookup. `size == 0` means "any size".
Font_Resolver :: struct {
  resolve:   proc(user_data: rawptr, weight: string, size: u16) -> u16,
  user_data: rawptr,
}

// Bakes the accumulated text properties into a clay text config, filling in
// defaults for anything the stylesheets did not set.
finalize_text :: proc(style: Style_Builder, resolver: Font_Resolver = {}) -> clay.TextElementConfig {
  config := clay.TextElementConfig{
    textColor = DEFAULT_TEXT_COLOR,
    fontId    = DEFAULT_TEXT_FONT,
    fontSize  = DEFAULT_TEXT_SIZE,
  }
  if style.text.has_color   do config.textColor = style.text.color
  if style.text.has_font_size do config.fontSize = style.text.font_size

  // an explicit font-id wins; otherwise resolve the requested weight + size
  if style.text.has_font_id {
    config.fontId = style.text.font_id
  } else if resolver.resolve != nil {
    requested_size := style.text.has_font_size ? style.text.font_size : u16(0)
    config.fontId = resolver.resolve(resolver.user_data, style.text.weight, requested_size)
  }
  config.wrapMode = .Words
  if style.text.letter_spacing != 0 do config.letterSpacing = style.text.letter_spacing
  if style.text.line_height    != 0 do config.lineHeight = style.text.line_height
  return config
}

// Bakes an accumulated builder into a clay element config.
//
// `default_grow`, when true, makes an axis that was left entirely unset fill
// its parent instead of shrink-wrapping. Used for the body, which should span
// the window unless the stylesheets size it explicitly.
finalize :: proc(style: Style_Builder, default_grow := false) -> clay.ElementDeclaration {
  config: clay.ElementDeclaration
  config.layout.layoutDirection = style.layout.direction
  config.layout.childGap = style.layout.gap
  config.layout.childAlignment = {x = style.layout.align_x, y = style.layout.align_y}
  config.layout.padding = style.layout.padding
  config.layout.sizing.width = finalize_axis(style.layout.width, default_grow)
  config.layout.sizing.height = finalize_axis(style.layout.height, default_grow)
  config.backgroundColor = style.background
  config.border.color = style.border.color
  config.border.width = style.border.width
  // pixels; the renderer converts to roundness once the bounds are known
  config.cornerRadius = clay.CornerRadiusAll(style.radius)
  return config
}

finalize_axis :: proc(axis: Sizing_Direction, default_grow := false) -> clay.SizingAxis {
  switch axis.type {
  case .Percent:
    return clay.SizingPercent(axis.value)
  case .Fixed:
    // min/max clamp the fixed size; a zero constraint means "unset"
    value := axis.value
    if axis.min > 0 && value < axis.min do value = axis.min
    if axis.max > 0 && value > axis.max do value = axis.max
    return clay.SizingFixed(value)
  case .Grow:
    return clay.SizingGrow({min = axis.min, max = axis.max})
  case .Fit:
    // nothing set on this axis and no constraints: fill the parent when asked
    if default_grow && !axis.has_value && axis.min == 0 && axis.max == 0 {
      return clay.SizingGrow()
    }
    return clay.SizingFit({min = axis.min, max = axis.max})
  }
  return clay.SizingFit()
}

// Applies a css-like padding shorthand (1..4 values, space separated).
apply_border_width :: proc(layout: ^Border, value: string) {
  parts := strings.fields(value, context.temp_allocator)
  if len(parts) == 0 || len(parts) > 4 do return

  values: [4]int
  for part, i in parts {
    v, ok := parse_int(part)
    if !ok do return
    values[i] = v
  }

  padding: clay.BorderWidth
  switch len(parts) {
  case 1:
    // all edges
    padding.top    = u16(values[0])
    padding.right  = u16(values[0])
    padding.bottom = u16(values[0])
    padding.left   = u16(values[0])
  case 2:
    // block | inline
    padding.top    = u16(values[0])
    padding.bottom = u16(values[0])
    padding.left   = u16(values[1])
    padding.right  = u16(values[1])
  case 3:
    // top | inline | bottom
    padding.top    = u16(values[0])
    padding.left   = u16(values[1])
    padding.right  = u16(values[1])
    padding.bottom = u16(values[2])
  case:
    // top | right | bottom | left
    padding.top    = u16(values[0])
    padding.right  = u16(values[1])
    padding.bottom = u16(values[2])
    padding.left   = u16(values[3])
  }
  padding.betweenChildren = 0
  layout.width = padding
}

// Applies a css-like padding shorthand (1..4 values, space separated).
apply_padding :: proc(layout: ^Layout, value: string) {
  parts := strings.fields(value, context.temp_allocator)
  if len(parts) == 0 || len(parts) > 4 do return

  values: [4]int
  for part, i in parts {
    v, ok := parse_int(part)
    if !ok do return
    values[i] = v
  }

  padding: clay.Padding
  switch len(parts) {
  case 1:
    // all edges
    padding.top    = u16(values[0])
    padding.right  = u16(values[0])
    padding.bottom = u16(values[0])
    padding.left   = u16(values[0])
  case 2:
    // block | inline
    padding.top    = u16(values[0])
    padding.bottom = u16(values[0])
    padding.left   = u16(values[1])
    padding.right  = u16(values[1])
  case 3:
    // top | inline | bottom
    padding.top    = u16(values[0])
    padding.left   = u16(values[1])
    padding.right  = u16(values[1])
    padding.bottom = u16(values[2])
  case:
    // top | right | bottom | left
    padding.top    = u16(values[0])
    padding.right  = u16(values[1])
    padding.bottom = u16(values[2])
    padding.left   = u16(values[3])
  }
  layout.padding = padding
}


// === Value parsing ===

parse_int :: proc(value: string) -> (int, bool) {
  result, ok := strconv.parse_int(strings.trim_space(value))
  return result, ok
}

parse_float :: proc(value: string) -> (f32, bool) {
  result, ok := strconv.parse_f32(strings.trim_space(value))
  return result, ok
}

// Parses a pixel length, accepting an optional `px` suffix.
parse_length :: proc(value: string) -> (f32, bool) {
  text := strings.trim_space(value)
  if strings.has_suffix(text, "px") do text = text[:len(text) - 2]
  return parse_float(text)
}

// `fit` and `grow` are keywords, `N%` is a percentage and everything else is a
// pixel size. `type` is only meaningful when `ok` is true.
parse_size :: proc(value: string) -> (type: clay.SizingType, amount: f32, ok: bool) {
  text := strings.trim_space(value)
  switch text {
  case "fit":  return .Fit, 0, true
  case "grow": return .Grow, 0, true
  }

  if strings.has_suffix(text, "%") {
    percent, percent_ok := parse_float(text[:len(text) - 1])
    if !percent_ok do return .Fit, 0, false
    return .Percent, percent / 100, true
  }

  length, length_ok := parse_length(text)
  if !length_ok do return .Fit, 0, false
  return .Fixed, length, true
}


parse_hex_byte :: proc(text: string) -> (u8, bool) {
  value, ok := strconv.parse_int(text, 16)
  if !ok do return 0, false
  return u8(value), true
}

// Parses a `#rgb`, `#rrggbb` or `#rrggbbaa` color into a clay color.
parse_color :: proc(value: string) -> (clay.Color, bool) {
  hex := strings.trim_space(value)
  if len(hex) == 0 || hex[0] != '#' do return {}, false
  hex = hex[1:]

  switch len(hex) {
  case 3:
    r, r_ok := parse_hex_byte(hex[0:1])
    g, g_ok := parse_hex_byte(hex[1:2])
    b, b_ok := parse_hex_byte(hex[2:3])
    if !r_ok || !g_ok || !b_ok do return {}, false
    return {f32(r) * 17, f32(g) * 17, f32(b) * 17, 255}, true
  case 6:
    r, r_ok := parse_hex_byte(hex[0:2])
    g, g_ok := parse_hex_byte(hex[2:4])
    b, b_ok := parse_hex_byte(hex[4:6])
    if !r_ok || !g_ok || !b_ok do return {}, false
    return {f32(r), f32(g), f32(b), 255}, true
  case 8:
    r, r_ok := parse_hex_byte(hex[0:2])
    g, g_ok := parse_hex_byte(hex[2:4])
    b, b_ok := parse_hex_byte(hex[4:6])
    a, a_ok := parse_hex_byte(hex[6:8])
    if !r_ok || !g_ok || !b_ok || !a_ok do return {}, false
    return {f32(r), f32(g), f32(b), f32(a)}, true
  }
  return {}, false
}


create_style_sheet :: proc(p: ^parser.Parser, allocator := context.allocator) -> ^Style_Sheet {
  sheet := new(Style_Sheet, allocator)
  sheet.name = strings.clone(p.tok.file, allocator)
  sheet.path = strings.clone(p.tok.file, allocator)


  sheet.rules = make([dynamic]^Style_Rule, allocator)
  sheet.idMap = make(map[string]^Style_Rule, allocator)
  sheet.classMap = make(map[string]^Style_Rule, allocator)
  sheet.elementMap = make(map[string]^Style_Rule, allocator)

  for node in p.doc {
    #partial switch r in node.derived {
    case ^ast.Rule:
      rule := new(Style_Rule, allocator)
      rule.selectors = make([dynamic]Selector, allocator)
      rule.declarations = make([dynamic]Declaration, allocator)
      load_selector_list(rule, r.selectors, sheet, allocator)
      if r.inner != nil {
        load_properties(rule, r.inner, allocator)
      }
      append(&sheet.rules, rule)
    }
  }

  return sheet
}


get_style_from_class :: proc(sheet: ^Style_Sheet, class: string) -> ^Style_Rule {
  return sheet.classMap[class]
}

get_style_from_id :: proc(sheet: ^Style_Sheet, id: string) -> ^Style_Rule {
  return sheet.idMap[id]
}

get_style_from_element :: proc(sheet: ^Style_Sheet, element: string) -> ^Style_Rule {
  return sheet.elementMap[element]
}


selector_matches :: proc(selector: Selector, tag, id: string, classes: []string) -> bool {
  switch selector.type {
  case .Id:
    return id == selector.name
  case .Class:
    for class in classes {
      if class == selector.name do return true
    }
    return false
  case .Element:
    return tag == selector.name
  case .Data:
    return false
  }
  return false
}

// A rule matches when every one of its selectors matches the node.
rule_matches :: proc(rule: ^Style_Rule, tag, id: string, classes: []string) -> bool {
  if len(rule.selectors) == 0 do return false
  for selector in rule.selectors {
    if !selector_matches(selector, tag, id, classes) do return false
  }
  return true
}

// TODO: Remove param spam holy shit this fucking sucks
merge_style :: proc(sheets: []^Style_Sheet, tag, id: string, classes: []string, default_grow := false, resolver: Font_Resolver = {}) -> (merged: clay.ElementDeclaration, text: clay.TextElementConfig, matched: bool) {
  builder: Style_Builder
  for sheet in sheets {
    for rule in sheet.rules {
      if rule_matches(rule, tag, id, classes) {
        for declaration in rule.declarations {
          apply_declaration(&builder, declaration)
        }
        matched = true
      }
    }
  }
  if matched {
    merged = finalize(builder, default_grow)
    text = finalize_text(builder, resolver)
  }
  return
}

// computes the nodes merged style and returns it to merge it with the node
resolve_style :: proc(sheets: []^Style_Sheet, tag, id: string, classes: []string, allocator := context.allocator, default_grow := false, resolver: Font_Resolver = {}) -> ^Style_Rule {
  merged, text, matched := merge_style(sheets, tag, id, classes, default_grow, resolver)
  if !matched do return nil

  rule := new(Style_Rule, allocator)
  rule.properties = merged
  rule.text = text
  return rule
}
