//
//  Reactive.swift
//  ReactiveSwift
//
//  Created by Jens Jakob Jensen in 2014.
//  Copyright (c) 2014 Jayway. All rights reserved.
//
//
// Sinks, Pushers, and Sink Operations
//
// A sink is just the (system defined) passive struct, SinkOf<T>, accepting Events: SinkOf<Event<T>>.
//
// A pusher is a closure taking a sink and returning a "terminator".
// Pushers can potentially block when calling put() on a sink.
//
// The pusher closure should retain what's necessary (e.g. sinks) while pushing, then release everything.
// Calling stop() on the terminator should end the pushing, and hence release everything.
//
// Events have the usual Value, Completed, Error states, but also a Stopped state to enable sinks to know when no more data is coming.
//
//
// TODO:
//  Move tests to test target (add a sink that assembles the values into an array)
//  Thread safety (using the Protector class?)
//  KVO
//  NotificationCenter
//  ...?

import class Foundation.NSError
import class Foundation.NSDate
import class Foundation.NSThread
//import typealias Foundation.NSDate.NSTimeInterval
import Foundation.NSDate // To get NSTimeInterval
import Dispatch.queue


// MARK: -

/// This maps a struct inside a class to get Hashable and Equatable (used by Splitter), and to avoid a bug in beta 5 (in the definition of Event)
public class Box<T>: Hashable, Equatable {
    public let value: T
    init(_ value: T) {
        self.value = value
    }
    public func unbox() -> T {
        return value
    }
    public var hashValue: Int {
        return reflect(self).objectIdentifier!.hashValue
    }
}

public func ==<T>(lhs: Box<T>, rhs: Box<T>) -> Bool {
    return lhs === rhs
}


// MARK: -

public enum Event<T> {
    /// A value
    case Value(Box<T>)
    /// Completed without error. This is an ending event: No more events will be pushed out.
    case Completed
    /// Stopped prematurely without error (terminated). This is an ending event: No more events will be pushed out.
    case Stopped
    /// Error. This is an ending event: No more events will be pushed out.
    case Error(NSError)
    
    public func convertNonValue<U>() -> Event<U> {
        switch self {
        case .Value(_):         fatalError("convertNonValue() cannot convert Event values!")
        case .Completed:        return .Completed
        case .Stopped:          return .Stopped
        case .Error(let error): return .Error(error)
        }
    }
    
    public var isValue: Bool {
        switch self {
        case .Value(_):
            return true
        default:
            return false
            }
    }
    public var isCompleted: Bool {
        switch self {
        case .Completed:
            return true
        default:
            return false
            }
    }
    public var isStopped: Bool {
        switch self {
        case .Stopped:
            return true
        default:
            return false
            }
    }
    public var isError: Bool {
        switch self {
        case .Error(_):
            return true
        default:
            return false
            }
    }
    public var isEnd: Bool {
        return !isValue
    }
    
    public var value: T? {
        switch self {
        case .Value(let valueBox):
            return valueBox.unbox()
        default:
            return nil
            }
    }
    public static func fromValue(value: T) -> Event {
        return .Value(Box(value))
    }
    
    public var error: NSError? {
        switch self {
        case .Error(let error):
            return error
        default:
            return nil
            }
    }
}


// MARK: -

public struct Types<T> {
    public typealias Sink = SinkOf<Event<T>>
    public typealias Pusher = Sink -> TerminatorType
    public typealias Intermediate = Sink -> Sink
    public typealias SinkOfPushers = Types<Pusher>.Sink
}

public struct TypesIO<I,O> {
    public typealias InputSink = SinkOf<Event<I>>
    public typealias OutputSink = SinkOf<Event<O>>
    public typealias InputPusher = InputSink -> TerminatorType
    public typealias OutputPusher = OutputSink -> TerminatorType
    public typealias SinkOfInputPushers = TypesIO<InputPusher,OutputPusher>.InputSink
    public typealias SinkOfOutputPushers = TypesIO<InputPusher,OutputPusher>.OutputSink
}


