package omlruntime

import oml "../"
import ocss "../ocss"
import lua "vendor:lua/5.4"
import "core:c"
import "core:fmt"
import "base:runtime"

add_pointer_to_stack :: proc(L: ^lua.State, ptr: rawptr) {
	lua.pushlightuserdata(L, ptr)
}

send_dom :: proc(L: ^lua.State, doc: ^oml.Document) {
	lua.pushlightuserdata(L, doc)
}

send_proc_with_data :: proc(L: ^lua.State, func: lua.CFunction, name: cstring, data_params: int = 0) {
	lua.pushcclosure(L, func, cast(c.int)data_params)
	lua.setglobal(L, name)
}

send_proc:: proc(L: ^lua.State, func: lua.CFunction, name: cstring) {
	lua.pushcfunction(L, func)
	lua.setglobal(L, name)
}

items_in_stack :: proc(L: ^lua.State) -> int {
	return cast(int)lua.gettop(L)
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

  push_node(L, node, doc)
  return 1
}

get_elements_by_class :: proc "c" (L: ^lua.State) -> c.int {
  context = runtime.default_context()
  doc := cast(^oml.Document)lua.touserdata(L, lua.REGISTRYINDEX - 1)
  if doc == nil {
    lua.pushnil(L)
    return 1
  }

  nodes := oml.get_elements_by_class(doc, string(lua.L_checkstring(L, 1)))
  if nodes == nil || len(nodes) == 0 {
    lua.pushnil(L)
    return 1
  }

  lua.newtable(L)
  for node, i in nodes {
    push_node(L, node, doc)
    // rawseti writes t[i+1] = node and pops it; rawgeti would only read.
    lua.rawseti(L, -2, lua.Integer(i + 1))
  }
  return 1
}

set_background_color :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	// gets the pointer to the passed in table,
	// stack is now [arg, ptr]
	// 							 1    2
	// -1 is used to push to top

	elem := lua.topointer(L, 1) // arg 1 (<table>, string)
	color := string(lua.L_checkstring(L, 2)) // arg 2 (table, <string>)

	// get the element
	// -2 is used as this will be pushed to the top.
	// offset by 1
	lua.getfield(L, -2, "__node")
	node := cast(^oml.Node)lua.topointer(L, -1)
	lua.pop(L, 3) // obliterate stack so i dont have to manage anything

	parsed_color, ok := ocss.parse_color(color)

	if ok == false {
		lua.pushboolean(L, false)
		return 1
	}

	node.styles.properties.backgroundColor = parsed_color

	lua.pushboolean(L, true)
	return 1
}

set_cursor_look :: proc "c" (L: ^lua.State) -> c.int {
  context = runtime.default_context()
  cursor := string(lua.L_checkstring(L, 1))
  ok := oml.set_cursor(cursor)
  
  lua.pushboolean(L, b32(ok))
  return 1
}

load_oml_lib :: proc(doc: ^oml.Document, L: ^lua.State) {
  add_pointer_to_stack(L, doc)
  send_proc_with_data(L, get_element_by_id, "get_element_by_id", 1)
  
  add_pointer_to_stack(L, doc)
  send_proc_with_data(L, get_elements_by_class, "get_elements_by_class", 1)

  send_proc(L, set_background_color, "set_color")
  send_proc(L, set_cursor_look, "set_cursor_look")
}

init_oml_runtime :: proc(doc: ^oml.Document) {
  for script in doc.scripts {
    fmt.printfln("Starting runtime for imported file: %v", script.name)
    script.lua_state = lua.L_newstate()
    L := script.lua_state
    lua.L_openlibs(L)

    load_oml_lib(doc, L)

    if lua.L_dofile(L, script.name) != 0 {
      fmt.eprintfln("lua error in %v: %s", script.name, lua.tostring(L, -1))
      lua.pop(L, 1)
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
