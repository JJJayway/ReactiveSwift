//
//  Types.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

public struct Types<T> {
    public typealias Sink = SinkOf<Event<T>>
    public typealias Emitter = Sink -> TerminatorType
    public typealias Intermediate = Sink -> Sink
    public typealias SinkOfEmitters = Types<Emitter>.Sink
}

public struct TypesIO<I,O> {
    public typealias InputSink = SinkOf<Event<I>>
    public typealias OutputSink = SinkOf<Event<O>>
    public typealias InputEmitter = InputSink -> TerminatorType
    public typealias OutputEmitter = OutputSink -> TerminatorType
    public typealias SinkOfInputEmitters = TypesIO<InputEmitter,OutputEmitter>.InputSink
    public typealias SinkOfOutputEmitters = TypesIO<InputEmitter,OutputEmitter>.OutputSink
}
