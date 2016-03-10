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

/**
 Used to tell whether or not the event has outlived the listener.
 */
private struct WeakObject {
    weak var object: AnyObject?
}

private let threadSafetyQueue = dispatch_queue_create("IZEvent.threadSafetyQueue", DISPATCH_QUEUE_SERIAL)

/**
 A pure-swift alternative to NSNotificationCenter. It's safer and more convenient.
 
 Events are delivered asynchronously by default to better ensure order of delivery.
 
 Defaults to main queue, but can be changed. Makes no guarantees against deadlocks if queue != main queue.
 */
public class IZEvent<ArgumentType> {
    private var functions: [(weak: WeakObject, function: ArgumentType -> Void)] = []
    private let asynchronous: Bool
    private let queue: dispatch_queue_t?
    
    public convenience init() {
        self.init(synchronous: false)
    }
    
    public convenience init(synchronous: Bool) {
        self.init(synchronous: true, queue: dispatch_get_main_queue())
    }
    
    /**
     If queue is passed in as nil, then GCD won't be used at all (nil does not mean "main queue"). If you want the main
     queue, pass it in or use another initializer.
     */
    public init(synchronous: Bool, queue: dispatch_queue_t?) {
        self.asynchronous = !synchronous
        self.queue = queue
        assert(queue != nil || synchronous, "Cannot dispatch asynchronously without a queue.")
    }
    
    /**
     There can only be one function registered per instance. And it will be called asynchronously, on the main thread
     (by default anyways).
     
     If you call this again with the same instance, the previously associated function will be overridden with this one.
     */
    public func setFunction<InstanceType: AnyObject>(function: InstanceType -> ArgumentType -> Void, forInstance instance: InstanceType) {
        threadSafety {
            self.removeNullListeners()
            
            // If called again, put it to the end of the list.
            self._removeFunctionForInstance(instance)
            
            self.functions.append((
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
    
    private func threadSafety(closure: () -> Void) {
        if asynchronous {
            dispatch_async(threadSafetyQueue, closure)
        } else {
            dispatch_sync(threadSafetyQueue, closure)
        }
    }
    
    /**
     We manually clean up listeners that have deallocated whenever setFunction or emit is called.
     */
    private func removeNullListeners() {
        functions = functions.filter({ $0.weak.object != nil })
    }
    
    public func removeFunctionForInstance(instance: AnyObject) {
        threadSafety {
            self._removeFunctionForInstance(instance)
        }
    }
    
    private func _removeFunctionForInstance(instance: AnyObject) {
        self.removeNullListeners()
        if let index = self.functions.indexOf({ $0.weak.object === instance }) {
            self.functions.removeAtIndex(index)
        }
    }
    
    public func removeAllFunctions() {
        threadSafety {
            self.functions.removeAll()
        }
    }
    
    /**
     Calls all functions registered with this event.
     
     Will call all functions on the main thread, asynchronously.
     
     Functions are executed asynchronously to guarantee full delivery. In the event that a function also
     emits an event, all functions registered with this event will get called before the next event emits.
     
     Events are emitted on the main thread because this class was intended to be used for Service -> GUI
     communication (i.e., for notifications that directly result in a user-visible change in the GUI).
     */
    public func emit(argument: ArgumentType) {
        threadSafety {
            guard !self.functions.isEmpty else {
                return
            }
            
            self.removeNullListeners()
            self.execute(argument: argument)
        }
    }
    
    private func execute(argument argument: ArgumentType) {
        let exec = { () -> Void in
            for listener in self.functions {
                listener.function(argument)
            }
        }
    
        if asynchronous {
            dispatch_async(queue!, exec)
        } else if queue === dispatch_get_main_queue() && NSThread.isMainThread() {
            // Don't deadlock.
            exec()
        } else if let queue = queue {
            dispatch_sync(queue, exec)
        } else {
            exec()
        }
    }
}
