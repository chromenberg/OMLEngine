package tests

import "core:testing"
import "../oml/ocss/tokenizer"

@(test)
tokenize_oto_expr :: proc(t: ^testing.T) {
  
}

@(test)
tokenize_css_style :: proc(t: ^testing.T) {
  tok: tokenizer.Tokenizer
  tok.file = "test/test.ocss"
  tokenizer.tokenize_file(&tok)
  
  // exp
}

@(test)
tokenize_css_grouped_style :: proc(t: ^testing.T) {
  tok: tokenizer.Tokenizer
  tok.file = "test/test.ocss"
  tokenizer.tokenize_file(&tok)
}

@(test)
tokenize_css_grouped_style_middle :: proc(t: ^testing.T) {
  tok: tokenizer.Tokenizer
  tok.file = "test/groupedclassmiddle.ocss"
  tokenizer.tokenize_file(&tok)

  // testing.expect(t, tok.tokens[:] == []tokenizer.Token{
  //   tokenizer.Token{
  //     kind = .Period
  //   }
  // })
}

@(test)
tokenize_css_properties :: proc(t: ^testing.T) {
  tok: tokenizer.Tokenizer
  tok.file = "test/styleproperties.ocss"
  tokenizer.tokenize_file(&tok)
}

@(test)
tokenize_css_id :: proc(t: ^testing.T) {
  
}