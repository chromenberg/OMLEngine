
package ocss

import "core:fmt"
import "core:c"
import "shared:clay"
import "parser"
import "ast"

// === Style Colors ===
ColorType :: enum {
  RGB,
  RGBA,
  HEX,
}
Color :: struct {
  type: ColorType
}
// RGB color data, inherits from base Color data
RGBColor :: struct {
  using _: Color,
  r: u8,
  g: u8,
  b: u8,
}
// RGBA color data, inherits from RGBColor and extends an alpha channel
RGBAColor :: struct {
  using _: RGBColor,
  a: u8,
}

// === Positioning ===
Padding :: struct {
  top: int,
  right: int,
  bottom: int,
  left: int,
}
PaddingBlock :: struct {
  top: int,
  bottom: int,
}
PaddingInline :: struct {
  left: int,
  right: int,
}
SizingInfo :: struct {
  width: int,
  height: int,
}
Alignment :: enum {
  None,
  Center,
  Start,
  End,
}
LayoutAlignment :: struct {
  // how left or right are the children aligned
  x: Alignment,
  y: Alignment
}

// === Text ===
FontData :: struct {
  size: int,
  weight: int,
  family: string,
}

// Rule selectors


Style_Padding :: struct {
  left:   u16,
  right:  u16,
  top:    u16,
  bottom: u16
}

Style_Alignment :: struct {
  x: clay.LayoutAlignmentX,
  y: clay.LayoutAlignmentY
}

Style_Layout_Props :: struct {
  layoutDirection: clay.LayoutDirection,
  padding: Style_Padding,
  childGap: c.uint16_t,
  childAlignment: Style_Alignment,
  sizing: SizingInfo,
}

Style_Properties :: struct {
  layout: Style_Layout_Props,
  backgroundColor : Color,
}

Selector :: struct {
  name: string,
  type: ast.Selector_Kind
}

Style_Rule :: struct {
  selectors: [dynamic]Selector,
  properties: Style_Properties
}

Style_Sheet :: struct {
  name: string,
  path: string,
  rules: [dynamic]Style_Rule
}

load_selectors :: proc(rule: ^Style_Rule, list: ^ast.Selector_List) {
  for selector in list.inner {
    #partial switch d in selector.derived {
    case ^ast.Selector:
      selec: Selector
      selec.name = d.name.text
      selec.type = d.kind

      append(&rule.selectors, selec)
    }
  }
}

load_selector_list :: proc(rule: ^Style_Rule, data: ^ast.Rule) {
  for selector_list in data.selectors {
    load_selectors(rule, selector_list)
  }  
}

create_style_sheet :: proc(p: ^parser.Parser) {
  tree := p.doc
  sheet: Style_Sheet
  sheet.name = p.tok.file
  for rule in tree {
    parsed_rule: Style_Rule
    
    #partial switch r in rule.derived {
    case ^ast.Rule:
      load_selector_list(&parsed_rule, r)
    }
    
    append(&sheet.rules, parsed_rule)
  }

  fmt.printfln("%#v", sheet)
} 
