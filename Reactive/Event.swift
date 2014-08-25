//
//  Event.swift
//  Reactive
//
//  Created by Jens Jakob Jensen on 25/08/14.
//  Copyright (c) 2014 Jayway. All rights reserved.
//


/// This maps a struct inside a class to get Hashable and Equatable (used by Splitter), and to avoid a bug in beta 6 (in the definition of Event)
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
    /// A value.
    /// Box the value due to an unimplemented feature in beta 6: "unimplemented IR generation feature non-fixed multi-payload enum layout".
    case Value(Box<T>)
    /// Completed without error. This is an ending event: No more events will be emitted.
    case Completed
    /// Stopped prematurely without error (terminated). This is an ending event: No more events will be emitted.
    case Stopped
    /// Error. This is an ending event: No more events will be emitted.
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
