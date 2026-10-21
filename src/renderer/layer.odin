package renderer

import oml "../"

// This contains all the nodes that will be rendered on a new layer
// These can be taken OUT of the doc-flow if they arent in a render layer like `0` 
Render_Layer :: struct {
	nodes: [dynamic]^oml.Node,
	height: int,
	
	// Does the render layer affect other nodes and their positioning
	affects: bool
}