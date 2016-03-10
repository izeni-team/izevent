# IZEvent

IZEvent is a pure-Swift alternative to NSNotificationCenter. It strives to be easy, safe, and simple. Pro's over NSNotificationCenter:

- Memory-safe: No memory leaks are possible and no need to remove observers in deinit
- Thread-safe: Delivers events to main thread by default
- Type-safe: A pure-Swift implementation means that everything is type-checked at _compile-time_, not run-time
- User-safe: Every instance can only ever have 1 function registered with an event at a time--no double registering is possible

## Installation

Add the folowing to your Podfile:

```
pod 'IZEvent', :git => 'https://dev.izeni.net/bhenderson/izevent.git'
```

## Usage

1. Create an event.

```swift
class MyService {
    static let simpleEvent = IZEvent<Void>() // Synchronous, main thread delivery by default.
    static let complexEvent = IZEvent<(String, Int)>(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0))
}
```

2. Listen for the event.

```swift
class MyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        MyService.simpleEvent.set(self, function: MyViewController.simpleEventEmitted)
        MyService.complexEvent.set(self, function: MyViewController.complexEventEmitted)
    }

    func simpleEventEmitted() {
        assert(NSThread.isMainThread()) // Guaranteed to be run on main thread.
        print("Something happened!")
    }

    func complexEventEmitted(string: String, integer: Int) {
        assert(NSThread.isMainThread() == false) // All functions from this event are delivered on the background thread.
        print("string: \(string), integer: \(integer)")
    }
}
```

3. Emit the event.

```swift
class MyService {
    ...
    func somethingHappened() {
        MyService.simpleEvent.emit()
        MyService.complexEvent.emit(("How Many?", 3))
    }
}
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## History

v0.2.0 - Functions are shorter. Added support for static functions. Synchronous by default.
v0.1.0 - First version.

## Credits

tbrimhall@izeni.com (for pointing out the need), bhenderson@izeni.com (for initial implementation)

## License

The MIT License (MIT)

Copyright (c) 2016 Izeni, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
