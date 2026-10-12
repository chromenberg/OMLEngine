package main

import "core:c"
import "core:strings"
import "core:math"
import "base:runtime"
import rl "vendor:raylib"
import "shared:clay"
import "oml"

// The measure callback receives the document as userData (set via
// `set_measure_document`), so it can resolve the font the text was styled with.
measure_text_ascii :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, userData: rawptr) -> clay.Dimensions {
	context = runtime.default_context()
	doc := cast(^oml.Document)userData
	font := oml.get_font_by_id(doc, config.fontId)

	text_str := string(text.chars[:text.length])

	// no font loaded for that id: return a rough estimate so layout still runs
	if font.baseSize == 0 {
		return {width = f32(len(text_str)) * f32(config.fontSize) * 0.5, height = f32(config.fontSize)}
	}

	line_width: f32 = 0
	for i in 0 ..< len(text_str) {
		glyph_index := text_str[i] - 32
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
		}
	}

	scaleFactor := f32(config.fontSize) / f32(font.baseSize)
	total_spacing := f32(len(text_str)) * f32(config.letterSpacing)

	return {width = line_width * scaleFactor + total_spacing, height = f32(config.fontSize)}
}

// Point text measurement at a parsed document so it can resolve fonts by id.
// Call once after `oml.parse` and before the first frame.
set_measure_document :: proc(doc: ^oml.Document) {
	clay.SetMeasureTextFunction(measure_text_ascii, cast(rawptr)doc)
}

render_clip_start :: proc(render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
	rl.BeginScissorMode(i32(math.round(bounds.x)), i32(math.round(bounds.y)), i32(math.round(bounds.width)), i32(math.round(bounds.height)))
}

render_clip_end :: proc(render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
  rl.EndScissorMode()
}

render_border :: proc(render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
  config := render_command.renderData.border
		// Left border
		if config.width.left > 0 {
			draw_rect(
				bounds.x,
				bounds.y + config.cornerRadius.topLeft,
				f32(config.width.left),
				bounds.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft,
				config.color,
			)
		}
		// Right border
		if config.width.right > 0 {
			draw_rect(
				bounds.x + bounds.width - f32(config.width.right),
				bounds.y + config.cornerRadius.topRight,
				f32(config.width.right),
				bounds.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight,
				config.color,
			)
		}
		// Top border
		if config.width.top > 0 {
			draw_rect(
				bounds.x + (config.cornerRadius.topLeft),
				bounds.y,
				bounds.width - config.cornerRadius.topLeft - config.cornerRadius.topRight,
				f32(config.width.top),
				config.color,
			)
		}
		// Bottom border
		if config.width.bottom > 0 {
			draw_rect(
				bounds.x + config.cornerRadius.bottomLeft,
				bounds.y + bounds.height - f32(config.width.bottom),
				bounds.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight,
				f32(config.width.bottom),
				config.color,
			)
		}

		// Rounded Borders
		if config.cornerRadius.topLeft > 0 {
			draw_arc(
				bounds.x + config.cornerRadius.topLeft,
				bounds.y + config.cornerRadius.topLeft,
				config.cornerRadius.topLeft - f32(config.width.top),
				config.cornerRadius.topLeft,
				180,
				270,
				config.color,
			)
		}
		if config.cornerRadius.topRight > 0 {
			draw_arc(
				bounds.x + bounds.width - config.cornerRadius.topRight,
				bounds.y + config.cornerRadius.topRight,
				config.cornerRadius.topRight - f32(config.width.top),
				config.cornerRadius.topRight,
				270,
				360,
				config.color,
			)
		}
		if config.cornerRadius.bottomLeft > 0 {
			draw_arc(
				bounds.x + config.cornerRadius.bottomLeft,
				bounds.y + bounds.height - config.cornerRadius.bottomLeft,
				config.cornerRadius.bottomLeft - f32(config.width.top),
				config.cornerRadius.bottomLeft,
				90,
				180,
				config.color,
			)
		}
		if config.cornerRadius.bottomRight > 0 {
			draw_arc(
				bounds.x + bounds.width - config.cornerRadius.bottomRight,
				bounds.y + bounds.height - config.cornerRadius.bottomRight,
				config.cornerRadius.bottomRight - f32(config.width.bottom),
				config.cornerRadius.bottomRight,
				0.1,
				90,
				config.color,
			)
		}
}
render_text :: proc(doc: ^oml.Document, render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
  config := render_command.renderData.text

  // get the text up to the length of the string, because c sucks and ends all strings with \n
  text := string(config.stringContents.chars[:config.stringContents.length])

  // raylib uses cstrings, clay does not
  cstr_text := strings.clone_to_cstring(text, context.temp_allocator)

  font := oml.get_font_by_id(doc, config.fontId)
  rl.DrawTextEx(
    font,
    cstr_text,
    {bounds.x, bounds.y},
    f32(config.fontSize),
    f32(config.letterSpacing),
    clay_to_rl(config.textColor)
  )
}
render_rect :: proc(render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
  config := render_command.renderData.rectangle

  if is_rounded(config.cornerRadius) {
    radius: f32 = (config.cornerRadius.topLeft * 2) / min(bounds.width, bounds.height)
    draw_rect(
      bounds,
      radius,
      config.backgroundColor
    )
  } else {
    draw_rect(
      bounds,
      config.backgroundColor
    )
  }
}

