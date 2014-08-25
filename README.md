ReactiveSwift
=============

###### Lightweight, High-performance Reactive Extensions for Swift, inspired by [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa).

ReactiveSwift is a Swift framework enabling Functional Reactive Programming.
ReactiveSwift uses the standard Swift `SinkType`, and provides APIs for **composing and transforming sinks**.
Most functional reactive frameworks provides operations on signals.
In ReactiveSwift you work on sinks instead, which is sort of backwards but leads to more general code and enables more optimized code.

In effect, you can create all sorts of objects emitting events, but they all end in sinks.
The sink operations should be universally usable.

## Sinks, Emitters, Terminators, and Sink Operations

An Emitter takes a sink and returns a Terminator. When given a sink, the emitter starts emitting events to the sink.
An event is either a value, an error, the Completed event, or the Stopped event.
The last three events are called ending events.
After an ending event, the emitter will not emit any more events, and all resources, including the sink, will be released.
Currently an Emitter is just a closure, but in upcoming releases it may evolve into e.g. a struct having e.g. a name for debugging purposes.

A Terminator sports a single method: `stop()`, which can be used to end the emitter.
The emitter will emit a final Stopped event, release all resources, and terminate.
The emitter may currently be blocked in a call to `put()`, in which case it will not terminate instantly.

A Sink is the standard Swift struct `SinkOf<T>` which holds a single closure, implementing the put() method.
The struct is a value type, but as it holds a single reference type, it can be passed around almost like a reference type (e.g. a class).

The Emitter decides whether events are emitted to the sink synchronously or asynchronously.

The `emit(Sequence)(Sink) -> Terminator` function results in a synchronous emit:

```swift
  emitElements([1, 3, 5, 7, 9])
    .. map { (v: Int) -> Int in v + 1 }
    .. filter { (v: Int) -> Bool in v < 10 }
    .. accept { (v: Int) -> () in println(v) }
```

Use `emit(Sequence, onQueue:queue)(Sink) -> Terminator` to emit a sequence asynchronously:

```swift
emitElements([1, 3, 5, 7, 9], onQueue: myQueue)
  .. map { $0 + 1 } .. filter { $0 < 10 } .. onMain .. accept { println($0) }
```

