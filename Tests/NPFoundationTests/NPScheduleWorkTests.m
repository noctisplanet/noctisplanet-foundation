//
//  NPScheduleWorkTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 8/14/25.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import <XCTest/XCTest.h>
#import <NPFoundation/NPFoundation.h>

@interface NPScheduleWorkTests : XCTestCase

@end

@implementation NPScheduleWorkTests

/// Waits out `seconds` so that any work still in flight has a chance to run before an assertion.
- (void)settleFor:(double)seconds {
    XCTestExpectation *settled = [self expectationWithDescription:@"settled"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settled fulfill];
    });
    [self waitForExpectations:@[settled] timeout:seconds + 5];
}

#pragma mark - Throttle

- (void)testThrottleFiresOncePerWindow {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"throttled"];
    NPScheduleWorkRef work = NPDispatchScheduleThrottle(1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });

    NPScheduleWorkResume(work);
    NPScheduleWorkResume(work);
    NPScheduleWorkResume(work);
    NPScheduleWorkResume(work);
    [self waitForExpectations:@[expectation] timeout:5];

    // The window is still open, so the burst above must have produced exactly one call.
    XCTAssertEqual(count, 1);
    NPScheduleWorkRelease(work);
}

- (void)testThrottleFiresAgainAfterTheWindow {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"throttled twice"];
    expectation.expectedFulfillmentCount = 2;
    NPScheduleWorkRef work = NPDispatchScheduleThrottle(0.2, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });

    NPScheduleWorkResume(work);
    NPScheduleWorkResume(work);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NPScheduleWorkResume(work);
    });
    [self waitForExpectations:@[expectation] timeout:5];
    XCTAssertEqual(count, 2);
    NPScheduleWorkRelease(work);
}

#pragma mark - Debounce

- (void)testDebounceFiresOnceForABurst {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"debounced"];
    NPScheduleWorkRef work = NPDispatchScheduleDebounce(0.2, 0.05, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });

    for (int idx = 0; idx < 8; idx ++) {
        NPScheduleWorkResume(work);
    }
    [self waitForExpectations:@[expectation] timeout:5];

    // A debounce must collapse the whole burst into a single call, so give any stray timer from the
    // burst a chance to fire before checking the count.
    [self settleFor:0.5];
    XCTAssertEqual(count, 1);
    NPScheduleWorkRelease(work);
}

- (void)testDebounceCancel {
    NP_BLOCK(int) count = 0;
    NPScheduleWorkRef work = NPDispatchScheduleDebounce(0.2, 0, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
    });

    NPScheduleWorkResume(work);
    NPScheduleWorkCancel(work);
    [self settleFor:0.6];
    XCTAssertEqual(count, 0);
    NPScheduleWorkRelease(work);
}

- (void)testDebounceResumesAfterCancel {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"debounced"];
    NPScheduleWorkRef work = NPDispatchScheduleDebounce(0.2, 0, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });

    NPScheduleWorkResume(work);
    NPScheduleWorkCancel(work);
    NPScheduleWorkResume(work);
    [self waitForExpectations:@[expectation] timeout:5];
    XCTAssertEqual(count, 1);
    NPScheduleWorkRelease(work);
}

#pragma mark - Lifetime

- (void)testTheHandleIsUsable {
    NPScheduleWorkRef work = NPDispatchScheduleThrottle(1, dispatch_get_main_queue(), ^{});
    XCTAssertTrue(work != NULL);
    NPScheduleWorkRelease(work);

    // A NULL handle is inert rather than a crash, whichever way it is used.
    NPScheduleWorkResume(NULL);
    NPScheduleWorkCancel(NULL);
    NPScheduleWorkRelease(NULL);
}

/// The callback must stay alive as long as the handle does, even after the frame that created it
/// has returned.
- (void)testHandleOutlivesTheSchedulingFrame {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"throttled"];
    NPScheduleWorkRef work = [self scheduleWithCounter:&count expectation:expectation];

    NPScheduleWorkResume(work);
    [self waitForExpectations:@[expectation] timeout:5];
    XCTAssertEqual(count, 1);
    NPScheduleWorkRelease(work);
}

- (NPScheduleWorkRef)scheduleWithCounter:(int *)counter expectation:(XCTestExpectation *)expectation {
    return NPDispatchScheduleThrottle(1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        *counter += 1;
        [expectation fulfill];
    });
}

@end
