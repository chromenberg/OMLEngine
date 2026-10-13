package oml

import "core:log"
import "core:encoding/xml"

OML_Parser :: struct {
	using parser: Parser,
	xdoc: ^xml.Document,
	doc: ^Document
}

open_file :: proc(p: ^OML_Parser) {
	doc, err := xml.load_from_file(p.file.src, allocator = p.allocator)
	p.xdoc = doc
}

parse_contents :: proc(p: ^OML_Parser) {
	for node in p.xdoc.elements {
		log.logf(.Debug, "%#v", node)
	}
}

parse_oml :: proc(p: ^OML_Parser) {
	open_file(p)
	parse_contents(p)
	// free(p.xdoc)
}