// MARK: -

public protocol TerminatorType {
    /// Stop pushing events and push a final .Stopped
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


// MARK: -

/// This will push new values to `output` each time `state` changes.
/// When connecting to the output, the current state is pushed immediately.
///
/// NOTE: The state is only meant to be changed from one thread.
public class StateChangePusher<T: Equatable> {
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
        sink.put(Event.fromValue(self.state)) // Push current state immediately
        return BlockTerminator {
            self.outputSink = nil
            sink.put(.Stopped)
        }
    }
}


// MARK: -

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


// MARK: -

/// Concatenates a series of pushers, first forwarding the values from the first pusher,
/// then, when that pusher ends, forwards values from the next, and so on.
///
/// If some pusher (including the pusher of pushers) sends the .Error event, or the .Stopped event, that event will be forwarded and event processing ends.
/// Other than that, event processing continues until all pushers (including the pusher of pushers) have completed.
public func concat<T>(var sink: Types<T>.Sink) -> Types<T>.SinkOfPushers {
    let queue = dispatch_queue_create("Reactive.concat", DISPATCH_QUEUE_SERIAL) // Serialize incoming pushers
    var pusherCount = 0
    var mainPusherHasEnded = false
    var valid = true // Becomes false if some pusher fails or stops
    
    sink = eventIntercept { if $0.isError || $0.isStopped { valid = false } }
        .. eventFilter {
            // Only send last .Completed
            // NOTE: This is run on `queue`
            if !$0.isCompleted {
                return true // Forward all non-.Completed events
            }
            return mainPusherHasEnded && pusherCount == 0 // Only forward .Completed if all pushers have ended
        }
        .. sink
    
    return SinkOf {
        event in
        if !valid {
            return // Some pusher failed or stopped. We have ended.
        }
        dispatch_sync(queue) {
            dispatch_suspend(queue) // Do not accept more pushers until this has ended
            if let pusher = event.value {
                pusherCount++
                pusher
                    .. eventFilter { _ in valid } // Ignore remaining events if we got an .Error or .Stopped event
                    .. eventIntercept { if $0.isEnd { pusherCount--; dispatch_resume(queue) } } // Accept next pusher
                    .. sink
            } else {
                // The pusher of pushers has ended
                mainPusherHasEnded = true
                sink.put(event.convertNonValue())
                dispatch_resume(queue)
            }
        }
    }
}

/// Merge a series of pushers, forwarding their values as they come in.
///
/// If some pusher (including the pusher of pushers) sends the .Error event, or the .Stopped event, that event will be forwarded and event processing ends.
/// Other than that, event processing continues until all pushers (including the pusher of pushers) have completed.
public func merge<T>(var sink: Types<T>.Sink) -> Types<T>.SinkOfPushers {
    let queue = dispatch_queue_create("Reactive.merge", DISPATCH_QUEUE_SERIAL) // Serialize pushes to the sink
    var pusherCount = 0
    var mainPusherHasEnded = false
    var valid = true // Becomes false if some pusher fails or stops
    
    sink = eventIntercept { if $0.isError || $0.isStopped { valid = false } }
        .. eventFilter {
            // Only send last .Completed
            // NOTE: This is run on `queue`
            if !$0.isCompleted {
                return true // Forward all non-.Completed events
            }
            return mainPusherHasEnded && pusherCount == 0 // Only forward .Completed if all pushers have ended
        }
        .. sink
    
    return SinkOf {
        event in
        if !valid {
            return // Some pusher failed or stopped. We have ended.
        }
        if let pusher = event.value {
            dispatch_async(queue) {
                pusherCount++
                return
            }
            pusher
                .. eventFilter { _ in valid } // Ignore remaining events if we got an .Error or .Stopped event
                .. onQueue (queue)
                .. eventIntercept { if $0.isCompleted { pusherCount-- } }
                .. sink
        } else {
            // No more pushers
            dispatch_async(queue) {
                mainPusherHasEnded = true
                sink.put(event.convertNonValue())
            }
        }
    }
}


