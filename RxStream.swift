//
//  RxStream.swift
//  ReactiveSwift
//
//  Created by Jens Jakob Jensen on 06/06/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//


/// Specify that we require of elements in RxStreams
/// We need Equatable for ignore()
protocol RxElementType : Equatable {
}

/// A protocol representing any stream of values.
///
/// When subclassing RxStream, only the methods in the RxStreamProtocol need
/// to be overridden.
protocol RxStreamProtocol : RxElementType {
    
    typealias Element
    
    /// A block which accepts a value from a RxStream and returns a new instance
    /// of the same stream class.
    ///
    /// Setting `stop` to `YES` will cause the bind to terminate after the returned
    /// value.
    typealias RxStreamBindBlock // (value: Element, stop: inout Bool) -> Self
    
    /// Returns an empty stream.
    class func empty() -> Self
    
    /// Lifts `value` into the stream monad.
    ///
    /// Returns a stream containing only the given value.
    class func lift(value: Element) -> Self
    
    /// Lazily binds a block to the values in the receiver.
    ///
    /// This should only be used if you need to terminate the bind early, or close
    /// over some state. -flattenMap: is more appropriate for all other cases.
    ///
    /// block - A block returning a RxStreamBindBlock. This block will be invoked
    ///         each time the bound stream is re-evaluated.
    ///
    /// Returns a new stream which represents the combined result of all lazy
    /// applications of `block`.
    func bind(block: () -> RxStreamBindBlock) -> Self
    
    /// Appends the values of `stream` to the values in the receiver.
    ///
    /// stream - A stream to concatenate. This must be an instance of the same
    ///          concrete class as the receiver.
    ///
    /// Returns a new stream representing the receiver followed by `stream`.
    func concat(stream: Self) -> Self
    
    /// Zips the values in the receiver with those of the given stream to create
    /// tuples.
    ///
    /// The first value of each stream will be combined, then the second value, and
    /// so forth, until at least one of the streams is exhausted.
    ///
    /// stream - The stream to zip with. This must be an instance of the same
    ///          concrete class as the receiver.
    ///
    /// Returns a new stream of tuples, representing the zipped values of the
    /// two streams.
    func zipWith(stream: Self) -> Self
}

/// Operations built on the RxStream primitives.
///
/// These methods do not need to be overridden, although subclasses may
/// occasionally gain better performance from doing so.
protocol RxStreamOperations : RxStreamProtocol {
    
    /// Maps `block` across the values in the receiver and flattens the result.
    ///
    /// Note that operators applied _after_ flattenMap() behave differently from
    /// operators _within_ flattenMap(). See the Examples section below.
    ///
    /// This corresponds to the `SelectMany` method in Rx.
    ///
    /// block - A block which accepts the values in the receiver and returns a new
    ///         instance of the receiver's class (possibly just an empty signal).
    ///
    /// Examples
    ///
    ///   signal.flattenMap {
    ///       // Logs each time a returned signal completes.
    ///       x in RSignal.lift(x).logCompleted()
    ///   }];
    ///
    ///   // Logs only once, when all of the signals complete.
    ///   signal.flattenMap(RSignal.lift).logCompleted()
    ///
    /// Returns a new stream which represents the combined streams resulting from
    /// mapping `block`.
    func flattenMap(block: Element -> Self) -> Self
    
    // NOTE: flatten moved to RxStreamOfStreamsOperations
    // func flatten() -> Element {
    
    /// Maps `block` across the values in the receiver.
    ///
    /// This corresponds to the `Select` method in Rx.
    ///
    /// Returns a new stream with the mapped values.
    func map(block: Element -> Element) -> Self
    
    /// Replaces each value in the receiver with the given object.
    ///
    /// Returns a new stream which includes the given object once for each value in
    /// the receiver.
    func mapReplace(object: Element) -> Self
    
    /// Filters out values in the receiver that don't pass the given test.
    ///
    /// This corresponds to the `Where` method in Rx.
    ///
    /// Returns a new stream with only those values that passed.
    func filter(block: Element -> Bool) -> Self
    
    /// Filters out values in the receiver that equal (via Equatable) the provided value.
    ///
    /// Returns a new stream containing only the values which did not compare equal
    /// to `value`.
    func ignore(value: Element) -> Self
    
    // NOTE: reduceEach omitted.
    /// Unpacks each RACTuple in the receiver and maps the values to a new value.
    ///
    /// reduceBlock - The block which reduces each RACTuple's values into one value.
    ///               It must take as many arguments as the number of tuple elements
    ///               to process. Each argument will be an object argument. The
    ///               return value must be an object. This argument cannot be nil.
    ///
    /// Returns a new stream of reduced tuple values.
    // func reduceEach(recuceBlock: (RxTuple) -> Element) -> Self
    
    /// Returns a stream consisting of `value`, followed by the values in the
    /// receiver.
    func startWith(value: Element) -> Self
    
    /// Skips the first `skipCount` values in the receiver.
    ///
    /// Returns the receiver after skipping the first `skipCount` values. If
    /// `skipCount` is greater than the number of values in the stream, an empty
    /// stream is returned.
    func skip(skipCount: Int) -> Self
    
