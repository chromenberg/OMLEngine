package omlruntime

import "core:c"
import "base:runtime"
import "core:fmt"
import "shared:clay"
import lua "vendor:lua/5.4"
import oml "../oml"

// Odin string -> Lua string. Ids/tags/classes are not NUL terminated, so use
// pushlstring (pushstring would read past the end).
lua_string :: proc(L: ^lua.State, s: string) {
  lua.pushlstring(L, cast(cstring)raw_data(s), c.size_t(len(s)))
}

// === enum -> readable name helpers ===

node_type_name :: proc(t: oml.NodeType) -> string {
  switch t {
  case .Root:     return "root"
  case .Head:     return "head"
  case .Link:     return "link"
  case .Body:     return "body"
  case .Rect:     return "rect"
  case .Text:     return "text"
  case .Button:   return "button"
  case .InputBox: return "inputbox"
  case .Input:    return "input"
  }
  return "unknown"
}

direction_name :: proc(d: clay.LayoutDirection) -> string {
  switch d {
  case .LeftToRight: return "row"
  case .TopToBottom: return "column"
  }
  return "row"
}

align_x_name :: proc(a: clay.LayoutAlignmentX) -> string {
  switch a {
  case .Left:   return "left"
  case .Right:  return "right"
  case .Center: return "center"
  }
  return "left"
}

align_y_name :: proc(a: clay.LayoutAlignmentY) -> string {
  switch a {
  case .Top:    return "top"
  case .Bottom: return "bottom"
  case .Center: return "center"
  }
  return "top"
}

sizing_type_name :: proc(t: clay.SizingType) -> string {
  switch t {
  case .Fit:     return "fit"
  case .Grow:    return "grow"
  case .Percent: return "percent"
  case .Fixed:   return "fixed"
  }
  return "fit"
}

// === value pushers (each leaves exactly ONE value on the stack) ===

push_string_array :: proc(L: ^lua.State, values: []string) {
  lua.newtable(L)
  for value, i in values {
    lua_string(L, value)
    lua.rawseti(L, -2, lua.Integer(i + 1))
  }
}

push_color :: proc(L: ^lua.State, color: clay.Color) {
  lua.newtable(L)
  lua.pushnumber(L, lua.Number(color[0])); lua.setfield(L, -2, "r")
  lua.pushnumber(L, lua.Number(color[1])); lua.setfield(L, -2, "g")
  lua.pushnumber(L, lua.Number(color[2])); lua.setfield(L, -2, "b")
  lua.pushnumber(L, lua.Number(color[3])); lua.setfield(L, -2, "a")
}

push_axis :: proc(L: ^lua.State, axis: clay.SizingAxis) {
  lua.newtable(L)

  lua_string(L, sizing_type_name(axis.type))
  lua.setfield(L, -2, "type")

  value: f64
  switch axis.type {
  case .Percent:            value = f64(axis.constraints.sizePercent)
  case .Fit, .Grow, .Fixed: value = f64(axis.constraints.sizeMinMax.min)
  }
  lua.pushnumber(L, lua.Number(value)); lua.setfield(L, -2, "value")
  lua.pushnumber(L, lua.Number(axis.constraints.sizeMinMax.min)); lua.setfield(L, -2, "min")
  lua.pushnumber(L, lua.Number(axis.constraints.sizeMinMax.max)); lua.setfield(L, -2, "max")
}

