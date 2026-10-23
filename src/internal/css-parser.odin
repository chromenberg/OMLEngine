package internal

import "core:log"
import "core:os"
import "core:mem"
import "core:strings"

// Parses css based off of the w3 spec
// im gonna forget this shit so quickly

CSS_Pos :: struct {
  offset: int,
  line: int,
  column: int,
}

CSS_Token :: struct {
  kind: CSS_Token_Kind,
  text: string,
  pos: CSS_Pos,
  preceded_by_space: bool,
}

CSS_Token_Kind :: enum {
  Invalid,
  EOF,
  Ident,
  At_Keyword,
  Hash,
  String,
  Number,
  Dimension,  // 10px
  Percentage, // 10%
  Comma,
  Colon,
  Semicolon,
  Dot,
  Star,
  Greater,
  Plus,
  Tilde,
  Caret,
  Dollar,
  Pipe,
  Equal,
  Bang,
  Open_Brace,
  Close_Brace,
  Open_Paren,
  Close_Paren,
  Open_Bracket,
  Close_Bracket,
  Delim,
}

CSS_Parser :: struct {
  using parser: Parser,
  doc: ^Document,
  tokens: [dynamic]CSS_Token,
  index: int,
  current: CSS_Token,
  sheet: ^CSS_Stylesheet,
}

Any_CSS_Node :: union {
  ^CSS_Stylesheet,
  ^CSS_Rule,
  ^CSS_Selector,
  ^CSS_Compound,
  ^CSS_Simple_Selector,
  ^CSS_Declaration,
}

CSS_Node :: struct {
  derived: Any_CSS_Node,
  pos: CSS_Pos,
}

CSS_Selector_Kind :: enum {
  Type,
  Universal,
  Class,
  Id,
  Attribute,
  Pseudo,
}

CSS_Simple_Selector :: struct {
  using node: CSS_Node,
  kind: CSS_Selector_Kind,
  name: string,
  // attribute selectors only
  op: string,
  value: string,
}

CSS_Combinator :: enum {
  None,
  Descendant,
  Child,
  Adjacent,
  Sibling,
}

CSS_Compound :: struct {
  using node: CSS_Node,
  simples: [dynamic]^CSS_Simple_Selector,
  // relation between this compound and the one to its right
  combinator: CSS_Combinator,
}

CSS_Selector :: struct {
  using node: CSS_Node,
  parts: [dynamic]^CSS_Compound,
  specificity: [3]int,
}

CSS_Declaration :: struct {
  using node: CSS_Node,
  name: string,
  value: string,
  important: bool,
}

CSS_Rule :: struct {
  using node: CSS_Node,
  selectors: [dynamic]^CSS_Selector,
  declarations: [dynamic]^CSS_Declaration,
}

CSS_Stylesheet :: struct {
  using node: CSS_Node,
  rules: [dynamic]^CSS_Rule,
}

new_css_node :: proc($T: typeid, pos: CSS_Pos, allocator: mem.Allocator) -> ^T {
  node := new(T, allocator)
  node.derived = node
  node.pos = pos
  return node
}

@(private="file")
read_stylesheet :: proc(p: ^CSS_Parser) -> bool {
  data, err := os.read_entire_file(p.file.src, p.allocator)
  if err != nil {
    log.errorf("Failed to read stylesheet %v: %v", p.file.src, err)
    return false
  }
  p.source = string(data)
  return true
}

@(private="file")
is_css_digit :: proc(c: byte) -> bool {
  return c >= '0' && c <= '9'
}

@(private="file")
is_css_ident_start :: proc(c: byte) -> bool {
  return c == '_' || c == '-' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c >= 0x80
}

@(private="file")
is_css_ident_continue :: proc(c: byte) -> bool {
  return is_css_ident_start(c) || is_css_digit(c)
}

@(private="file")
scan_css_ident :: proc(source: string, start: int) -> int {
  i := start
  for i < len(source) && is_css_ident_continue(source[i]) do i += 1
  return i
}

