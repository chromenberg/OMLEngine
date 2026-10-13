ackage oml

import "core:encoding/xml"

OML_Parser :: struct {
	using parser: Parser,
	xdoc: ^xml.Document,
	doc: ^Document
}

open_file :: proc(p: ^OML_Parser) {
	doc, err := xml.load_from_file(p.file.src)
	
}