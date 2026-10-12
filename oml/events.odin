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

Event :: struct {
  kind:      Event_Kind,
  callback:  proc(node: ^Node, user_data: rawptr),
  user_data: rawptr,
  next:      ^Event, // stored as a linked list
}

node_on :: proc(
  node: ^Node,
  kind: Event_Kind,
  callback: proc(node: ^Node, user_data: rawptr),
  user_data: rawptr,
  allocator := context.allocator,
) {
  entry := new(Event, allocator)
  entry^ = {
    kind      = kind,
    callback  = callback,
    user_data = user_data,
    next      = node.events.event_list,
  }
  node.events.event_list = entry
}

node_off :: proc(node: ^Node, kind: Event_Kind) {
  previous: ^Event = nil
  entry := node.events.event_list

  for entry != nil {
    next := entry.next
    if entry.kind == kind {
      if previous == nil {
        node.events.event_list = next
      } else {
        previous.next = next
      }
    } else {
      previous = entry
    }
    entry = next
  }
}

// loops through all registered events and runs the events callback on those with the matching `Event_Kind`
emit :: proc(node: ^Node, kind: Event_Kind) {
  entry := node.events.event_list
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
  case "mouse:over":       return .Hover, true
  case "mouse:over.enter": return .Hover_Enter, true
  case "mouse:over.leave": return .Hover_Leave, true
  case "mouse:click":       return .Click, true
  case "mouse:down":       return .Press, true
  case "mouse:up":     return .Release, true
  }
  return .Hover, false
}

// TODO: Remake this MYSELF so i can still work on it.
// TODO: Made with deepseek for getting a rough idea on HOW i could manage this
// but not HOW i will do it

// dispatches events every tick, this should later be implemented to happen only once when needed
// 
// if an event state has changed then we can emit it
dispatch_events :: proc(node: ^Node) {
  if node.events.event_list == nil do return

  hovered := clay.Hovered()
  pointer := clay.GetPointerState()

  if hovered { // is the current node hovered?
    emit(node, .Hover) // if so, emit that we are hovered - this fires every tick
    if !node.events.hovered do emit(node, .Hover_Enter)

    #partial switch pointer.state {
    case .PressedThisFrame:
      emit(node, .Press)
      emit(node, .Click)
    case .ReleasedThisFrame:
      emit(node, .Release)
    }
  } else if node.events.hovered {
    emit(node, .Hover_Leave)
  }

  node.events.hovered = hovered
}
