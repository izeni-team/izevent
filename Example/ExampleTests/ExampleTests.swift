//
//  ExampleTests.swift
//  ExampleTests
//
//  Created by Christopher Bryan Henderson on 3/4/16.
//  Copyright © 2016 Izeni. All rights reserved.
//

import XCTest
import IZEvent
@testable import Example

class Listener: Equatable, CustomDebugStringConvertible {
    static var orderOfDelivery = [Listener]()
    
    let id = NSUUID()
    var noArgDate: NSDate?
    var stringArgValue: String?
    var multiArgValue: (str: String, int: Int)?
    
    init() {
        Listener.orderOfDelivery.removeAll()
    }
    
    func reset() {
        noArgDate = nil
    }
    
    func noArg() {
        noArgDate = NSDate()
        delivered()
    }
    
    var debugDescription: String {
        return id.debugDescription
    }
    
    func stringArg(string: String) {
        stringArgValue = string
        delivered()
    }
    
    func multiArg(string: String, integer: Int) {
        multiArgValue = (str: string, int: integer)
        delivered()
    }
    
    func delivered() {
        Listener.orderOfDelivery.append(self)
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
        
        let expectation = self.expectationWithDescription("Event Listening")
        
        // Test being run from the main thread.
        self.testNoArgs(synchronous: true) {
            // Test being run from a background thread.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
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
        
        self.waitForExpectationsWithTimeout(60) { (error) -> Void in
            XCTAssertNil(error)
        }
    }
    
    func testNoArgs(synchronous synchronous: Bool, completion: () -> Void) {
        let event = IZEvent<Void>(synchronous: synchronous)
        let listenerA = Listener()
        let listenerB = Listener()
        let wait = self.wait
        
        let reset = { () -> Void in
            listenerA.reset()
            listenerB.reset()
            Listener.orderOfDelivery.removeAll()
        }
        
        // Make sure it doesn't crash when nothing is listening.
        event.emit()
        
        // Test order of delivery.
        event.setFunction(Listener.noArg, forInstance: listenerA)
        event.setFunction(Listener.noArg, forInstance: listenerB)
        event.emit()
        
        wait {
            XCTAssert(Listener.orderOfDelivery == [listenerA, listenerB])
            reset()
            
            // Test reverse order of delivery.
            event.setFunction(Listener.noArg, forInstance: listenerA) // This is supposed to put A after B
            event.emit()
            
            wait {
                XCTAssert(Listener.orderOfDelivery == [listenerB, listenerA])
                reset()
                
                // Test removal of listener.
                event.removeFunctionForInstance(listenerA)
                event.emit()
                
                wait {
                    XCTAssert(Listener.orderOfDelivery == [listenerB] && listenerA.noArgDate == nil)
                    reset()
                    
                    // Test removal of all functions
                    event.removeAllFunctions()
                    event.emit()
                    wait {
                        XCTAssert(Listener.orderOfDelivery.isEmpty && listenerA.noArgDate == nil && listenerB.noArgDate == nil)
                        reset()
                        completion()
                    }
                }
            }
        }
    }
    
    func testOneArg(completion: () -> Void) {
        let event = IZEvent<String>(synchronous: true)
        let listener = Listener()
        event.setFunction(Listener.stringArg, forInstance: listener)
        event.emit("Test")
        XCTAssert(listener.stringArgValue == "Test")
        completion()
    }
    
    func testMultipleArgs(completion: () -> Void) {
        let event = IZEvent<(str: String, int: Int)>(synchronous: false)
        let listener = Listener()
        
        event.setFunction(Listener.multiArg, forInstance: listener)
        event.emit((str: "Hello, World!", int: 3))
        wait {
            print(Listener.orderOfDelivery)
            XCTAssert(Listener.orderOfDelivery == [listener])
            XCTAssert(listener.multiArgValue != nil && listener.multiArgValue!.str == "Hello, World!" && listener.multiArgValue!.int == 3)
            completion()
        }
    }
    
    func wait(closure: () -> Void) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Float(NSEC_PER_SEC) * 0.01)), dispatch_get_main_queue(), closure)
    }
}