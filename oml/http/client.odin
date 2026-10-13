package requests


import "shared:http"
import "core:net"
import "core:fmt"
import client "shared:http/client"

USER_AGENT :: "Vortex-Launcher/0.1"

handle_req_err :: proc(err: client.Error) {
  #partial switch e in err {
    case client.SSL_Error:
      fmt.printfln("Could not retrieve image. error: %v", e)
    case net.Network_Error:
      fmt.printfln("Could not retrieve image. error: %v", e)
  }
}

handle_body_err :: proc(err: client.Body_Error) {
  if err == .None do return
  fmt.printfln("Could not get response body. error: %v", err)
}

handle_err :: proc {
  handle_req_err,
  handle_body_err
}

get_image :: proc(path: string) -> string {
  request: client.Request
  request.method = .Get
  request.headers._kv["User-Agent"] = USER_AGENT
  
  res, err := client.request(&request, path)
  client.request_destroy(&request)
  handle_err(err)
  
  body, allocced, body_err := client.response_body(&res)
  handle_err(body_err)
  return body.(client.Body_Plain)
}
