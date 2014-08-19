//
//  ReactiveTests.swift
//  ReactiveTests
//
//  Created by Jens Jakob Jensen on 19/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//

import UIKit
import XCTest
import Reactive


func verify<T: Equatable>(var facit: [T]) (sink: Reactive.Types<T>.Sink) -> SinkOf<Event<T>> {
    var verified = true
    return SinkOf {
        event in
        switch event {
        case .Value(let valueBox):
            if valueBox.unbox() != facit.first! {
                XCTAssert(false, "Unexpected value")
                verified = false
            }
            facit.removeAtIndex(0)
        case .Completed:
            if facit.count > 0 {
                XCTAssert(false, "Unexpected number of values")
                verified = false
            }
            println(verified ? "OK" : "FAILED")
            XCTAssert(true, "Verified OK")
        case .Error(let error):
            println("Error: \(error)")
            XCTAssert(false, "Unexpected .Error \(error)")
        case .Stopped:
            println("Stopped")
            XCTAssert(false, "Unexpected .Stopped")
        }
        sink.put(event)
    }
}

class ReactiveTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        let queue = dispatch_queue_create("test5", DISPATCH_QUEUE_SERIAL)
        push([1, 3, 5, 7, 9], onQueue: queue)
            .. map { $0 + 1 } .. filter { $0 < 10 } .. verify([2,4,6,8]) .. onMain .. accept { println($0) }
        XCTAssert(true, "Pass")
    }
    
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measureBlock() {
//            // Put the code you want to measure the time of here.
//        }
//    }
    
}
