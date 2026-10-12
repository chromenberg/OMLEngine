package oml

import "shared:clay"

// Every kind of event a node can emit.
Event_Kind :: enum {
  Hover,
  Hover_Enter,
  Hover_Leave,
  Click,
  Press,
  Release,
}

Event_Node :: struct {
  kind:      Event_Kind,
  callback:  proc(node: ^Node, user_data: rawptr),
  user_data: rawptr,
  next:      ^Event_Node, // stored as a linked list
}

node_on :: proc(
  node: ^Node,
  kind: Event_Kind,
  callback: proc(node: ^Node, user_data: rawptr),
  user_data: rawptr,
  allocator := context.allocator,
) {
  entry := new(Event_Node, allocator)
  entry^ = {
    kind      = kind,
    callback  = callback,
    user_data = user_data,
    next      = node.events,
  }
  node.events = entry
}

node_off :: proc(node: ^Node, kind: Event_Kind) {
  previous: ^Event_Node = nil
  entry := node.events

  for entry != nil {
    next := entry.next
    if entry.kind == kind {
      if previous == nil {
        node.events = next
      } else {
        previous.next = next
      }
    } else {
      previous = entry
    }
    entry = next
  }
}

// Fires `kind` on `node`, calling every matching listener.
node_emit :: proc(node: ^Node, kind: Event_Kind) {
  entry := node.events
  for entry != nil {
    if entry.kind == kind && entry.callback != nil {
      entry.callback(node, entry.user_data)
    }
    entry = entry.next
  }
}

// Maps a script event name to a kind.
event_kind_from_name :: proc(name: string) -> (Event_Kind, bool) {
  switch name {
  case "hover":       return .Hover, true
  case "hover_enter": return .Hover_Enter, true
  case "hover_leave": return .Hover_Leave, true
  case "click":       return .Click, true
  case "press":       return .Press, true
  case "release":     return .Release, true
  }
  return .Hover, false
}

// TODO: Remake this MYSELF so i can still work on it.
// TODO: Made with deepseek for getting a rough idea on HOW i could manage this
// but not HOW i will do it

// Runs the built-in triggers for the element currently open in clay.
//
// Called from the render pass while the element is open, so clay's `Hovered()`
// and pointer state refer to it. Only nodes that actually have listeners are
// inspected.
dispatch_events :: proc(node: ^Node) {
  if node.events == nil do return

  hovered := clay.Hovered()
  pointer := clay.GetPointerState()

  if hovered {
    node_emit(node, .Hover)
    if !node.was_hovered do node_emit(node, .Hover_Enter)

    #partial switch pointer.state {
    case .PressedThisFrame:
      node_emit(node, .Press)
      node_emit(node, .Click)
    case .ReleasedThisFrame:
      node_emit(node, .Release)
    }
  } else if node.was_hovered {
    node_emit(node, .Hover_Leave)
  }

  node.was_hovered = hovered
}
