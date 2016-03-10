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
    private typealias InstanceIdentifier = Int
    public typealias Function = ArgumentType -> Void
    
    private var functions: [(weak: WeakObject, function: Function)] = []
    private let asynchronous: Bool
    private let queue: dispatch_queue_t?
    
    public convenience init() {
        self.init(synchronous: false)
    }
    
    public convenience init(synchronous: Bool) {
        self.init(synchronous: true, queue: dispatch_get_main_queue())
    }
    
    public init(synchronous: Bool, queue: dispatch_queue_t?) {
        self.asynchronous = !synchronous
        self.queue = queue
        assert(queue != nil || synchronous, "Cannot dispatch asynchronously without a queue.")
    }
    
    /**
     There can only be one function registered per instance. And it will be called asynchronously, on the main thread.
     
     If you call this again with the same instance, the previously associated function will be overridden with this one.
     */
    public func setFunction<InstanceType: AnyObject>(function: InstanceType -> Function, forInstance instance: InstanceType) {
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
    
    public func removeFunctionForInstance(instance: AnyObject) {
        threadSafety {
            self._removeFunctionForInstance(instance)
        }
    }
    
    private func _removeFunctionForInstance(instance: AnyObject, object: AnyObject? = nil) {
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
    
    private func threadSafety(closure: () -> Void) {
        if asynchronous {
            dispatch_async(threadSafetyQueue, closure)
        } else {
            dispatch_sync(threadSafetyQueue, closure)
        }
    }
    
    private func execute(argument argument: ArgumentType, object: AnyObject? = nil) {
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
    
    /**
     We manually clean up listeners that have deallocated whenever setFunction or emit is called.
     */
    private func removeNullListeners() {
        functions = functions.filter({ $0.weak.object != nil })
    }
}
