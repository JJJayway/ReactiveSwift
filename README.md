ReactiveSwift
=============

High-performance Reactive extensions for Swift, inspired by ReactiveCocoa.

ReactiveSwift is a Swift framework inspired by Functional Reactive
Programming. ReactiveSwift uses the standard Swift SinkType, and provides APIs for
**composing and transforming sinks**.

## Sinks, Pushers, Terminators, and Sink Operations

A Pusher takes a sink and returns a Terminator. When given a sink, the pusher starts pushing
out events to the sink. An event is either a value, an error, the Completed event, or the
Stopped event. The last three events are ending events. After an ending event, the pusher
will not push out any more events, and all resources, including the sink, will be
released. Currently a Pusher is just a closure, but in upcoming releases it may evolve
into e.g. a struct having e.g. a name for debugging purposes.

A Terminator sports a single method: `stop()`, which can be used to end the pusher. The
pusher will push a final Stopped event, release all resources, and terminate. The pusher
may currently be blocked in a call to `put()`, in which case it will not terminate
instantly.

A Sink is the standard Swift struct `SinkOf<T>` which holds a single closure, implementing
the put() method. The struct is a value type, but as it holds a single reference type,
it can be passed around almost like a reference type (e.g. a class).

The Pusher decides whether events are pushed to the sink synchronously or asynchronously.

The `push(Sequence)(Sink) -> Terminator` function results in a synchronous push:

```swift
  push([1, 3, 5, 7, 9])
    .. map { (v: Int) -> Int in v + 1 }
    .. filter { (v: Int) -> Bool in v < 10 }
    .. accept { (v: Int) -> () in println(v) }
```

Use `push(Sequence, onQueue:queue)(Sink) -> Terminator` to push a sequence asynchronously:

```swift
push([1, 3, 5, 7, 9], onQueue: myQueue)
  .. map { $0 + 1 } .. filter { $0 < 10 } .. onMain .. accept { println($0) }
```

