//
//  ReactiveTests.swift
//  ReactiveTests
//
//  Created by Jens Jakob Jensen on 19/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

import XCTest
import Reactive


// ==== If this is uncommented, the testMergeFilter() test succeeds! ====
public func emitValue(value: Int) (sink: Types<Int>.Sink) -> TerminatorType {
    sink.put(Event.fromValue(value))
    sink.put(.Completed)
    return BlockTerminator { fatalError("Not terminatable") }
}
func mergeFilter(pred: Int -> Bool) -> (sink: Types<Int>.Sink) -> Types<Int>.Sink {
    return map {
        value -> Types<Int>.Emitter in
        if pred(value) {
            return emitValue(value)
        } else {
            return emptyEmitter()
        }
        }
        .. merge
}
// ==== If the above lines are uncommented, the testMergeFilter() test succeeds! ====


class ArrayVerifier<T: Equatable> {
    let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
    let facit: [T]
    var result: [T] = []
    init(facit: [T]) {
        self.facit = facit
    }
    var input: Types<T>.Sink {
        return toArray {
            array in
            self.result = array
            dispatch_semaphore_signal(self.semaphore)
            }
    }
    func wait() {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        XCTAssert(result == facit)
    }
}

class Verifier<T: Equatable> {
    let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
    let facit: T
    var result: T?
    init(facit: T) {
        self.facit = facit
    }
    var input: Types<T>.Sink {
        return accept(
            onValue: { v in self.result = v },
            onEnd:   { dispatch_semaphore_signal(self.semaphore); return }
            )
    }
    func wait() {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        XCTAssert(result! == facit)
    }
}

func mergeFilter<T>(pred: T -> Bool) -> (sink: Types<T>.Sink) -> Types<T>.Sink {
    return map {
        value -> Types<T>.Emitter in
        if pred(value) {
            return emitValue(value)
        } else {
            return emptyEmitter()
        }
        }
        .. merge
}


class ReactiveTests: XCTestCase {
    
    let queue = dispatch_queue_create("ReactiveTests", DISPATCH_QUEUE_SERIAL)
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSequence() {
        var verifier = ArrayVerifier(facit: [1, 3, 5, 7, 9])
        emitElements([1, 3, 5, 7, 9], onQueue: queue) .. verifier.input
        verifier.wait()
    }
    
    func testMapAndFilter() {
        var verifier = ArrayVerifier(facit: [2, 4, 6, 8])
        emitElements([1, 3, 5, 7, 9], onQueue: queue) .. map { $0 + 1 } .. filter { $0 < 10 } .. verifier.input
        verifier.wait()
    }
    
    func testReduce() {
        var verifier1 = Verifier(facit: "A B C D E F G H I ")
        let letters = "A B C D E F G H I".componentsSeparatedByString(" ")
        emitElements(letters) .. reduce(initial: "") { c, v in c + "\(v) " } .. verifier1.input
        verifier1.wait()
        
        var verifier2 = Verifier(facit: "A B C D E F G H I ")
        emitElements("ABCDEFGHI") .. reduce(initial: "") { c, v in c + "\(v) " } .. verifier2.input
        verifier2.wait()
    }
    
    func testSplitter() {
        var splitter = Splitter<Int>()
        var verifier1 = Verifier(facit: "1: 0 2 4 6 ")
        splitter.newOutput
            .. map { $0 * 2 }
            .. reduce(initial: "1: ") { c, v in c + "\(v) " }
            .. verifier1.input
        var verifier2 = Verifier(facit: "2: 0 1 2 3 ")
        splitter.newOutput
            .. reduce(initial: "2: ") { c, v in c + "\(v) " }
            .. verifier2.input
        var verifier3 = ArrayVerifier(facit: [0, 1, 2, 3])
        splitter.newOutput
            .. verifier3.input
        var verifier4 = ArrayVerifier(facit: [0, -1, -2, -3])
        splitter.newOutput
            .. map { -$0 }
            .. verifier4.input
        
        emitElements([1, 2, 3, 4], onQueue: queue) .. map { $0 - 1 } .. splitter.input
        
        verifier1.wait()
        verifier2.wait()
        verifier3.wait()
        verifier4.wait()
    }
    
    func testAsync() {
        class C {
            struct Static {
                static var innerDone = false
            }
            func ping(s: String) {
                println("C.ping " + s)
            }
            deinit {
                emitValue("C.deinit") .. accept { v in println(v) }
                //XCTAssert(Static.innerDone, "innerDone was supposed to be true")
                if (!Static.innerDone) {
                    // As XCTAssert doesn't work async...
                    fatalError("innerDone was supposed to be true")
                }
            }
        }
        func inner() {
            var c = C()
            emitElements([1, 2, 3], onQueue: queue)
                .. accept { v in c.ping("\(v)") }
        }
        inner()
        println("inner() done")
        C.Static.innerDone = true
    }
    
    func testConcat() {
        let localQueue = dispatch_queue_create("testConcat", DISPATCH_QUEUE_SERIAL)
        
        let verifier = ArrayVerifier(facit: [1, 2, 3, 4, 9, 8, 7, 6])
        let emitters: [Types<Int>.Emitter] = [
            emitElements([1, 2, 3, 4], onQueue: queue) .. throttle(0.001),
            emitElements([9, 8, 7, 6], onQueue: localQueue)
        ]
        emitElements(emitters) .. concat .. verifier.input
    }
    
    func testMerge() {
        typealias IntSet = Dictionary<Int,()>
        
        let queue1 = dispatch_queue_create("testMerge 1", DISPATCH_QUEUE_SERIAL)
        let queue2 = dispatch_queue_create("testMerge 2", DISPATCH_QUEUE_SERIAL)
        
        let verifier = Verifier(facit: [1, 2, 3, 4, 6, 7, 8, 9])
        let emitters: [Types<Int>.Emitter] = [
            emitElements([1, 2, 3, 4], onQueue: queue1) .. throttle(0.001),
            emitElements([9, 8, 7, 6], onQueue: queue2) .. throttle(0.001)
        ]
        emitElements(emitters)
            .. merge
            .. reduce(initial: IntSet()) { (var set, i) in set[i] = (); return set }
            .. map { set in sorted(set.keys) }
            .. verifier.input
        verifier.wait()
    }
    
    func testMergeFilter() {
        let verifier = ArrayVerifier(facit: [2, 4, 6, 8])
        emitElements([1, 2, 3, 4, 5, 6, 7, 8, 9])
            .. mergeFilter { $0 % 2 == 0 }
            .. verifier.input
        verifier.wait()
    }
    
    func testStop() {
        var t = timer(0.02) .. accept(onValue: { println("testStop: timer fired") }, onStopped: { println("testStop() was stopped") })
        NSThread.sleepForTimeInterval(0.1)
        //t.stop() // Crashes in beta 6
    }
    
    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
}