@(private="file")
scan_css_string :: proc(source: string, start: int, quote: byte) -> int {
  i := start + 1 // opening quote
  for i < len(source) {
    char := source[i]
    if char == '\\' && i+1 < len(source) {
      i += 2
      continue
    }
    if char == quote {
      i += 1
      break
    }
    if char == '\n' do break
    i += 1
  }
  return i
}

// returns the units of the number
@(private="file")
scan_css_number :: proc(source: string, i: int) -> (end: int, kind: CSS_Token_Kind) {
  j := i
  for j < len(source) && is_css_digit(source[j]) do j += 1
  if j < len(source) && source[j] == '.' {
    j += 1
    for j < len(source) && is_css_digit(source[j]) do j += 1
  }
  if j < len(source) && (source[j] == 'e' || source[j] == 'E') {
    k := j + 1
    if k < len(source) && (source[k] == '+' || source[k] == '-') do k += 1
    if k < len(source) && is_css_digit(source[k]) {
      j = k
      for j < len(source) && is_css_digit(source[j]) do j += 1
    }
  }

  kind = .Number
  if j < len(source) && source[j] == '%' {
    j += 1
    kind = .Percentage
  } else if j < len(source) && is_css_ident_start(source[j]) {
    j = scan_css_ident(source, j)
    kind = .Dimension
  }
  return j, kind
}

@(private="file")
tokenize_css :: proc(p: ^CSS_Parser) {
  p.tokens = make([dynamic]CSS_Token, 0, 64, p.allocator)
  src := p.source

  i := 0
  line := 1
  line_start := 0
  spaced := false

  for i < len(src) {
    char := src[i]

    // skip whitespace
    if char == ' ' || char == '\t' || char == '\r' || char == '\n' {
      if char == '\n' {
        line += 1
        line_start = i + 1
      }
      i += 1
      spaced = true
      continue
    }

    if char == '/' && i+1 < len(src) && src[i+1] == '*' {
      i += 2
      for i+1 < len(src) && !(src[i] == '*' && src[i+1] == '/') {
        if src[i] == '\n' {
          line += 1
          line_start = i + 1
        }
        i += 1
      }
      if i+1 < len(src) do i += 2
      spaced = true
      continue
    }

    if char == '/' && i+1 < len(src) && src[i+1] == '/' {
      i += 2
      for i < len(src) && src[i] != '\n' do i += 1
      spaced = true
      continue
    }

    start := i
    pos := CSS_Pos {
      offset = i,
      line = line,
      column = i - line_start + 1,
    }
    kind: CSS_Token_Kind

    switch {
    case char == '@':
      i += 1
      i = scan_css_ident(src, i)
      kind = .At_Keyword
    case char == '#':
      i += 1
      i = scan_css_ident(src, i)
      kind = .Hash
    case char == '"' || char == '\'':
      i = scan_css_string(src, i, char)
      kind = .String
    case is_css_digit(char) || (char == '.' && i+1 < len(src) && is_css_digit(src[i+1])):
      i, kind = scan_css_number(src, i)
    case is_css_ident_start(char):
      i = scan_css_ident(src, i)
      kind = .Ident
    case:
      i += 1
      switch char {
      case '{': kind = .Open_Brace
      case '}': kind = .Close_Brace
      case '(': kind = .Open_Paren
      case ')': kind = .Close_Paren
      case '[': kind = .Open_Bracket
      case ']': kind = .Close_Bracket
      case ':': kind = .Colon
      case ';': kind = .Semicolon
      case ',': kind = .Comma
      case '.': kind = .Dot
      case '*': kind = .Star
      case '>': kind = .Greater
      case '+': kind = .Plus
      case '~': kind = .Tilde
      case '=': kind = .Equal
      case '^': kind = .Caret
      case '$': kind = .Dollar
      case '|': kind = .Pipe
      case '!': kind = .Bang
      case:     kind = .Delim
      }
    }

    append(&p.tokens, CSS_Token {
      kind = kind,
      text = src[start:i],
      pos = pos,
      preceded_by_space = spaced,
    })
    spaced = false
  }

  append(&p.tokens, CSS_Token {
    kind = .EOF,
    pos = CSS_Pos {
      offset = len(src),
      line = line,
      column = len(src) - line_start + 1,
    },
    preceded_by_space = spaced,
  })
}

