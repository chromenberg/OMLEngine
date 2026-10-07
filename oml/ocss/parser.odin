package ocss

GROUP_TYPE :: enum {
  DeclarationStart,
    ClassDeclaration,
    GroupedDeclaration,
    IdDeclaration,
    PropertyDeclaration,
  DeclarationEnd
}
Declaration :: []TOKEN_KIND

// a class is a class token followed by an identifier
ClassDeclaration : Declaration : {.Class, .Identifier}
IdDeclaration : Declaration : {.Id, .Identifier}

// Parser :: struct {
//   i
// }

parse :: proc() {
  
}
