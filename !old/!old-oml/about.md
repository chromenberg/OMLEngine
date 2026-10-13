core files for oml, oml dom, ocss, ocssom, runtime.

- DOM types should be detatched from the renderer and be independent
- DOM nodes should be more extensible and allow for their own fields
- Renderer should be made in another module to parse the DOM
- DOM should manage what needs to be rendered
- Retained-Mode Rendering
- Rendering should be done on another thread
- DOM updates -> Renders should be scheduled, needs an event loop?
- OCSS should be more flexible
- Layout Engine should be remade from scratch
- Event System should not fire every frame
- Runtime functions should be easier to extend
- HTTP/S should not use an external library for just making GET requests?