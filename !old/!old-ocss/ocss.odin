package ocss

import "core:strconv"
import "core:strings"
import "shared:clay"
import "ast"
import "parser"

Selector :: struct {
  name: string,
  type: ast.Selector_Kind,
}

Declaration :: struct {
  name:  string,
  value: string,
}

Style_Rule :: struct {
  selectors:    [dynamic]Selector,
  declarations: [dynamic]Declaration,
  properties:   clay.ElementDeclaration,
  text:         clay.TextElementConfig,
}

Style_Sheet :: struct {
  name:       string,
  path:       string,
  rules:      [dynamic]^Style_Rule,
  idMap:      map[string]^Style_Rule,
  classMap:   map[string]^Style_Rule,
  elementMap: map[string]^Style_Rule,
}

Style_Builder :: struct {
  layout:     Layout,
  text:       Text,
  background: clay.Color,
  image_url:  string,
  border: Border,
  radius:     f32,
  floating:   Floating,
  clip:       clay.ClipElementConfig,
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

//   - `align-self` / `float`
//   - `float-attach-to` / `float-element` / `float-attach`: anchor by id
Floating :: struct {
  enabled:         bool,
  attach_to:       clay.FloatingAttachToElement,
  // id of the element to anchor to when `attach_to == .ElementWithId`
  target:          string,
  element_point:   clay.FloatingAttachPointType,
  parent_point:    clay.FloatingAttachPointType,
  offset:          clay.Vector2,
  z_index:         i16,
  clip_to:         clay.FloatingClipToElement,
  pointer_capture: clay.PointerCaptureMode,
}

// Loads selectors from a selector list and adds them to the selector map
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
  // floating / anchoring
  case "align-self", "float":
    apply_align_self(&style.floating, declaration.value)
  case "float-attach-to":
    apply_float_attach_to(&style.floating, declaration.value)
  case "float-element":
    style.floating.target = strings.trim_space(declaration.value)
    style.floating.attach_to = .ElementWithId
    style.floating.enabled = true
  case "float-attach":
    apply_float_attach(&style.floating, declaration.value)
  case "float-offset":
    apply_float_offset(&style.floating, declaration.value)
  case "float-z":
    if z, ok := parse_int(declaration.value); ok do style.floating.z_index = i16(z)
  case "float-clip":
    switch strings.trim_space(declaration.value) {
    case "parent": style.floating.clip_to = .AttachedParent
    case "none":   style.floating.clip_to = .None
    }
  case "float-pointer":
    switch strings.trim_space(declaration.value) {
    case "capture":     style.floating.pointer_capture = .Capture
    case "passthrough": style.floating.pointer_capture = .Passthrough
    }
  // clipping / scroll containers
  case "overflow", "clip":
    apply_overflow(&style.clip, declaration.value)
  case "overflow-x":
    if on, ok := parse_overflow(declaration.value); ok do style.clip.horizontal = on
  case "overflow-y":
    if on, ok := parse_overflow(declaration.value); ok do style.clip.vertical = on
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

DEFAULT_TEXT_COLOR :: clay.Color{40, 40, 40, 255}
DEFAULT_TEXT_SIZE  :: u16(16)
DEFAULT_TEXT_FONT  :: u16(0)

Font_Resolver :: struct {
  resolve:   proc(user_data: rawptr, weight: string, size: u16) -> u16,
  user_data: rawptr,
}


finalize_text :: proc(style: Style_Builder, resolver: Font_Resolver = {}) -> clay.TextElementConfig {
  config := clay.TextElementConfig{
    textColor = DEFAULT_TEXT_COLOR,
    fontId    = DEFAULT_TEXT_FONT,
    fontSize  = DEFAULT_TEXT_SIZE,
  }
  if style.text.has_color   do config.textColor = style.text.color
  if style.text.has_font_size do config.fontSize = style.text.font_size

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
  config.cornerRadius = clay.CornerRadiusAll(style.radius)
  if style.floating.enabled {
    floating: clay.FloatingElementConfig
    floating.attachTo = style.floating.attach_to
    floating.attachment = {
      element = style.floating.element_point,
      parent  = style.floating.parent_point,
    }
    floating.offset = style.floating.offset
    floating.zIndex = style.floating.z_index
    floating.clipTo = style.floating.clip_to
    floating.pointerCaptureMode = style.floating.pointer_capture
    // anchoring to another element: clay matches the parent id hash, so it has
    // to line up with the id the target node is opened with.
    if style.floating.attach_to == .ElementWithId && len(style.floating.target) > 0 {
      floating.parentId = clay.ID(style.floating.target).id
    }
    config.floating = floating
  }

  //clip contents outside of view
  config.clip.horizontal = style.clip.horizontal
  config.clip.vertical = style.clip.vertical
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


apply_align_self :: proc(floating: ^Floating, value: string) {
  switch strings.trim_space(value) {
  case "left":
    floating.enabled = true
    floating.attach_to = .Parent
    floating.element_point = .LeftCenter
    floating.parent_point = .LeftCenter
  case "right":
    floating.enabled = true
    floating.attach_to = .Parent
    floating.element_point = .RightCenter
    floating.parent_point = .RightCenter
  case "center":
    floating.enabled = true
    floating.attach_to = .Parent
    floating.element_point = .CenterCenter
    floating.parent_point = .CenterCenter
  case "top":
    floating.enabled = true
    floating.attach_to = .Parent
    floating.element_point = .CenterTop
    floating.parent_point = .CenterTop
  case "bottom":
    floating.enabled = true
    floating.attach_to = .Parent
    floating.element_point = .CenterBottom
    floating.parent_point = .CenterBottom
  case "none":
    floating.enabled = false
  }
}

apply_float_attach_to :: proc(floating: ^Floating, value: string) {
  trimmed := strings.trim_space(value)
  switch trimmed {
  case "parent":
    floating.attach_to = .Parent
    floating.enabled = true
  case "root":
    floating.attach_to = .Root
    floating.enabled = true
  case "element", "id":
    floating.attach_to = .ElementWithId
    floating.enabled = true
  case "none":
    floating.enabled = false
  case:
    floating.attach_to = .ElementWithId
    floating.target = trimmed
    floating.enabled = true
  }
}

apply_float_attach :: proc(floating: ^Floating, value: string) {
  parts := strings.fields(value, context.temp_allocator)
  if len(parts) == 0 do return
  if point, ok := parse_attach_point(parts[0]); ok {
    floating.element_point = point
    floating.enabled = true
  }
  if len(parts) >= 2 {
    if point, ok := parse_attach_point(parts[1]); ok {
      floating.parent_point = point
    }
  }
}

// `float-offset: <x> [y]`; a single value applies to both axes.
apply_float_offset :: proc(floating: ^Floating, value: string) {
  parts := strings.fields(value, context.temp_allocator)
  if len(parts) == 0 do return
  if x, ok := parse_float(parts[0]); ok do floating.offset[0] = x
  if len(parts) >= 2 {
    if y, ok := parse_float(parts[1]); ok do floating.offset[1] = y
  } else {
    floating.offset[1] = floating.offset[0]
  }
}

parse_attach_point :: proc(value: string) -> (point: clay.FloatingAttachPointType, ok: bool) {
  switch strings.trim_space(value) {
  case "left-top":       return .LeftTop, true
  case "left-center":    return .LeftCenter, true
  case "left-bottom":    return .LeftBottom, true
  case "center-top":     return .CenterTop, true
  case "center-center":  return .CenterCenter, true
  case "center-bottom":  return .CenterBottom, true
  case "right-top":      return .RightTop, true
  case "right-center":   return .RightCenter, true
  case "right-bottom":   return .RightBottom, true
  }
  return .LeftTop, false
}

// `overflow: <x> [y]` / `clip: hidden`
apply_overflow :: proc(clip: ^clay.ClipElementConfig, value: string) {
  parts := strings.fields(value, context.temp_allocator)
  if len(parts) == 0 do return
  if x, ok := parse_overflow(parts[0]); ok {
    clip.horizontal = x
    clip.vertical = x
  }
  if len(parts) >= 2 {
    if y, ok := parse_overflow(parts[1]); ok do clip.vertical = y
  }
}

//`clip`/`scroll`/`hidden` - clip,
//`visible`/`none` - no clip.
parse_overflow :: proc(value: string) -> (clip: bool, ok: bool) {
  switch strings.trim_space(value) {
  case "hidden", "clip", "scroll", "auto": return true, true
  case "visible", "none": return false, true
  }
  return false, false
}

parse_int :: proc(value: string) -> (int, bool) {
  result, ok := strconv.parse_int(strings.trim_space(value))
  return result, ok
}

parse_float :: proc(value: string) -> (f32, bool) {
  result, ok := strconv.parse_f32(strings.trim_space(value))
  return result, ok
}

parse_length :: proc(value: string) -> (f32, bool) {
  text := strings.trim_space(value)
  if strings.has_suffix(text, "px") do text = text[:len(text) - 2]
  return parse_float(text)
}

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
resolve_style :: proc(sheets: []^Style_Sheet, data: ^string, tag, id: string, classes: []string, allocator := context.allocator, default_grow := false, resolver: Font_Resolver = {}) -> ^Style_Rule {
  merged, text, matched := merge_style(sheets, tag, id, classes, default_grow, resolver)
  if !matched do return nil

  rule := new(Style_Rule, allocator)
  rule.properties = merged
  rule.text = text
  rule.properties.image.imageData = data
  return rule
}
