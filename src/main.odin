package oml

import "base:runtime"
import "core:log"
import "core:mem"
import "core:nbio"

// Represents the entire page, everything to do with DOM creation, OCSSOM creation and bindings are held here
Document :: struct {
	allocator: mem.Allocator,

	// document arena, used for temporary allocations like parsing before cloning finalized data out into the main allocator to last for the lifetime of the process
	arena: mem.Allocator,

	// inner data of the docs arena allocator
	_arena: ^mem.Dynamic_Arena,
	// store the event loop in the doc?
	event_loop: nbio.Event_Loop,

	file: File,
	// root of the dom parsed out of the oml file
	tree: ^Node,
	// loaded_scripts: nil,
	// loaded_styles: nil
}

File :: struct {
	name: string,
	src: string,

	errors: int,
	warns: int,
}

Parser :: struct {
	// this is redirected to `Document.allocator`
	allocator: mem.Allocator,
	arena: mem.Allocator,
	file: File,
	source: string,
}



init :: proc(doc: ^Document) {
	// context.logger = log.create_console_logger()
	doc.allocator = runtime.heap_allocator()
	doc._arena = new(mem.Dynamic_Arena, doc.allocator)
	doc._arena.block_allocator = doc.allocator
	doc._arena.block_size = 1024

	mem.dynamic_arena_init(doc._arena, doc.allocator, doc.allocator)
	doc.arena = mem.dynamic_arena_allocator(doc._arena)
}

clean_doc :: proc(doc: ^Document) {
	free_all(doc.arena)
	free_all(doc.allocator)
}
