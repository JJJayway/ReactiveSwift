//
//  Splitter.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//


/// A splitter, exposing a single `input` and several `newOutput`s.
///
/// Each time newOutput is accessed, a new output is created.
/// If an ending event has been sent to the input sink, that single event is sent to the new output.
/// Other than that, new outputs will only get events sent starting from that point in time.
///
/// You should connect all the outputs before connecting the input.
public class Splitter<T> { // FIXME: Make this thread safe
    typealias Sink = Types<T>.Sink
    typealias Token = Box<Sink>
    var sinks: [Token: ()] = [:]
    
    public init() {
    }
    
    func addSink(sink: Sink) -> Token {
        func ptr<T>(v: COpaquePointer) -> COpaquePointer {
            return v
        }
        let box = Box(sink)
        let token = box
        sinks[token] = ()
        return token
    }
    func removeSink(token: Token) {
        sinks.removeValueForKey(token)
    }
    
    var endingEvent: Event<T>?
    
    public var newOutput: Sink -> TerminatorType {
        return {
            sink in
            if let event = self.endingEvent {
                sink.put(event)
            }
            let token = self.addSink(sink)
            return BlockTerminator {
                self.removeSink(token)
                sink.put(.Stopped)
            }
            }
    }
    public lazy var input: Sink = SinkOf {
        event in
        // If the event signals the end, forward to all new sinks
        if event.isEnd {
            self.endingEvent = event
        }
        for sinkBox in self.sinks.keys {
            sinkBox.unbox().put(event)
        }
    }
}
