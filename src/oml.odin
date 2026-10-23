package oml

import "vendor:sdl3"
import "core:log"
import "base:runtime"
import "core:mem"
import oml "internal"
import rend "internal/renderer"


init :: proc(doc: ^Document) {
	// context.logger = log.create_console_logger()
	doc.allocator = runtime.heap_allocator()
	doc._arena = new(mem.Dynamic_Arena, doc.allocator)
	doc._arena.block_allocator = doc.allocator
	doc._arena.block_size = 1024

	mem.dynamic_arena_init(doc._arena, doc.allocator, doc.allocator)
	doc.arena = mem.dynamic_arena_allocator(doc._arena)
}

create_document :: proc() -> ^Document {
	d := new(Document)
	d.loaded_styles = make([dynamic]^CSS_Stylesheet)
	return d
}

// Sets a nodes dirty flag to tell the engine that something is out of date
dirty_node :: proc(n: ^Node) {

}

// Schedules a layout recalculation for some point in the future
//
// This is usually done before the next frame is displayed
schedule_reflow :: proc(r: ^Renderer) {
	if is_reflow_pending(r) {
		log.logf(.Debug, "There was already a pending reflow, not scheduling for another")
		return
	}
	update_pending_reflow(r, true)
	oml.schedule(r, proc(op: ^Event_Op, r: ^Renderer) {
		rend.reflow(r)
		update_pending_reflow(r, false)
	})
}

repaint_sync :: proc(r: ^Renderer) {
	d_change := false
	rend.get_deltas(r.document.body, &r.deltas, &d_change)

	if d_change {
		rend.update_dirty(r.document.body)
		rend.paint(r, r.deltas)
		r.deltas = {}
	}
}

// Schedules a paint recalculation for some point in the future
//
// This is usually done before the next frame is displayed
schedule_repaint :: proc(r: ^Renderer) {
	oml.schedule(r, proc(op: ^Event_Op, r: ^Renderer) {
		repaint_sync(r)
		// Do we need to redraw the screen instantly?
		// draw_now(r)
	})
}

// Schedules the screen to redraw at some point in the future
schedule_redraw :: proc() {

}

draw_loop :: proc(r: ^Renderer) {
	oml.timeout(16_000_000, r, proc(op: ^Event_Op, r: ^Renderer) {
		rend.draw_screen(r)
		draw_loop(r)
	})
}

// Recalculates layout almost instantly
reflow_now :: proc(r: ^Renderer) {
	log.logf(.Info, "A reflow was requested to happen now")
	rend.reflow(r)
}

// Recalculates paint almost instantly
repaint_now :: proc(r: ^Renderer) {
	log.logf(.Info, "A repaint was requested to happen now")
	rend.paint(r, r.deltas)
}

// Redraws almost instantly
redraw_now :: proc(r: ^Renderer) {
	// do we need to schedule it to happen in the next tick?
	oml.schedule(r, proc(op: ^Event_Op, r: ^Renderer) {
		rend.draw_screen(r)
	})
}

// Recalculates layout, paint and redraws almost instantly
recalc_all_now :: proc(r: ^Renderer) {
	oml.schedule(r, proc(op: ^Event_Op, r: ^Renderer) {
		rend.rebuild_texture(r) // Takes too long when window is large
		reflow_now(r)
		repaint_sync(r)
		redraw_now(r)
		// rend.draw_screen(r)
	})
}

// checks if a reflow has already been scheduled for checks to avoid making multiple requests
is_reflow_pending :: proc(r: ^Renderer) -> bool {
	return r.pending.reflow
}

update_pending_reflow :: proc(r: ^Renderer, s: bool) {
	r.pending.reflow = s
}

update_pending_repaint :: proc(r: ^Renderer, s: bool) {
	r.pending.repaint = s
}

// checks if a repaint has already been scheduled for checks to avoid making multiple requests
is_repaint_pending :: proc(r: ^Renderer) -> bool {
	return r.pending.repaint
}

// unschedules pending reflows and instead runs them all now, this is useful if the runtime is requesting a computed value that might not be up to date
dump_pending_reflow :: proc() {

}

// unschedules pending repaints and instead runs them all now, this is useful if the runtime is requesting a computed value that might not be up to date
dump_pending_repaint :: proc() {

}

create_parser :: oml.create_parser

load :: proc(d: ^Document) {
	oml.schedule(d, proc(op: ^oml.Event_Op, d: ^Document) {
		oml.parse_oml(d.parser)
		d.body.render.dirty = {.Layout, .Paint, .Style}
		
		log.logf(.Info, "Successfully parsed OML document and its render-blocking imports.")
		
		oml.find_styles(d, d.body)
		oml.destroy_parser(d.parser)
	})
}


loop :: proc(r: ^Renderer) {
	mainloop: for {
		for e: sdl3.Event; sdl3.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT, .WINDOW_CLOSE_REQUESTED, .LOW_MEMORY:
				log.log(.Debug, "Requested program close")
				break mainloop
			case .WINDOW_RESIZED:
				// clear_now(r)
				log.logf(.Info, "Window has been resized. Recalculating layout.")
				rend.set_window_size(r, f32(e.display.data1), f32(e.display.data2))
				recalc_all_now(r)
			case .MOUSE_MOTION:
				// This just runs (getmousepos), even though this event passes out the data of the mouse move
				rend.update_mouse(r)
			}
		}

		// cb(..args)
		oml.tick_loop()
	}
}

delete_data :: proc(node: ^Node) {
	delete(node.render.ops)
	delete(node.render.lines)
	delete(node.class)
	delete(node.applied_styles)
	defer delete(node.children)
	for n in node.children do delete_data(n)
}

cleanup :: proc(doc: ^Document) {
	delete_data(doc.tree)
	delete(doc.loaded_styles)
}

quit :: proc(doc: ^Document) {

}

start_event_loop :: oml.start_event_loop
close_event_loop :: oml.close_event_loop

