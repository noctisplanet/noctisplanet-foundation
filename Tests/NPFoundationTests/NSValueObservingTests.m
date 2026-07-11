//
//  NSValueObservingTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 8/19/25.
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

@interface NSValueObservingTests : XCTestCase

@end

@implementation NSValueObservingTests

- (void)testAttachDeallocationHandler {
    __block bool success = false;
    {
        NSObject *observable = [NSObject new];
        NPAttachDeallocationHandler(observable, ^{
            success = true;
        });
    }
    XCTAssertTrue(success);
}

/// The handler must survive the frame that attached it: the block literal starts out on the stack,
/// so it has to be copied to the heap when it is stored.
- (void)testHandlerOutlivesTheAttachingFrame {
    __block bool success = false;
    NSObject *observable = [NSObject new];
    [self attachTo:observable flag:&success];

    XCTAssertFalse(success);
    observable = nil;
    XCTAssertTrue(success);
}

- (void)attachTo:(NSObject *)observable flag:(bool *)flag {
    char padding[256];
    memset(padding, 0xAB, sizeof(padding));
    NPAttachDeallocationHandler(observable, ^{
        *flag = true;
    });
    (void)padding;
}

- (void)testMultipleHandlers {
    __block int count = 0;
    {
        NSObject *observable = [NSObject new];
        NPAttachDeallocationHandler(observable, ^{ count += 1; });
        NPAttachDeallocationHandler(observable, ^{ count += 1; });
        NPAttachDeallocationHandler(observable, ^{ count += 1; });
    }
    XCTAssertEqual(count, 3);
}

@end
