//
//  Reactive.swift
//  ReactiveSwift
//
//  Created by Jens Jakob Jensen in 2014.
//  Copyright (c) 2014 Jayway. All rights reserved.
//
//
// Sinks, Emitters, and Sink Operations
//
// A sink is just the (system defined) passive struct, SinkOf<T>, accepting Events: SinkOf<Event<T>>.
//
// An emitter is a closure taking a sink and returning a "terminator".
// Emitters can potentially block when calling put() on a sink.
//
// The emitter closure should retain what's necessary (e.g. sinks) while emitting, then release everything.
// Calling stop() on the terminator should end the emitting, and hence release everything.
//
// Events have the usual Value, Completed, Error states, but also a Stopped state to enable sinks to know when no more data is coming.
//
//
// TODO:
//  Thread safety (using the Protector class?)
//  KVO
//  NotificationCenter
//  ...?

//import class Foundation.NSError
//import class Foundation.NSDate
//import class Foundation.NSThread
////import typealias Foundation.NSDate.NSTimeInterval
//import Foundation.NSDate // To get NSTimeInterval
//import Dispatch.queue
