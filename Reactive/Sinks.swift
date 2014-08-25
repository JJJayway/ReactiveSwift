//
//  Sinks.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

public func accept<T>(onValue: T -> () = {_ in}, onCompleted: () -> () = {}, onError: (NSError) -> () = {_ in}, onStopped: () -> () = {}, onEnd: () -> () = {}) -> Types<T>.Sink {
    return SinkOf {
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

/// Store all emitted values in an array, and pass it to the callback when the emitter ends.
public func toArray<T>(callback: [T] -> ()) -> Types<T>.Sink {
    var result: [T] = []
    return accept(onValue: { v in result.append(v) }, onEnd: { callback(result) } )
}
