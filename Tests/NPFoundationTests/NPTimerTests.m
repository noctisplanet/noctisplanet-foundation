//
//  NPTimerTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 8/20/25.
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

@interface NPTimerTests : XCTestCase

@end

@implementation NPTimerTests

- (void)testCancelWhileSuspended {
    // Cancelling a suspended source leaves it suspended forever unless the suspend is balanced, so
    // the source is never reclaimed and its event handler is never released. The released handler
    // is what this observes.
    XCTestExpectation *released = [self expectationWithDescription:@"handler released"];
    NSObject *sentinel = [NSObject new];
    NPAttachDeallocationHandler(sentinel, ^{
        [released fulfill];
    });

    @autoreleasepool {
        NPTimer timer = NPDispatchTimer(nil, 60, 0, ^{
            (void)sentinel;
        });
        NPDispatchTimerSuspend(timer);
        NPDispatchTimerCancel(timer);
        timer = nil;
    }
    sentinel = nil;

    [self waitForExpectations:@[released] timeout:5];
}

- (void)testCancelStopsTheTimer {
    NP_BLOCK(int) count = 0;
    NPTimer timer = NPDispatchTimer(nil, 0.1, 0, ^{
        count += 1;
    });
    NPDispatchTimerCancel(timer);

    XCTestExpectation *settled = [self expectationWithDescription:@"settled"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settled fulfill];
    });
    [self waitForExpectations:@[settled] timeout:5];

    // The timer fires once immediately on activation, then must stop.
    XCTAssertLessThanOrEqual(count, 1);
}

- (void)testCreate {
    XCTAssertNotNil(NPDispatchTimer(nil, 0, 0, ^{}));
    XCTAssertNotNil(NPDispatchTimer(nil, 0, 0, ^{}));
    XCTAssertNotNil(NPDispatchTimer(nil, 1, 0, ^{}));
    XCTAssertNotNil(NPDispatchTimer(nil, 0, 1, ^{}));
}

- (void)testTimerOperation  {
    NPTimer timer = NPDispatchTimer(nil, 0.5, 0, ^{ });
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerCancel(timer);
    NPDispatchTimerCancel(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerSuspend(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerResume(timer);
    NPDispatchTimerCancel(timer);
}

- (void)testTimerRun {
    NP_BLOCK(int) count = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"TIME_FOREVER"];
    NPTimer timer = NPDispatchTimer(nil, 0.5, 0, ^{
        count += 1;
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:2];
    XCTAssertTrue(count > 0);
}

- (void)testObservable {
    NP_BLOCK(int) count1 = 0;
    NP_BLOCK(int) count2 = 0;
    XCTestExpectation *expectation = [self expectationWithDescription:@"TIME_FOREVER"];
    dispatch_queue_t queue = dispatch_queue_create("", DISPATCH_QUEUE_SERIAL);
    {
        __block NSObject *value = [NSObject new];
        NPDispatchTimerObservable(value, nil, 1, 0, ^{
            count1 += 1;
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), queue, ^{
            id strong = value;
            value = strong;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), queue, ^{
                count2 = count1;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), queue, ^{
                    [expectation fulfill];
                });
            });
        });
    }
    [self waitForExpectations:@[expectation] timeout:5];
    XCTAssertTrue(count1 > 0);
    XCTAssertEqual(count1, count2);
}

@end
