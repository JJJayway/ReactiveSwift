//
//  SinkOperations.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

import Dispatch.queue
import Foundation.NSDate // To get NSTimeInterval
import class Foundation.NSError


public func map<I,O>(block: I -> O) (sink: TypesIO<I,O>.OutputSink) -> TypesIO<I,O>.InputSink {
    return SinkOf {
        event in
        if let value = event.value {
            sink.put(Event.fromValue(block(value)))
        } else {
            sink.put(event.convertNonValue())
        }
    }
}

public func filter<T>(block: T -> Bool) (sink: Types<T>.Sink) -> Types<T>.Sink {
    return SinkOf {
        event in
        if let value = event.value {
            if block(value) {
                sink.put(event)
            }
        } else {
            sink.put(event)
        }
    }
}

/// Also see merge()
public func flattenMap<I,O>(block: I -> TypesIO<I,O>.OutputEmitter) (sink: TypesIO<I,O>.OutputSink) -> TypesIO<I,O>.InputSink {
    return map(block) .. merge .. sink
}

/// Actually fold(), but the Swift standard library calls this `reduce`, hence the naming.
public func reduce<T, U>(#initial: U, combine: (U, T) -> U) (sink: Types<U>.Sink) -> Types<T>.Sink {
    var runningValue = initial
    return SinkOf {
        event in
        if let value = event.value {
            runningValue = combine(runningValue, value)
        } else if event.isCompleted {
            sink.put(Event.fromValue(runningValue))
            sink.put(.Completed)
        } else {
            sink.put(event.convertNonValue())
        }
    }
}


// MARK: -

/// Concatenates a series of emitters, first forwarding the values from the first emitter,
/// then, when that emitter ends, forwards values from the next, and so on.
///
/// If some emitter (including the emitter of emitters) sends the .Error event, or the .Stopped event, that event will be forwarded and event processing ends.
/// Other than that, event processing continues until all emitters (including the emitter of emitters) have completed.
public func concat<T>(var sink: Types<T>.Sink) -> Types<T>.SinkOfEmitters {
    let queue = dispatch_queue_create("Reactive.concat", DISPATCH_QUEUE_SERIAL) // Serialize incoming emitters
    var emitterCount = 0
    var mainEmitterHasEnded = false
    var valid = true // Becomes false if some emitter fails or stops
    
    sink = eventIntercept { if $0.isError || $0.isStopped { valid = false } }
        .. eventFilter {
            // Only send last .Completed
            // NOTE: This is run on `queue`
            if !$0.isCompleted {
                return true // Forward all non-.Completed events
            }
            return mainEmitterHasEnded && emitterCount == 0 // Only forward .Completed if all emitters have ended
        }
        .. sink
    
    return SinkOf {
        event in
        if !valid {
            return // Some emitter failed or stopped. We have ended.
        }
        dispatch_sync(queue) {
            dispatch_suspend(queue) // Do not accept more emitters until this has ended
            if let emitter = event.value {
                emitterCount++
                emitter
                    .. eventFilter { _ in valid } // Ignore remaining events if we got an .Error or .Stopped event
                    .. eventIntercept { if $0.isEnd { emitterCount--; dispatch_resume(queue) } } // Accept next emitter
                    .. sink
            } else {
                // The emitter of emitters has ended
                mainEmitterHasEnded = true
                sink.put(event.convertNonValue())
                dispatch_resume(queue)
            }
        }
    }
}

/// Merge a series of emitters, forwarding their values as they come in.
///
/// If some emitter (including the emitter of emitters) sends the .Error event, or the .Stopped event, that event will be forwarded and event processing ends.
/// Other than that, event processing continues until all emitters (including the emitter of emitters) have completed.
public func merge<T>(var sink: Types<T>.Sink) -> Types<T>.SinkOfEmitters {
    let queue = dispatch_queue_create("Reactive.merge", DISPATCH_QUEUE_SERIAL) // Serialize emits to the sink
    var emitterCount = 0
    var mainEmitterHasEnded = false
    var valid = true // Becomes false if some emitter fails or stops
    
    sink = eventIntercept { if $0.isError || $0.isStopped { valid = false } }
        .. eventFilter {
            // Only send last .Completed
            // NOTE: This is run on `queue`
            if !$0.isCompleted {
                return true // Forward all non-.Completed events
            }
            return mainEmitterHasEnded && emitterCount == 0 // Only forward .Completed if all emitters have ended
        }
        .. sink
    
    return SinkOf {
        event in
        if !valid {
            return // Some emitter failed or stopped. We have ended.
        }
        if let emitter = event.value {
            dispatch_async(queue) {
                emitterCount++
                return
            }
            emitter
                .. eventFilter { _ in valid } // Ignore remaining events if we got an .Error or .Stopped event
                .. onQueue (queue)
                .. eventIntercept { if $0.isCompleted { emitterCount-- } }
                .. sink
        } else {
            // No more emitters
            dispatch_async(queue) {
                mainEmitterHasEnded = true
                sink.put(event.convertNonValue())
            }
        }
    }
}


// MARK: -

/// Forward events on the given queue (asynchronously)
public func onQueue<T>(queue: dispatch_queue_t) (sink: Types<T>.Sink) -> Types<T>.Sink {
    return SinkOf { event in dispatch_async(queue) { sink.put(event) } }
}

public func onMain<T>(sink: Types<T>.Sink) -> Types<T>.Sink {
    return onQueue(dispatch_get_main_queue())(sink: sink)
}

public func throttle<T>(minInterval: NSTimeInterval) (sink: Types<T>.Sink) -> Types<T>.Sink {
    var nextAcceptTime = NSDate()
    return SinkOf {
        event in
        NSThread.sleepUntilDate(nextAcceptTime)
        nextAcceptTime = NSDate(timeIntervalSinceNow: minInterval)
        sink.put(event)
    }
}


// MARK: -

public func intercept<T>(onValue: T -> () = {_ in}, onCompleted: () -> () = {}, onError: (NSError) -> () = {_ in}, onStopped: () -> () = {}, onEnd: () -> () = {}) -> (sink: Types<T>.Sink) -> Types<T>.Sink {
    return eventIntercept {
        event in
        switch event {
        case .Value(let valueBox):
            onValue(valueBox.unbox())
        case .Completed:
            onCompleted()
            onEnd()
        case .Error(let error):
            onError(error)
            onEnd()
        case .Stopped:
            onStopped()
            onEnd()
        }
    }
}

public func valueIntercept<T>(onValue: T -> ()) -> (sink: Types<T>.Sink) -> Types<T>.Sink {
    return eventIntercept {
        event in
        if let value = event.value {
            onValue(value)
        }
    }
}

public func eventFilter<T>(block: Event<T> -> Bool) (sink: Types<T>.Sink) -> Types<T>.Sink {
    return SinkOf {
        event in
        if block(event) {
            sink.put(event)
        }
    }
}

public func eventIntercept<T>(block: Event<T> -> ()) (sink: Types<T>.Sink) -> Types<T>.Sink {
    return SinkOf {
        event in
        block(event)
        sink.put(event)
    }
}
