package oml


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

get_element_by_id :: proc(doc: ^Document, id: string) -> ^Node {
	return doc_traverse(doc, doc.tree, proc(node: ^Node, data: string) -> bool {
	  return node.id == data
	}, id)
}