@(private="file")
css_peek :: proc(p: ^CSS_Parser, lookahead := 0) -> CSS_Token {
  i := p.index + lookahead
  if i < 0 || i >= len(p.tokens) do return CSS_Token{ kind = .EOF }
  return p.tokens[i]
}

@(private="file")
css_advance :: proc(p: ^CSS_Parser) -> CSS_Token {
  tok := css_peek(p)
  p.current = tok
  if p.index < len(p.tokens) do p.index += 1
  return tok
}

@(private="file")
css_at :: proc(p: ^CSS_Parser, kind: CSS_Token_Kind) -> bool {
  return css_peek(p).kind == kind
}

@(private="file")
css_expect :: proc(p: ^CSS_Parser, kind: CSS_Token_Kind) -> bool {
  if !css_at(p, kind) {
    tok := css_peek(p)
    log.errorf("css: expected %v, got %v at %d:%d", kind, tok.kind, tok.pos.line, tok.pos.column)
    return false
  }
  css_advance(p)
  return true
}

@(private="file")
css_take_ident :: proc(p: ^CSS_Parser) -> (name: string, ok: bool) {
  tok := css_peek(p)
  if tok.kind != .Ident do return "", false
  css_advance(p)
  return strings.clone(tok.text, p.allocator), true
}

@(private="file")
css_can_start_simple :: proc(tok: CSS_Token) -> bool {
  #partial switch tok.kind {
  case .Ident, .Star, .Dot, .Hash, .Open_Bracket, .Colon:
    return true
  case:
    return false
  }
}

@(private="file")
parse_simple :: proc(p: ^CSS_Parser) -> ^CSS_Simple_Selector {
  tok := css_peek(p)

  #partial switch tok.kind {
  case .Star:
    css_advance(p)
    s := new_css_node(CSS_Simple_Selector, tok.pos, p.allocator)
    s.kind = .Universal
    return s
  case .Ident:
    css_advance(p)
    s := new_css_node(CSS_Simple_Selector, tok.pos, p.allocator)
    s.kind = .Type
    s.name = strings.clone(tok.text, p.allocator)
    return s
  case .Dot:
    css_advance(p)
    name, ok := css_take_ident(p)
    if !ok do return nil
    s := new_css_node(CSS_Simple_Selector, tok.pos, p.allocator)
    s.kind = .Class
    s.name = name
    return s
  case .Hash:
    css_advance(p)
    s := new_css_node(CSS_Simple_Selector, tok.pos, p.allocator)
    s.kind = .Id
    // exclude leading # in a #id
    s.name = strings.clone(tok.text[1:], p.allocator)
    return s
  case .Open_Bracket:
    return parse_attribute(p)
  case .Colon:
    return parse_pseudo(p)
  }

  return nil
}

@(private="file")
parse_attribute :: proc(p: ^CSS_Parser) -> ^CSS_Simple_Selector {
  start := css_advance(p).pos // '['

  name, ok := css_take_ident(p)
  if !ok do return nil

  s := new_css_node(CSS_Simple_Selector, start, p.allocator)
  s.kind = .Attribute
  s.name = name

  op := css_peek(p)
  #partial switch op.kind {
  case .Equal:
    css_advance(p)
    s.op = "="
  case .Tilde:
    css_advance(p)
    if css_expect(p, .Equal) do s.op = "~="
  case .Caret:
    css_advance(p)
    if css_expect(p, .Equal) do s.op = "^="
  case .Dollar:
    css_advance(p)
    if css_expect(p, .Equal) do s.op = "$="
  case .Star:
    css_advance(p)
    if css_expect(p, .Equal) do s.op = "*="
  case .Pipe:
    css_advance(p)
    if css_expect(p, .Equal) do s.op = "|="
  case:
  }

  value := css_peek(p)
  if value.kind == .Ident || value.kind == .String {
    s.value = strings.clone(unquote_css(value.text), p.allocator)
    css_advance(p)
  }

  css_expect(p, .Close_Bracket)
  return s
}

