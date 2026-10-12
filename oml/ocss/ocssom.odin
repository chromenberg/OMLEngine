package ocss

/* 
	The OCSSOM is the Odin Cascading Style Sheets Object Model

	It is a tree that represents the object model of the DOM, with only style elements and nothing else

	[ body ]
		 |				[color: red; width: 200;]
		 |\						|					[color:black; font-size: 25;]
		 | \					|							|
		 |  ----- [ rect ] ----- [ text ]
	[ rect ] - [color: green]

	This is a basic tree containing everything INSIDE the <body> tag of an OML document,
	there are no defining factors like type or events, only its class, id, tags and styles
*/