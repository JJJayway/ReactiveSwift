//
//  Emitters.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

import Dispatch.queue
import Foundation.NSDate // To get NSTimeInterval


public func emptyEmitter<T>() (sink: Types<T>.Sink) -> TerminatorType {
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}

public func emitValue<T>(value: T) (sink: Types<T>.Sink) -> TerminatorType {
    sink.put(Event.fromValue(value))
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}

public func emitElements<T, S: SequenceType where S.Generator.Element == T>(sequence: S, onQueue queue: dispatch_queue_t) (sink: Types<T>.Sink) -> TerminatorType {
    var terminator = BasicTerminator()
    dispatch_async(queue) {
        for v in sequence {
            if terminator.stopped {
                sink.put(.Stopped)
                return
            }
            sink.put(Event.fromValue(v))
        }
        sink.put(.Completed)
    }
    return terminator
}

public func emitElements<T, S: SequenceType where S.Generator.Element == T>(sequence: S) (sink: Types<T>.Sink) -> TerminatorType {
    for v in sequence {
        sink.put(Event.fromValue(v))
    }
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}

public func timer(interval: NSTimeInterval, leeway: NSTimeInterval? = nil) (sink: Types<()>.Sink) -> TerminatorType {
    let queue = dispatch_queue_create("Reactive.timer", DISPATCH_QUEUE_SERIAL)
    let src = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
    dispatch_source_set_timer(src, DISPATCH_TIME_NOW, UInt64(interval * NSTimeInterval(NSEC_PER_SEC)), UInt64((leeway ?? interval/10) * NSTimeInterval(NSEC_PER_SEC)))
    dispatch_source_set_event_handler(src) {
        sink.put(Event.fromValue())
    }
    dispatch_resume(src)
    return BlockTerminator {
        dispatch_source_cancel(src)
        sink.put(.Stopped)
    }
}


// MARK: -

/// This will emit new values to `output` each time `state` changes.
/// When connecting to the output, the current state is emitted immediately.
///
/// NOTE: The state is only meant to be changed from one thread.
public class StateChangeEmitter<T: Equatable> {
    typealias Sink = Types<T>.Sink
    private var outputSink: Sink?
    private var prevState: T
    public var state: T {
        didSet {
            if state != prevState {
                prevState = state
                outputSink?.put(Event.fromValue(state))
            }
        }
    }
    init(_ initial: T) {
        prevState = initial
        state = initial
    }
    public lazy var output: Sink -> TerminatorType = {
        sink in
        self.outputSink = sink
        sink.put(Event.fromValue(self.state)) // Emit current state immediately
        return BlockTerminator {
            self.outputSink = nil
            sink.put(.Stopped)
        }
    }
}