render_image :: proc(overlay_colors: ^[dynamic]clay.Color, render_command: ^clay.RenderCommand, bounds: clay.BoundingBox) {
  config := render_command.renderData.image
	tint: clay.Color
	if len(overlay_colors) > 0 {
		tint = overlay_colors[len(overlay_colors) - 1]
	}
	if tint == 0 {
		tint = {255, 255, 255, 255}
	}

	imageTexture := (^rl.Texture2D)(config.imageData)
	rl.DrawTextureEx(imageTexture^, {bounds.x, bounds.y}, 0, bounds.width / f32(imageTexture.width), clay_to_rl(tint))
}


clay_render :: proc(
  commands: ^clay.ClayArray(clay.RenderCommand),
  doc: ^oml.Document,
  allocator := context.temp_allocator
) {
  overlay_colors := make([dynamic]clay.Color, allocator)
  for i in 0 ..< commands.length {
    render_command := clay.RenderCommandArray_Get(commands, i)
    bounds := render_command.boundingBox

    #partial switch render_command.commandType {
      case .None:
      case .Image:
        render_image(&overlay_colors, render_command, bounds)
      case .Rectangle:
        render_rect(render_command, bounds)
      case .Text:
        render_text(doc, render_command, bounds)
      case .Border:
   			render_border(render_command, bounds)
  		case .OverlayColorStart:
  			config := render_command.renderData.overlayColor
  			append(&overlay_colors, config.color)
  		case .OverlayColorEnd:
  			pop(&overlay_colors)
    }
  }
}

is_rounded :: proc(radius: clay.CornerRadius) -> bool {
  return radius.bottomLeft  > 0 ||
         radius.bottomRight > 0 ||
         radius.topLeft     > 0 ||
         radius.topRight    > 0
}

@(private="file", require_results)
f32_to_i32 :: proc "contextless" (x: f32) -> i32 {
  return #force_inline i32(math.round(x))
}