@(private="file")
parse_pseudo :: proc(p: ^CSS_Parser) -> ^CSS_Simple_Selector {
  start := css_advance(p).pos // ':'
  if css_at(p, .Colon) do css_advance(p) // '::' pseudo-element

  tok := css_peek(p)
  if tok.kind != .Ident do return nil
  css_advance(p)

  s := new_css_node(CSS_Simple_Selector, start, p.allocator)
  s.kind = .Pseudo
  s.name = strings.clone(tok.text, p.allocator)

  // functional pseudo, :not(...)
  if css_at(p, .Open_Paren) {
    depth := 0
    for !css_at(p, .EOF) {
      if css_at(p, .Open_Paren) {
        depth += 1
        css_advance(p)
        continue
      }
      if css_at(p, .Close_Paren) {
        depth -= 1
        css_advance(p)
        if depth == 0 do break
        continue
      }
      css_advance(p)
    }
  }

  return s
}

@(private="file")
unquote_css :: proc(s: string) -> string {
  if len(s) >= 2 && (s[0] == '"' || s[0] == '\'') && s[len(s)-1] == s[0] {
    return s[1:len(s)-1]
  }
  return s
}

// Reads all selectors that belong to one compound selector
@(private="file")
parse_compound :: proc(p: ^CSS_Parser) -> ^CSS_Compound {
  start := css_peek(p).pos
  simples := make([dynamic]^CSS_Simple_Selector, p.allocator)

  for {
    tok := css_peek(p)
    if len(simples) > 0 && tok.preceded_by_space do break
    if !css_can_start_simple(tok) do break

    simple := parse_simple(p)
    if simple == nil do break
    append(&simples, simple)
  }

  if len(simples) == 0 do return nil

  compound := new_css_node(CSS_Compound, start, p.allocator)
  compound.simples = simples
  return compound
}

@(private="file")
parse_selector :: proc(p: ^CSS_Parser) -> ^CSS_Selector {
  start := css_peek(p).pos

  first := parse_compound(p)
  if first == nil do return nil

  parts := make([dynamic]^CSS_Compound, p.allocator)
  append(&parts, first)

  loop: for {
    tok := css_peek(p)
    if tok.kind == .Comma || tok.kind == .Open_Brace || tok.kind == .Close_Brace || tok.kind == .Close_Paren || tok.kind == .EOF do break

    combinator: CSS_Combinator
    #partial switch tok.kind {
    case .Greater:
      css_advance(p)
      combinator = .Child
    case .Plus:
      css_advance(p)
      combinator = .Adjacent
    case .Tilde:
      css_advance(p)
      combinator = .Sibling
    case:
      if !tok.preceded_by_space do break loop
      combinator = .Descendant
    }

    if !css_can_start_simple(css_peek(p)) do break

    compound := parse_compound(p)
    if compound == nil do break
    parts[len(parts)-1].combinator = combinator
    append(&parts, compound)
  }

  selector := new_css_node(CSS_Selector, start, p.allocator)
  selector.parts = parts
  selector.specificity = compute_specificity(parts)
  return selector
}

@(private="file")
parse_selector_list :: proc(p: ^CSS_Parser) -> [dynamic]^CSS_Selector {
  list := make([dynamic]^CSS_Selector, p.allocator)

  for {
    selector := parse_selector(p)
    if selector == nil do break
    append(&list, selector)

    if css_at(p, .Comma) {
      css_advance(p)
      continue
    }
    break
  }

  return list
}

