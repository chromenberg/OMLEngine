package main

import "core:time"
import "core:nbio"
import "core:log"
import "core:mem"
import "core:fmt"
import oml "../../src"

main :: proc() {
	context.logger = log.create_console_logger(.Debug)
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
				fmt.eprintfln("Total freed: %d | Total allocated: %d ", track.total_free_count, track.total_allocation_count)
				fmt.eprintfln("Peak usage: %d bytes | Current usage: %dbytes", track.peak_memory_allocated, track.current_memory_allocated)
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	doc: oml.Document
	doc.file.src = "examples/vortex/resources/pages/vortex-launcher.oml"

	oml.start_event_loop()
	defer oml.close_event_loop()

	oml.init(&doc)
	defer oml.clean_doc(&doc)

	oml_parse : oml.OML_Parser
	oml_parse.allocator = doc.allocator
	oml_parse.arena = doc.arena
	oml_parse.doc = &doc
	oml_parse.file = doc.file


	oml.schedule(&oml_parse, proc(op: ^oml.Event_Op, p: ^oml.OML_Parser) {
		oml.parse_oml(p)
	})

	oml.wake_loop()
}
