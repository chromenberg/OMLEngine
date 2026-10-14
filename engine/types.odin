// Scratch retained-mode UI engine.
//
// This is throwaway scaffolding: it is intentionally small and blunt. The parts
// worth keeping when it gets remade are the *splits*:
//
//   DOM/Node -> layout (CPU) -> Display_List -> raster (GPU) -> composite
//
// The Display_List is the boundary. Right now raylib (OpenGL) rasterizes it in
// raster()/paint.odin. Later a Rust/Vulkan program can consume the same list
// instead, either in-process or as a serialized buffer.
package main

// ---------------------------------------------------------------------------
// Geometry / color
// ---------------------------------------------------------------------------

Color :: struct {
	r, g, b, a: u8,
}

Rect :: struct {
	x, y, w, h: f32,
}

Edges :: struct {
	top, right, bottom, left: f32,
}

// ---------------------------------------------------------------------------
// Style (dense, resolved). Deliberately NOT a string map: layout and paint read
// these in the hot loop, so they are direct field access.
// ---------------------------------------------------------------------------

Size_Kind :: enum {
	Auto, // fill the available space (block behaviour)
	Fixed, // exact px
	Grow, // share leftover space along the main axis
	Percent, // value is 0..100 of the available space
}

Size :: struct {
	kind:  Size_Kind,
	value: f32,
}

Direction :: enum {
	Row,
	Column,
}

Align :: enum {
	Start,
	Center,
	End,
	Stretch,
}

Justify :: enum {
	Start,
	Center,
	End,
	Space_Between,
}

Style :: struct {
	width, height: Size,
	padding:       Edges,
	margin:        Edges,
	gap:           f32,
	direction:     Direction,
	align:         Align,
	justify:       Justify,

	background:     Color,
	has_background: bool,
	radius:         f32,

	border:       Edges,
	border_color: Color,
	has_border:   bool,

	text:       string,
	font_size:  f32,
	text_color: Color,

	// Compositor-ish. Baked into the display list for now, so changing these
	// marks the node Paint-dirty and rebuilds its ops.
	opacity:   f32, // 0..1
	translate: [2]f32,

	visible: bool,
}

// ---------------------------------------------------------------------------
// Dirtying. Three grades; each has a different propagation boundary once this
// is made real. For now everything recomputes and the damage rect keeps the
// raster pass cheap.
// ---------------------------------------------------------------------------

Dirty_Type :: enum {
	Style,
	Layout,
	Paint,
	Composite,
}

Dirty_Flags :: bit_set[Dirty_Type]

// ---------------------------------------------------------------------------
// Layout result, in absolute screen space. content_* is the padding box.
// ---------------------------------------------------------------------------

Box :: struct {
	x, y, w, h:                                 f32,
	content_x, content_y, content_w, content_h: f32,
}

// ---------------------------------------------------------------------------
// Paint. A flat list of primitive draw commands with absolute coordinates.
// POD-on-purpose: this is what a serializing backend would send to Rust.
// ---------------------------------------------------------------------------

Draw_Kind :: enum {
	Rect,
	Rounded_Rect,
	Border,
	Text,
}

Draw_Op :: struct {
	kind:   Draw_Kind,
	rect:   Rect,
	radius: f32,
	thick:  f32,
	color:  Color,
	text:   string,
	size:   f32,
}

Display_List :: struct {
	ops: [dynamic]Draw_Op,
}

// ---------------------------------------------------------------------------
// Node
// ---------------------------------------------------------------------------

Node :: struct {
	id:       string,
	style:    Style,
	parent:   ^Node,
	children: [dynamic]^Node,

	box:      Box,
	prev_box: Box, // snapshot taken before layout, for damage diffs

	display: Display_List,
	dirty:   Dirty_Flags,

	animations: [dynamic]Animation,
}

Scene :: struct {
	root:  ^Node,
	dirty: Dirty_Flags,
}

new_node :: proc() -> ^Node {
	n := new(Node)
	n.style.opacity = 1
	n.style.visible = true
	return n
}

add_child :: proc(parent, child: ^Node) {
	child.parent = parent
	append(&parent.children, child)
}

mark_dirty :: proc(scene: ^Scene, n: ^Node, flags: Dirty_Flags) {
	n.dirty += flags
	scene.dirty += flags
}

// ---------------------------------------------------------------------------
// Small rect helpers
// ---------------------------------------------------------------------------

rect_eq :: proc(a, b: Rect) -> bool {
	return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h
}

box_rect :: proc(b: Box) -> Rect {
	return {b.x, b.y, b.w, b.h}
}

rects_intersect :: proc(a, b: Rect) -> bool {
	return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
}
