
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

fileprivate let izEventThreadSafetyQueue = DispatchQueue(label: "IZEvent.threadSafety")

/**
 A pure-swift alternative to NSNotificationCenter. It's safer and more convenient.
 
 By default events are delivered on the same thread as they were emitted.
 
 By default events are delivered synchronously.
 
 Crashes against deadlocks.
 */
open class IZEvent<ValueType> {
    
    struct Listener {
        
        weak var weakObject: AnyObject?
        
        typealias Function = (ValueType)->Any?
        
        let function: Function
        
        var listening: Bool {
            
            return weakObject != nil
        }
    }
    
    typealias Listeners = [Listener]
    
    fileprivate var listeners: Listeners = []
    
    fileprivate let threadSafety = izEventThreadSafetyQueue
    
    open var targetQueue: DispatchQueue?
    
    open var sync: Bool
    
    /// init without a targetQueue
    init() {
        
        self.targetQueue = nil
        self.sync = false
    }
    
    /// init with a queue to define sync (default = true)
    init(targetQueue: DispatchQueue, sync: Bool = true) {
        
        self.targetQueue = targetQueue
        self.sync = sync
    }
    
    /// can pass in a function that returns void ( captures () (or Void) as Any )
    /// associates the instance as the owner of the function
    /// if the owner becomes nil, the function is removed
    open func register(_ instance: AnyObject, function: @escaping (ValueType) -> Any?) {
        
        threadSafety.sync {
            
            filterListeners()
            
            listeners.removeFirst(where: {$0.weakObject === instance})
            
            listeners.append(
                
                Listener(
                    weakObject: instance,
                    function: function
                )
            )
        }
    }
    
    /// calls the function then registers
    open func register<Instance: AnyObject>(_ instance: Instance, function: @escaping (Instance) -> (ValueType) -> Any?) {
        
        register(instance, function: function(instance))
    }
    
    /// registers the type as an AnyObject
    open func register(_ instanceType: AnyObject.Type, function: @escaping (ValueType) -> Any?) {
        
        register(instanceType as AnyObject, function: function)
    }
    
    // filters the listeners to confirm that the object is not deallocated
    fileprivate func filterListeners() {
        
        listeners = listeners.filter({$0.listening})
    }
    
    /// removes the Listener for that instance
    open func unregister(_ instance: AnyObject) {
        threadSafety.sync {
            listeners.removeFirst(where: {$0.weakObject === instance})
        }
    }
    
    /// calls unregister with instanceType as AnyObject
    open func unregister(_ instanceType: AnyObject.Type) {
        
        unregister(instanceType as AnyObject)
    }
    
    open func unregisterAll() {
        threadSafety.sync {
            listeners.removeAll()
        }
    }
    
    // gets the current values through the safetyQueue
    fileprivate func getValues() -> (Listeners, DispatchQueue?, Bool) {
        
        return threadSafety.sync {
            
            filterListeners()
            
            return (listeners, targetQueue, sync)
        }
    }
    
    /**
     Calls the listeners capturing the value and returning the results
     
     if sync = false and queue != nil, returns an empty array
     
     warning: where sync = true && the queue != .main && queue is (current queue) will be fatal (to avoid deadlock)
     
     */
    @discardableResult open func post(_ captureValue: ValueType) -> [Any?] {
        
        let (listeners, queue, sync) = getValues()
        
        return post(block: {
            
            var values: [Any?] = []
            
            for listener in listeners {
                
                values.append(listener.function(captureValue))
            }
            
            return values
            
        }, queue: queue, sync: sync)
    }
    
    
    // figures out which queue and method to call when posting
    fileprivate func post(block: @escaping ()->[Any?], queue: DispatchQueue?, sync: Bool) -> [Any?] {
        
        
        if let queue = queue {
            
            if sync {
                
                if queue == .main && Thread.isMainThread {
                    
                    return block()
                    
                } else {
                    
                    // OH_GEEZ_HOPE_DIZ_DOESNT_DEADLOCK
                    
                    // Nope, just crash.
                    
                    dispatchPrecondition(condition: .notOnQueue(queue))
                    
                    return queue.sync {
                        
                        return block()
                    }
                }
                
            } else {
                
                queue.async {
                    
                    _ = block()
                }
                
                return []
            }
            
        } else {
            
            return block()
        }
    }
}

extension IZEvent where ValueType: AnyObject {
    
    ///posts the value weakly.
    @discardableResult open func post(weak value: ValueType) -> [Any?] {
        
        let (listeners, queue, sync) = getValues()
        
        return post(block: { [weak value] in
            
            guard let value = value else {
                return []
            }
            
            var values: [Any?] = []
            
            for listener in listeners {
                
                values.append(listener.function(value))
            }
            
            return values
            
        }, queue: queue, sync: sync)
    }
}
