package oml

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import "core:sync"
import "core:thread"
import client "shared:http/client"
import rl "vendor:raylib"

// request passed to worker
Request :: struct {
  node: ^Node,
  url:  string,
}

// result from the worker
Result :: struct {
  node:  ^Node,
  bytes: []u8,
  ok:    bool,
}


Loader :: struct {
  thread:    ^thread.Thread,
  mutex:     sync.Mutex,
  cond:      sync.Cond,
  requests:  [dynamic]Request,
  results:   [dynamic]Result,
  running:   bool,
  allocator: runtime.Allocator,
}

// Starts the worker threads / the queue
loader_init :: proc(l: ^Loader, allocator := context.allocator) {
  l.allocator = allocator
  l.requests  = make([dynamic]Request, allocator)
  l.results   = make([dynamic]Result, allocator)
  l.running   = true
  l.thread = thread.create_and_start_with_data(rawptr(l), worker)
}

// Enqueue a URL to be fetched
loader_request :: proc(l: ^Loader, node: ^Node, url: string) {
  node.image.url   = strings.clone(url, l.allocator)
  node.image.state = .Loading

  sync.mutex_lock(&l.mutex)
  append(&l.requests, Request{node = node, url = node.image.url})
  sync.cond_signal(&l.cond)
  sync.mutex_unlock(&l.mutex)
}

// Drains queue, once per frame. returns rendering data
loader_update :: proc(l: ^Loader) {
  // take the finished results under the lock, then upload outside of it
  sync.mutex_lock(&l.mutex)
  finished := make([]Result, len(l.results), l.allocator)
  copy(finished, l.results[:])
  clear(&l.results)
  sync.mutex_unlock(&l.mutex)

  for result in finished {
    if !result.ok {
      result.node.image.state = .Failed
      continue
    }

    image := rl.LoadImageFromMemory(image_format(result.bytes), raw_data(result.bytes), c.int(len(result.bytes)))
    if image.data != nil {
      texture := rl.LoadTextureFromImage(image)
      rl.UnloadImage(image)

      // clamp to edges, generate mipmaps and alias
      rl.SetTextureWrap(texture, .CLAMP)
      rl.GenTextureMipmaps(&texture)
      rl.SetTextureFilter(texture, .TRILINEAR)

      result.node.image.texture = texture
      result.node.image.state = .Ready
    } else {
      fmt.eprintfln("[images] could not decode %s", result.node.image.url)
      result.node.image.state = .Failed
    }

    delete(result.bytes, l.allocator)
  }

  delete(finished, l.allocator)
}

loader_shutdown :: proc(l: ^Loader) {
  sync.mutex_lock(&l.mutex)
  l.running = false
  sync.cond_broadcast(&l.cond)
  sync.mutex_unlock(&l.mutex)

  if l.thread != nil {
    thread.join(l.thread)
    thread.destroy(l.thread)
    l.thread = nil
  }

  for result in l.results {
    if result.bytes != nil do delete(result.bytes, l.allocator)
  }
  delete(l.requests)
  delete(l.results)
}

@(private = "file")
worker :: proc(data: rawptr) {
  context = runtime.default_context()
  l := cast(^Loader)data

  for {
    sync.mutex_lock(&l.mutex)
    for len(l.requests) == 0 && l.running {
      sync.cond_wait(&l.cond, &l.mutex)
    }
    if !l.running {
      sync.mutex_unlock(&l.mutex)
      return
    }
    request := pop_front(&l.requests)
    sync.mutex_unlock(&l.mutex)

    bytes, ok := fetch_image(request.url, l.allocator)

    sync.mutex_lock(&l.mutex)
    append(&l.results, Result{node = request.node, bytes = bytes, ok = ok})
    sync.mutex_unlock(&l.mutex)
  }
}

@(private = "file")
fetch_image :: proc(url: string, allocator: runtime.Allocator) -> ([]u8, bool) {
  res, err := client.get(url, allocator)
  if err != nil {
    fmt.eprintfln("[images] request failed for %s: %v", url, err)
    return nil, false
  }
  defer client.response_destroy(&res)

  body, was_allocation, body_err := client.response_body(&res, allocator = allocator)
  if body_err != nil {
    fmt.eprintfln("[images] reading body failed for %s: %v", url, body_err)
    return nil, false
  }
  // destroy original data
  defer client.body_destroy(body, was_allocation, allocator)

  plain, ok := body.(client.Body_Plain)
  if !ok do return nil, false

  data := make([]u8, len(plain), allocator)
  copy(data, transmute([]u8)plain) // copy so the data isnt owned by http
  return data, true
}

// Sniffs the image format from its magic bytes so raylib can decode it.
@(private = "file")
image_format :: proc(bytes: []u8) -> cstring {
  if len(bytes) >= 8 && bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G' {
    return ".png"
  }
  if len(bytes) >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
    return ".jpg"
  }
  if len(bytes) >= 3 && bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F' {
    return ".gif"
  }
  if len(bytes) >= 2 && bytes[0] == 'B' && bytes[1] == 'M' {
    return ".bmp"
  }
  return ".png"
}