@(private="file")
clay_to_rl_color :: proc(color: clay.Color) -> rl.Color {
  return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

// This can also be applied to width and height
//
// #force_inline is applied as all this does is convert, it is actually heavier if it isnt inlined
@(require_results)
clay_to_rl_pos_only :: proc "contextless" (x, y: f32) -> (conv_x, conv_y: i32) {
  return #force_inline f32_to_i32(x), f32_to_i32(y)
}

// This can also be applied to width and height
//
// #force_inline is applied as all this does is convert, it is actually heavier if it isnt inlined
@(require_results)
clay_to_rl_pos_scale :: proc(in_x, in_y, in_w, in_h: f32) -> (x, y, w, h: i32) {
  return #force_inline f32_to_i32(in_x), f32_to_i32(in_y),f32_to_i32(in_w),f32_to_i32(in_h)
}

clay_to_rl :: proc{
  clay_to_rl_pos_only,
  clay_to_rl_pos_scale,
  clay_to_rl_color
}

// Draws a non rounded rectangle
//
// `x: f32` - X position
//
// `y: f32` - Y position
//
// `w: f32` - Width
//
// `h: f32` - Height
draw_rect_normal :: proc(x, y, w, h: f32, color: clay.Color) {
  rl.DrawRectangle(clay_to_rl(x, y, w, h), clay_to_rl(color))
}

// Draws a rounded rectangle with equal corner radius
//
// `x: f32` - X position
//
// `y: f32` - Y position
//
// `w: f32` - Width
//
// `h: f32` - Height
//
// `radius: f32` - Corner radius
draw_rect_rounded :: proc(x, y, w, h: f32, radius: f32, color: clay.Color, segments: i32 = 16) {
  rl.DrawRectangleRounded({x, y, w, h}, radius, segments, clay_to_rl(color))
}

draw_rect_with_bounds :: proc(bounds: clay.BoundingBox, color: clay.Color) {
  draw_rect(bounds.x, bounds.y, bounds.width, bounds.height, color)
}

// draws a rounded rectangle using the bounding box instead of deconstructed fields
draw_rect_with_bounds_rounded :: proc(bounds: clay.BoundingBox, radius: f32, color: clay.Color, segments: i32 = 16) {
  draw_rect(bounds.x, bounds.y, bounds.width, bounds.height, radius, color, segments)
}

draw_rect :: proc{
  draw_rect_normal,
  draw_rect_rounded,
  draw_rect_with_bounds,
  draw_rect_with_bounds_rounded
}

draw_arc :: proc(x, y: f32, inner_rad, outer_rad: f32, start_angle, end_angle: f32, color: clay.Color) {
	rl.DrawRing({math.round(x), math.round(y)}, math.round(inner_rad), outer_rad, start_angle, end_angle, 10, clay_to_rl(color))
}

error_handler :: proc "c" (data: clay.ErrorData) {

}


FONT_PATH :: "./resources/"
FONT_PRIMARY :: FONT_PATH + "Figtree.ttf"

layout_engine_min_memory :: proc() -> c.size_t {
	return cast(c.size_t)clay.MinMemorySize()
}

init_renderer :: proc(clay_mem: ^[^]u8) {
	// setup the layout manager

	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(
		layout_engine_min_memory(), clay_mem^
	)

	clay.Initialize(
		arena,
		{f32(WindowWidth),f32(WindowHeight)},
		{handler = error_handler}
	)
	clay.SetMeasureTextFunction(measure_text_ascii, nil)

	// setup renderer

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_HIGHDPI, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
  rl.InitWindow(i32(WindowWidth), i32(WindowHeight), "Erdene")
  rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

}

update_data :: proc() {
	WindowWidth = f32(rl.GetScreenWidth())
  WindowHeight = f32(rl.GetScreenHeight())

  clay.SetPointerState(
    rl.GetMousePosition(),
    rl.IsMouseButtonDown(rl.MouseButton.LEFT)
  )
  clay.SetLayoutDimensions({WindowWidth, WindowHeight})
}

render :: proc(doc: ^oml.Document) {
	commands := oml.render(doc, rl.GetFrameTime())

	rl.BeginDrawing()
  // rl.ClearBackground(clay_to_rl(doc.body.styles.properties.backgroundColor))
  	clay_render(&commands, doc)
  rl.EndDrawing()
}
