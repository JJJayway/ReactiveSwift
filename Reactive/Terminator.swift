//
//  Terminator.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

public protocol TerminatorType {
    /// Stop emitting events and emit a final .Stopped
    mutating func stop()
}

public struct BasicTerminator: TerminatorType {
    public var stopped = false
    public mutating func stop() {
        stopped = true
    }
}

public struct BlockTerminator: TerminatorType {
    let block: () -> ()
    init(block: () -> ()) {
        self.block = block
    }
    public mutating func stop() {
        self.block()
    }
}
