//
//  Operator.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

infix operator .. { precedence 91 associativity right } // Precedence one higher than assignment

// Merge an intermediate with a sink
public func .. <I,O>(f: TypesIO<I,O>.OutputSink -> TypesIO<I,O>.InputSink, sink: TypesIO<I,O>.OutputSink) -> TypesIO<I,O>.InputSink {
    return f(sink)
}

// Merge an emitter and a sink
public func .. <T>(emitter: Types<T>.Emitter, sink: Types<T>.Sink) -> TerminatorType {
    return emitter(sink)
}

// Merge an emitter and an intermediate
public func .. <T>(emitter: Types<T>.Emitter, f: Types<T>.Sink -> Types<T>.Sink) (sink: Types<T>.Sink) -> TerminatorType {
    return emitter .. f .. sink
}

// Merge two intermediates
public func .. <I,T,O>(f: TypesIO<I,T>.OutputSink -> TypesIO<I,T>.InputSink, g: TypesIO<T,O>.OutputSink -> TypesIO<T,O>.InputSink) (sink: TypesIO<T,O>.OutputSink) -> TypesIO<I,T>.InputSink {
    return f(g(sink))
}
