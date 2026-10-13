package oml

import "core:time"
import "core:nbio"
import "core:log"

// Defines a task that is ran on the event loop
Task :: struct {
	
}

start_event_loop :: proc(/* doc: ^Document */) {
	log.logf(.Info, "Acquiring OMLEngine event loop")	
	if err := nbio.acquire_thread_event_loop(); err != nil {
		log.errorf("OMLEngine failed to acquire the event loop. nbio err: %v", nbio.error_string(err))
		return
	}
	log.logf(.Info, "Acquired OMLEngine event loop")
	
}

close_event_loop :: proc() {
	nbio.release_thread_event_loop()
	log.logf(.Info, "Closed OMLEngine event loop")
}

// Schedules a task to occur on the next tick of the event loop
// 
// This procedure has no arguments
next_tick_noargs :: proc(cb: nbio.Callback) -> ^nbio.Operation {
	return nbio.next_tick(cb)
}


// Schedules a task to occur on the next tick of the event loop
// 
// This procedure has 1 arguments
next_tick_1arg :: proc(arg1: $T, cb: $C/proc(op: ^nbio.Operation, arg1: T)) -> ^nbio.Operation {
	return nbio.next_tick_poly(arg1,cb)
}

// Schedules a task to occur on the next tick of the event loop
// 
// This procedure has 2 arguments
next_tick_2args :: proc(arg1: $T, arg2: $T2, cb: $C/proc(op: ^nbio.Operation, arg1: T, arg2: T2)) -> ^nbio.Operation {
	return nbio.next_tick_poly2(arg1, arg2, cb)
}

// Schedules a task to occur on the next tick of the event loop
// 
// This procedure has no arguments
next_tick_3args :: proc(arg1: $T, arg2: $T2, arg3: $T3, cb: $C/proc(op: ^nbio.Operation, arg1: T, arg2: T2, arg3: T3)) -> ^nbio.Operation {
	return nbio.next_tick_poly3(arg1, arg2, arg2, cb)
}

next_tick :: proc {
	next_tick_noargs,
	next_tick_1arg,
	next_tick_2args,
	next_tick_3args
}


timeout_noargs :: proc(duration: time.Duration, cb: nbio.Callback) -> ^nbio.Operation {
	return nbio.timeout(duration, cb)
}

timeout_1arg :: proc(duration: time.Duration, arg1: $T, cb: $C/proc(op: ^nbio.Operation, arg1: T)) -> ^nbio.Operation {
	return nbio.timeout_poly(duration, arg1, cb)
}

timeout_2args :: proc(duration: time.Duration, arg1: $T, arg2: $T2, cb: $C/proc(op: ^nbio.Operation, arg1: T, arg2: T2)) -> ^nbio.Operation {
	return nbio.timeout_poly2(duration, arg1, arg2, cb)
}

timeout_3args :: proc(duration: time.Duration, arg1: $T, arg2: $T2, arg3: $T3, cb: $C/proc(op: ^nbio.Operation, arg1: T, arg2: T2, arg3: T3)) -> ^nbio.Operation {
	return nbio.timeout_poly3(duration, arg1, arg2, arg2, cb)
}

// Schedules a task to occur in `duration`ns
schedule :: proc {
	timeout_noargs,
	timeout_1arg,
	timeout_2args,
	timeout_3args
}

// Writes to a handle at a specified offset
write :: proc {
	nbio.write,
	nbio.write_poly,
	nbio.write_poly2,
	nbio.write_poly3,
}

exec :: nbio.exec

pending_events :: nbio.num_waiting