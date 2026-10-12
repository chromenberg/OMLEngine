package main
import "oml"
import "core:os"
import "core:log"
import "core:mem"
import "core:fmt"
import "vendor:raylib"
import script "oml/runtime"

Vector2 :: raylib.Vector2

WindowScale : Vector2 = {640, 480}
WindowWidth := WindowScale[0]
WindowHeight := WindowScale[1]

DIR := ""
NAME := ""




set_dir :: proc() {
	DIR, NAME = os.split_path(os.args[1])
	os.set_working_directory(DIR)
}


main :: proc() {
	if len(os.args) < 2 {
		return
	}
	set_dir()
	context.logger = log.create_console_logger()
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
				fmt.eprintf("=== total size %v kb ===\n", track.current_memory_allocated/1024)

			}
			mem.tracking_allocator_destroy(&track)
		}
	}

  memory:= make([^]u8, layout_engine_min_memory())
  defer free(memory)
  init_renderer(&memory)

  doc := new(oml.Document)
  set_measure_document(doc)
  defer free(doc)
  
  doc.backing = make([]byte, 256*1024)
  defer delete(doc.backing)
  defer free_all(doc.allocator)
  
  oml.parse(NAME, doc)
  script.init_oml_runtime(doc)
  defer script.close_runtimes(doc)

  for !raylib.WindowShouldClose() {
  	defer free_all(context.temp_allocator)
		update_data()
		render(doc)
  }

  fmt.println("Deallocating before program exit")
  free_all(context.allocator)
  free_all(context.temp_allocator)
}

nuke :: proc(doc: ^oml.Document) {
 
}