@(private="file")
parse_declaration :: proc(p: ^CSS_Parser) -> ^CSS_Declaration {
  start := css_peek(p).pos

  name, ok := css_take_ident(p)
  if !ok do return nil
  if !css_expect(p, .Colon) do return nil

  // value is kept as raw source text
  value_start := css_peek(p).pos.offset
  value_end := value_start
  for {
    tok := css_peek(p)
    if tok.kind == .Semicolon || tok.kind == .Close_Brace || tok.kind == .EOF do break
    value_end = tok.pos.offset + len(tok.text)
    css_advance(p)
  }

  raw := strings.trim_space(p.source[value_start:value_end])
  important := false
  if bang := strings.index(raw, "!"); bang >= 0 {
    if strings.equal_fold(strings.trim_space(raw[bang+1:]), "important") {
      important = true
      raw = strings.trim_space(raw[:bang])
    }
  }

  if css_at(p, .Semicolon) do css_advance(p)

  declaration := new_css_node(CSS_Declaration, start, p.allocator)
  declaration.name = name
  declaration.value = strings.clone(raw, p.allocator)
  declaration.important = important
  return declaration
}

@(private="file")
parse_declaration_list :: proc(p: ^CSS_Parser) -> [dynamic]^CSS_Declaration {
  declarations := make([dynamic]^CSS_Declaration, p.allocator)

  for {
    tok := css_peek(p)
    if tok.kind == .Close_Brace || tok.kind == .EOF do break

    declaration := parse_declaration(p)
    if declaration == nil {
      // drop tokens until the next declaration
      for !css_at(p, .Semicolon) && !css_at(p, .Close_Brace) && !css_at(p, .EOF) {
        css_advance(p)
      }
      if css_at(p, .Semicolon) do css_advance(p)
      continue
    }
    append(&declarations, declaration)
  }

  return declarations
}

@(private="file")
parse_rule :: proc(p: ^CSS_Parser) -> ^CSS_Rule {
  start := css_peek(p).pos

  // wrap the selector list in parens after a `rule`
  wrapped := false
  if tok := css_peek(p); tok.kind == .Ident && tok.text == "rule" {
    wrapped = true
    css_advance(p)
    if !css_expect(p, .Open_Paren) do return nil
  }

  selectors := parse_selector_list(p)

  if wrapped && !css_expect(p, .Close_Paren) do return nil
  if !css_expect(p, .Open_Brace) do return nil

  declarations := parse_declaration_list(p)
  css_expect(p, .Close_Brace)

  rule := new_css_node(CSS_Rule, start, p.allocator)
  rule.selectors = selectors
  rule.declarations = declarations
  return rule
}

// Computes specificity following the W3 css standard
@(private="file")
compute_specificity :: proc(parts: [dynamic]^CSS_Compound) -> [3]int {
  spec: [3]int
  for compound in parts {
    for simple in compound.simples {
      switch simple.kind {
      case .Id:
        spec[0] += 1
      case .Class, .Attribute, .Pseudo:
        spec[1] += 1
      case .Type:
        spec[2] += 1
      case .Universal:
      }
    }
  }
  return spec
}

parse_css :: proc(p: ^CSS_Parser) {
  if len(p.source) == 0 {
    if !read_stylesheet(p) do return
  }

  p.sheet = new_css_node(CSS_Stylesheet, CSS_Pos{}, p.allocator)
  p.sheet.rules = make([dynamic]^CSS_Rule, p.allocator)

  tokenize_css(p)

  p.index = 0
  for !css_at(p, .EOF) {
    rule := parse_rule(p)
    if rule == nil {
      // nothing valid, skip token
      css_advance(p)
      continue
    }
    append(&p.sheet.rules, rule)
  }
}