    /// Returns a stream of the first `count` values in the receiver. If `count` is
    /// greater than or equal to the number of values in the stream, a stream
    /// equivalent to the receiver is returned.
    func take(count: Int) -> Self
    
/*
    /// Zips the values in the given streams to create tuples.
    ///
    /// The first value of each stream will be combined, then the second value, and
    /// so forth, until at least one of the streams is exhausted.
    ///
    /// streams - The streams to combine. These must all be instances of the same
    ///           concrete class implementing the protocol. If this collection is
    ///           empty, the returned stream will be empty.
    ///
    /// Returns a new stream containing tuples of the zipped values from the
    /// streams.
    class func zip<Seq: Sequence where Seq.GeneratorType.Element == Element>(streams: Seq) -> Self
    
    /// Zips streams using +zip:, then reduces the resulting tuples into a single
    /// value using -reduceEach:
    ///
    /// streams     - The streams to combine. These must all be instances of the
    ///               same concrete class implementing the protocol. If this
    ///               collection is empty, the returned stream will be empty.
    /// reduceBlock - The block which reduces the values from all the streams
    ///               into one value. It must take as many arguments as the
    ///               number of streams given. Each argument will be an object
    ///               argument. The return value must be an object.
    ///
    /// Example:
    ///
    ///   [RxStream zip:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
    ///       return [NSString stringWithFormat:@"%@: %@", string, number];
    ///   }];
    ///
    /// Returns a new stream containing the results from each invocation of
    /// `reduceBlock`.
    class func zip<Seq: Sequence where Seq.GeneratorType.Element == Element>(streams: Seq, reduceBlock: () -> Element) -> Self
    
    /// Returns a stream obtained by concatenating `streams` in order.
    class func concat<Seq: Sequence where Seq.GeneratorType.Element == Element>(streams: Seq) -> Self
    
    /// Combines values in the receiver from left to right using the given block.
    ///
    /// The algorithm proceeds as follows:
    ///
    ///  1. `startingValue` is passed into the block as the `running` value, and the
    ///  first element of the receiver is passed into the block as the `next` value.
    ///  2. The result of the invocation is added to the returned stream.
    ///  3. The result of the invocation (`running`) and the next element of the
    ///  receiver (`next`) is passed into `block`.
    ///  4. Steps 2 and 3 are repeated until all values have been processed.
    ///
    /// startingValue - The value to be combined with the first element of the
    ///                 receiver. This value may be `nil`.
    /// reduceBlock   - The block that describes how to combine values of the
    ///                 receiver. If the receiver is empty, this block will never be
    ///                 invoked.
    ///
    /// Examples
    ///
    ///      RSequence *numbers = @[ @1, @2, @3, @4 ].R_sequence;
    ///
    ///      // Contains 1, 3, 6, 10
    ///      RSequence *sums = [numbers scanWithStart:@0 reduce:^(NSNumber *sum, NSNumber *next) {
    ///          return @(sum.integerValue + next.integerValue);
    ///      }];
    ///
    /// Returns a new stream that consists of each application of `reduceBlock`. If the
    /// receiver is empty, an empty stream is returned.
    func scanWithStart(startingValue: Element?, reduceBlock: (running: Element, next: Element) -> Element) -> Self
    
    /// Combines values in the receiver from left to right using the given block
    /// which also takes zero-based index of the values.
    ///
    /// startingValue - The value to be combined with the first element of the
    ///                 receiver. This value may be `nil`.
    /// reduceBlock   - The block that describes how to combine values of the
    ///                 receiver. This block takes zero-based index value as the last
    ///                 parameter. If the receiver is empty, this block will never
    ///                 be invoked. Cannot be nil.
    ///
    /// Returns a new stream that consists of each application of `reduceBlock`. If the
    /// receiver is empty, an empty stream is returned.
    func scanWithStart(startingValue: Element?, reduceBlock: (running: Element, next: Element, index: Int) -> Element) -> Self
    
    /// Combines each previous and current value into one object.
    ///
    /// This method is similar to -scanWithStart:reduce:, but only ever operates on
    /// the previous and current values (instead of the whole stream), and does not
    /// pass the return value of `reduceBlock` into the next invocation of it.
    ///
    /// start       - The value passed into `reduceBlock` as `previous` for the
    ///               first value.
    /// reduceBlock - The block that combines the previous value and the current
    ///               value to create the reduced value.
    ///
    /// Examples
    ///
    ///      RSequence *numbers = @[ @1, @2, @3, @4 ].R_sequence;
    ///
    ///      // Contains 1, 3, 5, 7
    ///      RSequence *sums = [numbers combinePreviousWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
    ///          return @(previous.integerValue + next.integerValue);
    ///      }];
    ///
    /// Returns a new stream consisting of the return values from each application of
    /// `reduceBlock`.
    func combinePreviousWithStart(start: Element?, reduceBlock: (previous: Element, current: Element) -> Element) -> Self
    
    /// Takes values until the given block returns `YES`.
    ///
    /// Returns a stream of the initial values in the receiver that fail `predicate`.
    /// If `predicate` never returns `YES`, a stream equivalent to the receiver is
    /// returned.
    func takeUntilBlock(predicate: Element -> Bool) -> Self
    
    /// Takes values until the given block returns `NO`.
    ///
    /// Returns a stream of the initial values in the receiver that pass `predicate`.
    /// If `predicate` never returns `NO`, a stream equivalent to the receiver is
    /// returned.
    func takeWhileBlock(predicate: Element -> Bool) -> Self
    
    /// Skips values until the given block returns `YES`.
    ///
    /// Returns a stream containing the values of the receiver that follow any
    /// initial values failing `predicate`. If `predicate` never returns `YES`,
    /// an empty stream is returned.
    func skipUntilBlock(predicate: Element -> Bool) -> Self
    
    /// Skips values until the given block returns `NO`.
    ///
    /// Returns a stream containing the values of the receiver that follow any
    /// initial values passing `predicate`. If `predicate` never returns `NO`, an
    /// empty stream is returned.
    func skipWhileBlock(predicate: Element -> Bool) -> Self
    
    /// Returns a stream of values for which -isEqual: returns NO when compared to the
    /// previous value.
    func distinctUntilChanged() -> Self
*/
}

