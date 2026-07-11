//
//  NPScheduleWorkTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 9/17/25.
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

- (void)testThrottleFiresOncePerWindow {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"throttled"];
    NPScheduleWork scheduleWork = NPDispatchScheduleThrottle(1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });
    scheduleWork.resume();
    scheduleWork.resume();
    scheduleWork.resume();
    scheduleWork.resume();
    [self waitForExpectations:@[expectation] timeout:5];

    // The window is still open, so the burst above must have produced exactly one call.
    XCTAssertEqual(count, 1);
}

- (void)testThrottleFiresAgainAfterTheWindow {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"throttled twice"];
    expectation.expectedFulfillmentCount = 2;
    NPScheduleWork scheduleWork = NPDispatchScheduleThrottle(0.2, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });
    scheduleWork.resume();
    scheduleWork.resume();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        scheduleWork.resume();
    });
    [self waitForExpectations:@[expectation] timeout:5];
    XCTAssertEqual(count, 2);
}

- (void)testDebounceFiresOnceForABurst {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"debounced"];
    NPScheduleWork scheduleWork = NPDispatchScheduleDeboundce(0.2, 0.05, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
        [expectation fulfill];
    });
    for (int idx = 0; idx < 8; idx ++) {
        scheduleWork.resume();
    }
    [self waitForExpectations:@[expectation] timeout:5];

    // Give any stray timer from the burst a chance to fire before checking the count: a debounce
    // must collapse the whole burst into a single call.
    XCTestExpectation *settled = [self expectationWithDescription:@"settled"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settled fulfill];
    });
    [self waitForExpectations:@[settled] timeout:5];
    XCTAssertEqual(count, 1);
}

- (void)testDebounceCancel {
    NP_BLOCK(int) count = 0;
    NPScheduleWork scheduleWork = NPDispatchScheduleDeboundce(0.2, 0, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        count += 1;
    });
    scheduleWork.resume();
    scheduleWork.cancel();

    XCTestExpectation *settled = [self expectationWithDescription:@"settled"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settled fulfill];
    });
    [self waitForExpectations:@[settled] timeout:5];
    XCTAssertEqual(count, 0);
}

@end
