// 
// 


import XCTest
import WireCryptobox

class EncryptionContextTests: XCTestCase {

    /// This test verifies that the critical section (in usingSessions)
    /// can not be entered at the same time on two different EncryptionContext
    func testThatItBlockWhileUsingSessionsOnTwoDifferentObjects() {
        
        // GIVEN
        let tempDir = createTempFolder()
        
        // have to do work on other queues because the main thread can't be blocked
        let queue1 = DispatchQueue(label: self.name)
        let queue2 = DispatchQueue(label: self.name)
        
        // coordinate between the two threads to make sure that they are executed in the right order
        let context2CanEnterSemaphore = DispatchSemaphore(value: 0)
        let context1CanCompleteSemaphore = DispatchSemaphore(value: 0)
        let queue2IsDoneSemaphore = DispatchSemaphore(value: 0)
        
        // whether the queues entered the critical section
        var queue1EnteredCriticalSection = false
        var queue1LeftCriticalSection = false
        var queue2EnteredCriticalSection = false
        var queue2LeftCriticalSection = false
        
        // WHEN
        
        // queue 1 will enter critical section and wait there until told to complete
        queue1.async {

            // entering the critical section
            EncryptionContext(path: tempDir).perform { _ in
                queue1EnteredCriticalSection = true
                // signal queue2 other thread that it should attempt to enter critical section
                context2CanEnterSemaphore.signal()
                // wait until it's told to leave critical section
                context1CanCompleteSemaphore.wait()
            }
            queue1LeftCriticalSection = true
        }
        
        // queue 2 will try to enter critical section, but should block (because of queue 1)
        queue2.async {
            
            // make sure queue 1 is in the right place (critical section) before attempting to enter critical section
            context2CanEnterSemaphore.wait()
            EncryptionContext(path: tempDir).perform { _ in
                // will not get here until queue1 has quit critical section
                queue2EnteredCriticalSection = true
            }
            queue2LeftCriticalSection = true
            queue2IsDoneSemaphore.signal()
        }
        
        // wait a few ms so that all threads are ready
        Thread.sleep(forTimeInterval: 0.3)
        
        // THEN
        XCTAssertTrue(queue1EnteredCriticalSection)
        XCTAssertFalse(queue1LeftCriticalSection)
        XCTAssertFalse(queue2EnteredCriticalSection)
        XCTAssertFalse(queue2LeftCriticalSection)
        
        // WHEN
        context1CanCompleteSemaphore.signal()
        
        // THEN
        queue2IsDoneSemaphore.wait()
        XCTAssertTrue(queue1EnteredCriticalSection)
        XCTAssertTrue(queue1LeftCriticalSection)
        XCTAssertTrue(queue2EnteredCriticalSection)
        XCTAssertTrue(queue2LeftCriticalSection)
    }

    func testThatItDoesNotBlockWhileUsingSessionsMultipleTimesOnTheSameObject() {
        
        // GIVEN
        let tempDir = createTempFolder()
        
        let mainContext = EncryptionContext(path: tempDir)
        let invocation1 = self.expectation(description: "first begin using session")
        let invocation2 = self.expectation(description: "second begin using session")

        
        // WHEN
        // enter critical section
        mainContext.perform { _ in
            invocation1.fulfill()
            
            // enter again
            mainContext.perform { _ in
                invocation2.fulfill()
            }
        }
        
        // THEN
        self.waitForExpectations(timeout: 0) { _ in }

    }
    
    func testThatItReceivesTheSameSessionStatusWithNestedPerform() {
        
        // GIVEN
        let tempDir = createTempFolder()
        
        let mainContext = EncryptionContext(path: tempDir)
        var lastStatus : EncryptionSessionsDirectory? = nil
 
        let invocation1 = self.expectation(description: "first begin using session")
        let invocation2 = self.expectation(description: "second begin using session")
        
        // WHEN
        
        // enter critical section
        mainContext.perform { context1 in
            lastStatus = context1
            invocation1.fulfill()
        
            mainContext.perform { context2 in
                XCTAssertTrue(lastStatus === context2)
                invocation2.fulfill()
            }
        }
        
        // THEN
        self.waitForExpectations(timeout: 0) { _ in }
    }
    
    func testThatItSafelyEncryptDecryptDuringNestedPerform() {
        
        // GIVEN
        let tempDir = createTempFolder()
        
        let mainContext = EncryptionContext(path: tempDir)
        
        let someTextToEncrypt = "ENCRYPT THIS!"
        
        // WHEN
        
        // enter critical section
        mainContext.perform { (context1 : EncryptionSessionsDirectory) in
            
            try! context1.createClientSession(hardcodedClientId, base64PreKeyString: hardcodedPrekey)
            
            mainContext.perform { (context2 : EncryptionSessionsDirectory) in
                _ = try! context2.encrypt(someTextToEncrypt.data(using: String.Encoding.utf8)!, for: hardcodedClientId)
                
            }
            
            _ = try! context1.encrypt(someTextToEncrypt.data(using: String.Encoding.utf8)!, for: hardcodedClientId)
        }
        
        // THEN 
        // it didn't crash
    }

    
    func testThatItDoesNotReceivesTheSameSessionStatusIfDonePerforming() {
        
        // GIVEN
        let tempDir = createTempFolder()
        
        let mainContext = EncryptionContext(path: tempDir)
        var lastStatus : EncryptionSessionsDirectory? = nil
        
        let invocation1 = self.expectation(description: "first begin using session")
        let invocation2 = self.expectation(description: "second begin using session")
        
        // WHEN
        
        // enter critical section
        mainContext.perform { context in
            lastStatus = context
            invocation1.fulfill()
        }
        
        // THEN
        // enter again
        mainContext.perform { context in
            invocation2.fulfill()
            XCTAssertFalse(lastStatus === context)
        }
        
        self.waitForExpectations(timeout: 0) { _ in }
    }
}