// The resolved clay config of a node (nil when nothing matched it).
push_styles :: proc(L: ^lua.State, node: ^oml.Node) {
  if node.styles == nil {
    lua.pushnil(L)
    return
  }

  props := node.styles.properties
  lua.newtable(L) // [s]

  push_color(L, props.backgroundColor)
  lua.setfield(L, -2, "background_color")

  lua.newtable(L) // corner_radius
  lua.pushnumber(L, lua.Number(props.cornerRadius.topLeft));     lua.setfield(L, -2, "top_left")
  lua.pushnumber(L, lua.Number(props.cornerRadius.topRight));    lua.setfield(L, -2, "top_right")
  lua.pushnumber(L, lua.Number(props.cornerRadius.bottomLeft));  lua.setfield(L, -2, "bottom_left")
  lua.pushnumber(L, lua.Number(props.cornerRadius.bottomRight)); lua.setfield(L, -2, "bottom_right")
  lua.setfield(L, -2, "corner_radius")

  lua.newtable(L) // padding
  lua.pushinteger(L, lua.Integer(props.layout.padding.left));   lua.setfield(L, -2, "left")
  lua.pushinteger(L, lua.Integer(props.layout.padding.right));  lua.setfield(L, -2, "right")
  lua.pushinteger(L, lua.Integer(props.layout.padding.top));    lua.setfield(L, -2, "top")
  lua.pushinteger(L, lua.Integer(props.layout.padding.bottom)); lua.setfield(L, -2, "bottom")
  lua.setfield(L, -2, "padding")

  lua.pushinteger(L, lua.Integer(props.layout.childGap))
  lua.setfield(L, -2, "gap")

  lua_string(L, direction_name(props.layout.layoutDirection))
  lua.setfield(L, -2, "direction")
  lua_string(L, align_x_name(props.layout.childAlignment.x))
  lua.setfield(L, -2, "align_items")
  lua_string(L, align_y_name(props.layout.childAlignment.y))
  lua.setfield(L, -2, "justify_content")

  push_axis(L, props.layout.sizing.width);  lua.setfield(L, -2, "width")
  push_axis(L, props.layout.sizing.height); lua.setfield(L, -2, "height")
}

// Converts a whole node (and its subtree) into a Lua table.
//
// `parent` is exposed as an opaque light-userdata handle rather than a table, so
// building the tree can never recurse back into a cycle.
push_node :: proc(L: ^lua.State, node: ^oml.Node) {
  lua.newtable(L) // [t]

  lua_string(L, node.id)
  lua.setfield(L, -2, "id")
  lua_string(L, node.tag)
  lua.setfield(L, -2, "tag")
  lua_string(L, node_type_name(node.type))
  lua.setfield(L, -2, "type")

  lua.pushboolean(L, b32(node.has_children))
  lua.setfield(L, -2, "has_children")
  lua.pushinteger(L, lua.Integer(node.refs))
  lua.setfield(L, -2, "refs")

  push_string_array(L, node.classes)
  lua.setfield(L, -2, "classes")

  if node.parent != nil {
    lua.pushlightuserdata(L, node.parent)
  } else {
    lua.pushnil(L)
  }
  lua.setfield(L, -2, "parent")

  // children, recursively
  lua.newtable(L)
  for child, i in node.children {
    push_node(L, child)
    lua.rawseti(L, -2, lua.Integer(i + 1))
  }
  lua.setfield(L, -2, "children")

  push_styles(L, node)
  lua.setfield(L, -2, "styles")
}

// Lua: local n = get_element_by_id("url_box"); print(n.id, n.children[1].tag)
get_element_by_id :: proc "c" (L: ^lua.State) -> c.int {
  context = runtime.default_context()
  doc := cast(^oml.Document)lua.touserdata(L, lua.REGISTRYINDEX - 1)
  if doc == nil {
    lua.pushnil(L)
    return 1
  }

  node := oml.get_element_by_id(doc, string(lua.L_checkstring(L, 1)))
  if node == nil {
    lua.pushnil(L)
    return 1
  }

  push_node(L, node)
  return 1
}

init_oml_runtime :: proc(doc: ^oml.Document) {
  for script in doc.scripts {
    fmt.printfln("Starting runtime for imported file: %v", script.name)
    script.lua_state = lua.L_newstate()
    lua.L_openlibs(script.lua_state)

    lua.pushlightuserdata(script.lua_state, doc)
    lua.pushcclosure(script.lua_state, get_element_by_id, 1)
    lua.setglobal(script.lua_state, "get_element_by_id")

    if lua.L_dofile(script.lua_state, script.name) != 0 {
      fmt.eprintfln("lua error in %v: %s", script.name, lua.tostring(script.lua_state, -1))
      lua.pop(script.lua_state, 1)
    }
  }
}

close_runtimes :: proc(doc: ^oml.Document) {
  for script in doc.scripts {
    fmt.printfln("Closing runtime for imported file: %v", script.name)
    L := script.lua_state
    lua.close(L)
  }
}