protocol RxStreamOfStreamsOperations :  RxStreamOperations {
    
    /// Flattens a stream of streams.
    ///
    /// This corresponds to the `Merge` method in Rx.
    ///
    /// Returns a stream consisting of the combined streams obtained from the
    /// receiver.
    func flatten() -> Element
}

/// A class representing any stream of values.
///
/// This class represents a monad, upon which many stream-based operations can
/// be built.
///
/// When subclassing RxStream, only the methods in the RxStreamProtocol need
/// to be overridden.
class RxStream<T: RxElementType> : RxStreamProtocol {
    typealias Element = T
    typealias RxStreamBindBlock = (value: Element, stop: inout Bool) -> RxStream
    
    /// Set name for debugging
    var name : String = ""
    
    class func empty() -> RxStream { return RxStream() }
    class func lift(value: Element) -> RxStream { return RxStream() }
    func bind(block: () -> RxStreamBindBlock) -> RxStream { return RxStream() }
    func concat(stream: RxStream) -> RxStream { return RxStream() }
    func zipWith(stream: RxStream) -> RxStream { return RxStream() }
}

// Attempt to make RxStream Equatable
func ==<T, R: RxStream<T>>(lhs: R, rhs: R) -> Bool {
    return false
}

/// This extension contains functionality to support naming streams for
/// debugging.
///
/// Subclasses do not need to override the methods here.
extension RxStream {
    
    /// Sets the name of the receiver to the given string.
    ///
    /// This is for debugging purposes only, and won't do anything unless the
    /// RX_DEBUG_SIGNAL_NAMES environment variable is set.
    ///
    /// Returns the receiver, for easy method chaining.
    func setName(name: String) -> RxStream {
        self.name = name
        return self
    }
}

/// Operations built on the RxStream primitives.
///
/// These methods do not need to be overridden, although subclasses may
/// occasionally gain better performance from doing so.
extension RxStream : RxStreamOperations {
    
    func flattenMap(block: Element -> RxStream) -> RxStream {
        var stream = bind {
            return {
                value, stop in
                return block(value)
            }
        }
        return stream.setName("[\(name)] flattenMap")
    }
    
    func map(block: Element -> Element) -> RxStream {
        var stream = flattenMap { value in RxStream.lift(block(value)) }
        return stream.setName("[\(name)] map")
    }
    
    func mapReplace(object: Element) -> RxStream {
        var stream = map { _ in object }
        return stream.setName("[\(name)] mapReplace")
    }
    
    func filter(block: Element -> Bool) -> RxStream {
        var stream = flattenMap {
            value in
            if block(value) {
                return RxStream.lift(value)
            } else {
                RxStream.empty()
            }
        }
        return stream.setName("[\(name)] filter")
    }
    
    func ignore(value: Element) -> RxStream {
        var stream = filter {x in x != value}
        return stream.setName("[\(name)] ignore")
    }
  
    // NOTE: reduceEach omitted.
    // func reduceEach(recuceBlock: (RxTuple) -> Element) -> RxStream
    
    func startWith(value: Element) -> RxStream {
        var stream = RxStream.lift(value).concat(self)
        return stream.setName("[\(name)] startWith")
    }
    
    func skip(skipCount: Int) -> RxStream {
        var stream = bind {
            var skipped = 0
            return {
                value, stop in
                if skipped >= skipCount {
                    return RxStream.lift(value)
                } else {
                    skipped++
                    return RxStream.empty()
                }
            };
        }
        return stream.setName("[\(name)] skip")
    }
    
    func take(count: Int) -> RxStream {
        var stream = bind {
            var taken = 0
            return {
                value, stop in
                if taken < count {
                    return RxStream.lift(value)
                } else {
                    if ++taken >= count {
                        stop = true;
                    }
                    return RxStream.empty()
                }
            };
        }
        return stream.setName("[\(name)] take")
    }
    
    // (Missing implementations...)
}