// MARK: -

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
public func flattenMap<I,O>(block: I -> TypesIO<I,O>.OutputPusher) (sink: TypesIO<I,O>.OutputSink) -> TypesIO<I,O>.InputSink {
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

public func push<T, S: SequenceType where S.Generator.Element == T>(sequence: S) (sink: Types<T>.Sink) -> TerminatorType {
    for v in sequence {
        sink.put(Event.fromValue(v))
    }
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}

public func push<T>(value: T) (sink: Types<T>.Sink) -> TerminatorType {
    sink.put(Event.fromValue(value))
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}

public func push<T, S: SequenceType where S.Generator.Element == T>(sequence: S, onQueue queue: dispatch_queue_t) (sink: Types<T>.Sink) -> TerminatorType {
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


// MARK: -

infix operator .. { precedence 91 associativity right } // Precedence one higher than assignment

// Merge an intermediate with a sink
public func .. <I,O>(f: TypesIO<I,O>.OutputSink -> TypesIO<I,O>.InputSink, sink: TypesIO<I,O>.OutputSink) -> TypesIO<I,O>.InputSink {
    return f(sink)
}

// Merge a pusher and a sink
public func .. <T>(pusher: Types<T>.Pusher, sink: Types<T>.Sink) -> TerminatorType {
    return pusher(sink)
}

// Merge a pusher and an intermediate
public func .. <T>(pusher: Types<T>.Pusher, f: Types<T>.Sink -> Types<T>.Sink) (sink: Types<T>.Sink) -> TerminatorType {
    return pusher .. f .. sink
}

// Merge two intermediates
public func .. <I,T,O>(f: TypesIO<I,T>.OutputSink -> TypesIO<I,T>.InputSink, g: TypesIO<T,O>.OutputSink -> TypesIO<T,O>.InputSink) (sink: TypesIO<T,O>.OutputSink) -> TypesIO<I,T>.InputSink {
    return f(g(sink))
}


// MARK: -

func printer<T>(_ prefix: String = "Got value: ") -> SinkOf<Event<T>> {
    return SinkOf {
        event in
        switch event {
        case .Value(let valueBox):
            println("\(prefix)\(valueBox.unbox())")
        case .Completed:
            println("\(prefix)(done)")
        case .Error(let error):
            println("\(prefix)Error: \(error)")
        case .Stopped:
            println("\(prefix)(stopped)")
        }
    }
}

func mainPrinter<T>(_ prefix: String = "Got: ") -> Types<T>.Sink {
    return onMain .. printer(prefix) // Print on the main thread
}

func verify<T: Equatable>(var facit: [T], _ prefix: String = "Verify: ") (sink: Types<T>.Sink) -> SinkOf<Event<T>> {
    var verified = true
    return SinkOf {
        event in
        switch event {
        case .Value(let valueBox):
            if valueBox.unbox() != facit.first! {
                verified = false
            }
            facit.removeAtIndex(0)
        case .Completed:
            if facit.count > 0 {
                verified = false
            }
            println("\(prefix)" + (verified ? "OK" : "FAILED"))
        case .Error(let error):
            println("\(prefix)Error: \(error)")
        case .Stopped:
            println("\(prefix)Stopped")
        }
        sink.put(event)
    }
}

/// This is used by test4(). The beta 5 compiler has some issues having this inside the function scope.
class C {
    struct Static {
        static var innerDone = false
    }
    func ping(s: String) {
        println("C.ping " + s)
    }
    deinit {
        push("C.deinit") .. mainPrinter() // Print on the main thread
//        NSLog("C.deinit") // Use NSLog for async printing
        if !Static.innerDone {
            println("innerDone was supposed to be true")
            //fatalError("innerDone was supposed to be true")
        }
    }
}

@objc class ReactiveSwift {
    
    class func test() {
        println("Testing ReactiveSwift")
//        test1()
//        test2()
//        test3()
//        test4()
        test5()
        test6()
        test7()
        test8()
    }
    class func test1() {
        // Outputs: 1, 3, 5, 7, 9
        push([1, 3, 5, 7, 9]) .. accept { (v: Int) -> () in println(v) }
        // Outputs: 2, 4, 6, 8
        push([1, 3, 5, 7, 9]) ..
            map { (v: Int) -> Int in v + 1 } ..
            filter { (v: Int) -> Bool in v < 10 } ..
            printer("test1: ")
    }
    class func test2() {
        let letters = "A B C D E F G H I".componentsSeparatedByString(" ")
        // Outputs: A B C D E F G H I
        push(letters) .. reduce(initial: "") { c, v in c + "\(v) " } .. verify(["A B C D E F G H I "], "test2: ") .. printer("test2: ")
    }
    class func test3() {
        var splitter = Splitter<Int>()
        // Outputs: 0 2 4 6
        splitter.newOutput
            .. map { $0 * 2 }
            .. reduce(initial: "1: ") { c, v in c + "\(v) " }
            .. onMain
            .. verify(["1: 0 2 4 6 "], "test3a: ")
            .. printer()
        // Outputs: 0 1 2 3
        splitter.newOutput
            .. onMain
            .. verify([0, 1, 2, 3], "test3b: ")
            .. reduce(initial: "2: ") { c, v in c + "\(v) " }
            .. printer()
        // Outputs: 0 1 2 3
        splitter.newOutput
            .. verify([0, 1, 2, 3], "test3c: ")
            .. accept { v in println("Got a nice \(v) :-)") }
        // Outputs: 0 -1 -2 -3
        splitter.newOutput
            .. map { -$0 }
            .. verify([0, -1, -2, -3], "test3d: ")
            .. accept(onValue: { v in println("<\(v)>") },
                onCompleted: { println("<done>") },
                onError: { e in println("<\(e)>") },
                onStopped: { println("<stopped>") })
        
        let queue = dispatch_queue_create("test3", DISPATCH_QUEUE_SERIAL)
        push([1, 2, 3, 4], onQueue: queue) .. map { $0 - 1 } .. splitter.input
    }
    class func test4() {
        let queue = dispatch_queue_create("test4", DISPATCH_QUEUE_SERIAL)
        func inner() {
            var c = C()
            push([1, 2, 3], onQueue: queue)
                .. accept { v in c.ping("\(v)") }
        }
        inner()
        println("inner() done")
        C.Static.innerDone = true
    }
    class func test5() {
        let queue = dispatch_queue_create("test5", DISPATCH_QUEUE_SERIAL)
        push([1, 3, 5, 7, 9], onQueue: queue)
            .. map { $0 + 1 } .. filter { $0 < 10 } .. onMain .. accept { println($0) }
    }
    class func test6() {
        struct Stat {
            static let queue = dispatch_queue_create("test6", DISPATCH_QUEUE_SERIAL)
        }
        
        let pushers: [Types<Int>.Pusher] = [push([1, 2, 3, 4], onQueue: Stat.queue) .. throttle(0.1), push([9, 8, 7, 6])]
        push(pushers)
            .. concat
            .. onMain
            .. verify([1,2,3,4,9,8,7,6], "test6: ")
            .. printer("concat: ")
    }
    class func test7() {
        let queue1 = dispatch_queue_create("test7a", DISPATCH_QUEUE_SERIAL)
        let queue2 = dispatch_queue_create("test7b", DISPATCH_QUEUE_SERIAL)
        
        let pushers: [Types<Int>.Pusher] = [
            push([1, 2, 3, 4], onQueue: queue1) .. throttle(0.1),
            push([9, 8, 7, 6], onQueue: queue2) .. throttle(0.1)
        ]
        var t = push(pushers)
            .. merge
            .. onMain
            .. printer("merge: ")
        
//        sleep(6)
//        t.stop() // Crashes in beta 6
    }
    class func test8() {
        var t = timer(0.25) .. printer("test8: ")
        sleep(1)
        t.stop()
    }
}

