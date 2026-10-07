package main
import "oml"
import "core:log"
import "core:mem"
import "core:fmt"
import "vendor:raylib"
Vector2 :: raylib.Vector2

WindowScale : Vector2 = {640, 480}
WindowWidth := WindowScale[0]
WindowHeight := WindowScale[1]


load_font :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
  	&raylib_fonts,
  	fontId,
  	RL_Font{
  	  font = raylib.LoadFontEx(
  			path,
  			cast(i32)fontSize * 2, nil, 0
  		),
  		fontID = cast(u16)fontId
  	}
	)

	raylib.SetTextureFilter(
	  raylib_fonts[fontId].font.texture,
		raylib.TextureFilter.BILINEAR
	)
}

main :: proc() {
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

	doc : oml.Document
	doc.backing = make([]byte, 5*1024)
	oml.parse("./tests/test.oml", &doc)
  defer delete(doc.backing)
  defer free_all(doc.allocator)

  memory:= make([^]u8, layout_engine_min_memory())
  defer free(memory)
  init_renderer(&memory)
  defer delete(raylib_fonts)

  for !raylib.WindowShouldClose() {
  	defer free_all(context.temp_allocator)
		render(&doc)
  }
}
