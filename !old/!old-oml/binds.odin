package oml

import "vendor:raylib"
import "core:fmt"

doc_traverse :: proc(doc: ^Document, node: ^Node, callback: proc(node: ^Node, data: $N) -> bool, data: $T) -> ^Node {
  return_val : ^Node = nil
  for child in node.children {
    if return_val != nil do break
    if callback(child, data) {
      return_val = child
      break
    }
    // set the return value to the next recursion
    // to hoist the result back up
    return_val = doc_traverse(doc, child, callback, data)
  }
  return return_val
}

doc_traverse_all :: proc(
  doc: ^Document,
  node: ^Node,
  callback: proc(node: ^Node, data: $N) -> bool,
  data: $T,
  output: ^[dynamic]^$E
) -> ^[dynamic]^E {
  for child in node.children {
    if callback(child, data) {
      append(output, child)
    }
    // set the return value to the next recursion
    // to hoist the result back up
    doc_traverse_all(doc, child, callback, data, output)
  }
  return output // return the output if you want to use it that way
}

get_element_by_id :: proc(doc: ^Document, id: string) -> ^Node {
	return doc_traverse(doc, doc.tree, proc(node: ^Node, data: string) -> bool {
	  return node.id == data
	}, id)
}

get_elements_by_class :: proc(doc: ^Document, class: string) -> [dynamic]^Node {
  output : [dynamic]^Node
	doc_traverse_all(doc, doc.tree, proc(node: ^Node, data: string) -> bool {
	  for class in node.classes {
			if class == data do return true
		}
		return false
	}, class, &output)
	return output
}

Cursor_Look := [len(raylib.MouseCursor)]string {
  "default",
  "arrow",
  "beam",
  "cross",
  "pointer",
  "resize-horizontal",
  "resize-vertical",
  "resize-desc",
  "resize-asc",
  "resize",
  "not-allowed"
}

// CursorLooks :: Cursor_Look

set_cursor :: proc(type: string) -> bool {
  for look, i in Cursor_Look {
    if look == type {
      raylib.SetMouseCursor(cast(raylib.MouseCursor)i)
      return true
    }
  }
  return false
}