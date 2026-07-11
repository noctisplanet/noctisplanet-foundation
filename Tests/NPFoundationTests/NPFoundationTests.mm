//
//  NPFoundationTests.mm
//  npfoundation
//
//  Created by Jonathan Lee on 5/6/25.
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

@interface NPFoundationTests : XCTestCase

@end

@implementation NPFoundationTests

/// A smoke test over the umbrella header: every module has to be reachable through
/// <NPFoundation/NPFoundation.h> alone, from a single Objective-C++ translation unit.
- (void)testUmbrellaHeaderExposesEveryModule {
    NP::Diagnostics diagnostics;
    XCTAssertTrue(diagnostics.noError());

    NP::ByteBufferAllocator allocator;
    NP::ByteBuffer buffer = allocator.buffer(16);
    XCTAssertEqual(buffer.writeCString("np"), 2);

    auto backed = NP::CopyOnWriteMake<std::string>("np");
    XCTAssertEqual(*backed.read(), "np");

    NP::Heap<int> heap{NP::HeapType::min};
    heap.push(1);
    XCTAssertEqual(heap.top(), 1);

    XCTAssertTrue(NP::Sys::dirExists("/"));

    struct NPMachineContext context;
    XCTAssertTrue(NPMachineContextGet(&context, pthread_self()));
    XCTAssertTrue(NPMachineContextGetInstructionAddress(&context) != 0);

    NPTimer timer = NPDispatchTimer(nil, 60, 0, ^{});
    XCTAssertNotNil(timer);
    NPDispatchTimerCancel(timer);
}

@end
