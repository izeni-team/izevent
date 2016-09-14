//
//  ExampleTests.swift
//  ExampleTests
//
//  Created by Christopher Bryan Henderson on 3/4/16.
//  Copyright © 2016 Izeni. All rights reserved.
//

import XCTest
@testable import Example

class Listener: Equatable, CustomDebugStringConvertible {
    static var orderOfDelivery = [Listener]()
    static var staticFuncDelivered = false
    
    let id = UUID()
    var noArgDate: Date?
    var stringArgValue: String?
    var multiArgValue: (str: String, int: Int)?
    
    init() {
        Listener.orderOfDelivery.removeAll()
        Listener.staticFuncDelivered = false
    }
    
    func reset() {
        noArgDate = nil
    }
    
    func noArg() {
        noArgDate = Date()
        delivered()
    }
    
    var debugDescription: String {
        return id.debugDescription
    }
    
    func stringArg(_ string: String) {
        stringArgValue = string
        delivered()
    }
    
    func multiArg(_ string: String, integer: Int) {
        multiArgValue = (str: string, int: integer)
        delivered()
    }
    
    func delivered() {
        Listener.orderOfDelivery.append(self)
    }
    
    static func staticFunc() {
        Listener.staticFuncDelivered = true
    }
}

func ==(lhs: Listener, rhs: Listener) -> Bool {
    return lhs.id == rhs.id
}

class ExampleTests: XCTestCase {
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
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let expectation = self.expectation(description: "Event Listening")
        
        // Test being run from the main thread.
        self.testNoArgs(synchronous: true) {
            // Test being run from a background thread.
            DispatchQueue.global(qos: .background).async {
                self.testNoArgs(synchronous: true) {
                    self.testNoArgs(synchronous: false) {
                        self.testOneArg {
                            self.testMultipleArgs {
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        self.waitForExpectations(timeout: 60) { (error) -> Void in
            XCTAssertNil(error)
        }
    }
    
    func testNoArgs(synchronous: Bool, completion: @escaping () -> Void) {
        let event = IZEvent<Void>(synchronous: synchronous, queue: DispatchQueue.main)
        let listenerA = Listener()
        let listenerB = Listener()
        let wait = self.wait
        
        let reset = { () -> Void in
            listenerA.reset()
            listenerB.reset()
            Listener.orderOfDelivery.removeAll()
        }
        
        // Make sure it doesn't crash when nothing is listening.
        event.post()
        
        // Test order of delivery.
        event.register(listenerA, function: Listener.noArg)
        event.register(listenerB, function: Listener.noArg)
        event.post()
        
        wait {
            XCTAssert(Listener.orderOfDelivery == [listenerA, listenerB])
            reset()
            
            // Test reverse order of delivery.
            event.register(listenerA, function: Listener.noArg) // This is supposed to put A after B
            event.post()
            
            wait {
                XCTAssert(Listener.orderOfDelivery == [listenerB, listenerA])
                reset()
                
                // Test removal of listener.
                event.unregister(listenerA)
                event.post()

                wait {
                    XCTAssert(Listener.orderOfDelivery == [listenerB] && listenerA.noArgDate == nil)
                    reset()
                    
                    // Test removal of all functions
                    event.unregisterAll()
                    event.post()
                    wait {
                        XCTAssert(Listener.orderOfDelivery.isEmpty && listenerA.noArgDate == nil && listenerB.noArgDate == nil)
                        event.unregisterAll()
                        reset()
                        
                        // Test static function
                        event.register(Listener.self, function: Listener.staticFunc)
                        event.post()
                        wait {
                            XCTAssert(Listener.staticFuncDelivered)
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    func testOneArg(_ completion: () -> Void) {
        let event = IZEvent<String>(synchronous: true)
        let listener = Listener()
        event.register(listener, function: Listener.stringArg)
        event.post("Test")
        XCTAssert(listener.stringArgValue == "Test")
        completion()
    }
    
    func testMultipleArgs(_ completion: @escaping () -> Void) {
        let event = IZEvent<(str: String, int: Int)>(synchronous: false)
        let listener = Listener()
        
        event.register(listener, function: Listener.multiArg)
        event.post((str: "Hello, World!", int: 3))
        wait {
            print(Listener.orderOfDelivery)
            XCTAssert(Listener.orderOfDelivery == [listener])
            XCTAssert(listener.multiArgValue != nil && listener.multiArgValue!.str == "Hello, World!" && listener.multiArgValue!.int == 3)
            completion()
        }
    }
    
    func wait(_ closure: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Float(NSEC_PER_SEC) * 0.01)) / Double(NSEC_PER_SEC), execute: closure)
    }
}
