// The MIT License (MIT)
//
// Copyright (c) 2016 Izeni, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// ermit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of
// the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
// OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

/**
 Used to tell whether or not the event has outlived the listener.
 */
private struct WeakObject {
    weak var object: AnyObject?
}

fileprivate let threadSafetyQueue = DispatchQueue(label: "IZEvent.threadSafetyQueue")

/**
 A pure-swift alternative to NSNotificationCenter. It's safer and more convenient.
 
 By default events are delivered on the same thread as they were emitted.
 
 By default events are delivered synchronously.
 
 Makes no guarantees against deadlocks if queue != main queue.
 */
open class IZEvent<ValueType> {
    fileprivate typealias Function = (weak: WeakObject, function: (ValueType) -> Void)
    fileprivate var listeners: [Function] = []
    fileprivate let asynchronous: Bool
    fileprivate let queue: DispatchQueue?
    
    /**
     Uses the main queue. Synchronous.
     */
    public convenience init() {
        self.init(synchronous: true)
    }
    
    /**
     Uses the main queue.
     */
    public convenience init(synchronous: Bool) {
        self.init(synchronous: synchronous, queue: DispatchQueue.main)
    }
    
    /**
     Synchronous. If queue is passed in as nil, then GCD won't be used at all (nil does not mean "main queue").
     */
    public convenience init(queue: DispatchQueue?) {
        self.init(synchronous: true, queue: queue)
    }
    
    /**
     If queue is passed in as nil, then GCD won't be used at all (nil does not mean "main queue").
     */
    public init(synchronous: Bool, queue: DispatchQueue?) {
        self.asynchronous = !synchronous
        self.queue = queue
        assert(queue != nil || synchronous, "Cannot dispatch asynchronously without a queue.")
    }
    
    /**
     There can only be one function registered per instance. Check the event declaration to see whether or not it will
     be synchronous and which queue it will be delivered on.
     
     If you call this again with the same instance, the previously associated function will be overridden with this one.
     In other words, only one function per instance can be registered with an event at a time.
     */
    open func register<InstanceType: AnyObject>(_ instance: InstanceType, function: @escaping (InstanceType) -> (ValueType) -> Void) {
        threadSafety {
            self.removeNullListeners()
            
            // If called again, put it to the end of the list.
            self._unregister(instance)
            
            self.listeners.append((
                // Used to tell whether or not this event has outlived the listener instance.
                weak: WeakObject(object: instance),
                
                // Instance must be weak to avoid a retention cycle (in other words, to avoid memory leaks).
                function: { [weak instance] (argument) -> Void in
                    if let instance = instance {
                        function(instance)(argument)
                    }
                }
            ))
        }
    }
    
    /**
     Used for setting class/static functions as recipients, as opposed to instances.
     
     Only 1 function per class is supported.
     */
    open func register<InstanceType: AnyObject>(_ instanceType: InstanceType.Type, function: @escaping (ValueType) -> Void) {
        threadSafety {
            self.removeNullListeners()
            
            // If called again, put it to the end of the list.
            self._unregister(instanceType)
            
            self.listeners.append((
                // Used to tell whether or not this event has outlived the listener instance.
                weak: WeakObject(object: instanceType),
                
                // Instance must be weak to avoid a retention cycle (in other words, to avoid memory leaks).
                function: function
            ))
        }
    }
    
    fileprivate func threadSafety(_ closure: () -> Void) {
        threadSafetyQueue.sync(execute: closure)
    }
    
    /**
     We manually clean up listeners that have deallocated whenever setFunction or emit is called.
     */
    fileprivate func removeNullListeners() {
        listeners = listeners.filter({ $0.weak.object != nil })
    }
    
    // Can unregister either an instance or an individual class.
    open func unregister(_ instance: AnyObject) {
        threadSafety {
            self._unregister(instance)
        }
    }
    
    fileprivate func _unregister(_ instance: AnyObject) {
        self.removeNullListeners()
        if let index = self.listeners.index(where: { $0.weak.object === instance }) {
            self.listeners.remove(at: index)
        }
    }
    
    open func unregisterAll() {
        threadSafety {
            self.listeners.removeAll()
        }
    }
    
    open func post(_ value: ValueType) {
        post([value])
    }
    
    /**
     Calls all functions registered with this event.
     */
    fileprivate func post(_ values: [ValueType]) {
        var functions: [Function]?
        
        threadSafety {
            guard !self.listeners.isEmpty else {
                return
            }
            
            self.removeNullListeners()
            functions = self.listeners
        }
        
        if let functions = functions {
            for value in values {
                self.execute(functions, value: value)
            }
        }
    }
    
    fileprivate func execute(_ listeners: [Function], value: ValueType) {
        let exec = { () -> Void in
            for listener in listeners {
                listener.function(value)
            }
        }

        if asynchronous {
            queue!.async(execute: exec)
        } else if queue === DispatchQueue.main && Thread.isMainThread {
            // Don't deadlock.
            exec()
        } else if let queue = queue {
            queue.sync(execute: exec)
        } else {
            exec()
        }
    }
}
