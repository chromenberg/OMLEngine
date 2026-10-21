package main

import "vendor:sdl3"
import "core:time"
import "core:nbio"
import "core:log"
import "core:mem"
import "core:fmt"
import oml "../../src"
import "../../src/renderer"

schedule_repaint :: proc(w: ^renderer.Renderer) {
	oml.schedule(w, proc(op: ^oml.Event_Op, w: ^renderer.Renderer) {
		log.logf(.Debug, "Drawing")

		renderer.paint(w, w.deltas)
		w.deltas = {}
	})
}
schedule_deltas :: proc(r: ^renderer.Renderer) {
	oml.schedule(r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		d_change := false
		renderer.get_deltas(r.document.body, &r.deltas, &d_change)

		if d_change {
			renderer.update_dirty(r.document.body)
			renderer.paint(r, r.deltas)
			r.deltas = {}
		}

		draw_now(r)
	})
}
schedule_reflow :: proc (r: ^renderer.Renderer) {
	oml.schedule(r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		renderer.reflow(r)
	})
}

schedule_draw :: proc (r: ^renderer.Renderer) {
	oml.timeout(16_000_000, r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		renderer.draw_screen(r)
		schedule_draw(r)
	})
}

draw_now :: proc (r: ^renderer.Renderer) {
	oml.schedule(r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		renderer.draw_screen(r)
	})
}
clear_now :: proc (r: ^renderer.Renderer) {
	oml.schedule(r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		renderer.clear_screen(r)
	})
}

// Sequentially recalculates everything, 
// builds texture -> reflow -> deltas -> repaint -> clear
full_recalc :: proc(r: ^renderer.Renderer) {
	oml.schedule(r, proc(op: ^oml.Event_Op, r: ^renderer.Renderer) {
		renderer.rebuild_texture(r) // Takes too long when window is large 
		renderer.reflow(r)
		
		d_change := false
		renderer.get_deltas(r.document.body, &r.deltas, &d_change)

		if d_change {
			renderer.update_dirty(r.document.body)
			renderer.paint(r, r.deltas)
			r.deltas = {}
		}
		
		renderer.draw_screen(r)
	})
}
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
	r := renderer.init()
	// doc: oml.Document
	r.document.file.src = "examples/vortex/resources/pages/vortex-launcher.oml"

	oml.start_event_loop()
	defer oml.close_event_loop()

	oml.init(r.document)
	defer oml.clean_doc(r.document)

	oml_parse : oml.OML_Parser
	oml_parse.allocator = r.document.allocator
	oml_parse.arena = r.document.arena
	oml_parse.doc = r.document
	oml_parse.file = r.document.file


	oml.schedule(&oml_parse, proc(op: ^oml.Event_Op, p: ^oml.OML_Parser) {
		oml.parse_oml(p)
		p.doc.body.render.dirty = {.Layout, .Paint, .Style}
		log.logf(.Info, "Successfully parsed OML document and its render-blocking imports.")
		oml.find_styles(p.doc, p.doc.body)
	})

	schedule_reflow(r)
	schedule_deltas(r)
	schedule_draw(r) // this starts a loop

	mainloop: for {
		// clear_now(r)
		
		for e: sdl3.Event; sdl3.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT, .WINDOW_CLOSE_REQUESTED, .LOW_MEMORY:
				log.log(.Debug, "Requested program close")
				break mainloop
			case .WINDOW_RESIZED:
				// clear_now(r)
				log.logf(.Info, "Window has been resized. Recalculating layout.")
				renderer.set_window_size(r, f32(e.display.data1), f32(e.display.data2))
				full_recalc(r)
			case .MOUSE_MOTION:
				// This just runs (getmousepos), even though this event passes out the data of the mouse move
				renderer.update_mouse(r)	
			}
		}

		// Right now reflows and paint changes are only ticked for resizes
		// However we should check when something is dirty and recalculate that
		
		schedule_reflow(r) // Recalculate layout every tick / TODO: Only recalc when needed 
		schedule_deltas(r) // Recalculate paint every tick / TODO: Only recalc when needed
		oml.tick_loop()
	}
}
