//
//  NPHeapTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 10/6/25.
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

@interface NPHeapTests : XCTestCase

@end

@implementation NPHeapTests

/// A shuffled list spanning negative and positive values. Built on demand: only the heapify tests
/// need it, and the push/pop tests were paying for a million elements they never looked at.
- (std::vector<int32_t>)randomList {
    const int32_t count = 200000;
    std::vector<int32_t> list;
    list.reserve(count);
    for (int32_t idx = 0; idx < count; idx ++) {
        list.push_back((int32_t)arc4random_uniform((uint32_t)count) - count / 2);
    }
    return list;
}

- (void)testMinHeapPushAndPop {
    NP::Heap<int> heap{NP::HeapType::min};
    heap.push(10);
    heap.push(11);
    heap.push(2);
    heap.push(7);
    heap.push(20);
    heap.push(18);
    XCTAssertEqual(heap.size(), 6);
    XCTAssertEqual(heap.top(), 2);
    XCTAssertEqual(heap.pop(), 2);
    XCTAssertEqual(heap.pop(), 7);
    XCTAssertEqual(heap.pop(), 10);
    XCTAssertEqual(heap.pop(), 11);
    XCTAssertEqual(heap.pop(), 18);
    XCTAssertEqual(heap.pop(), 20);
    XCTAssertFalse(heap.pop().has_value());
    XCTAssertTrue(heap.empty());
}

- (void)testMaxHeapPushAndPop {
    NP::Heap<int> heap{NP::HeapType::max};
    heap.push(10);
    heap.push(11);
    heap.push(2);
    heap.push(7);
    heap.push(20);
    heap.push(18);
    XCTAssertEqual(heap.size(), 6);
    XCTAssertEqual(heap.top(), 20);
    XCTAssertEqual(heap.pop(), 20);
    XCTAssertEqual(heap.pop(), 18);
    XCTAssertEqual(heap.pop(), 11);
    XCTAssertEqual(heap.pop(), 10);
    XCTAssertEqual(heap.pop(), 7);
    XCTAssertEqual(heap.pop(), 2);
    XCTAssertFalse(heap.pop().has_value());
    XCTAssertTrue(heap.empty());
}

- (void)testBuildMinHeap {
    std::vector<int32_t> list = [self randomList];
    NP::Heap<int32_t> heap{list, NP::HeapType::min};
    XCTAssertEqual(heap.size(), list.size());
    int32_t cur = INT32_MIN;
    while (heap.size() > 0) {
        const auto element = heap.pop();
        XCTAssertTrue(element >= cur);
        cur = element.value();
    }
    XCTAssertEqual(heap.size(), 0);
}

- (void)testBuildMaxHeap {
    std::vector<int32_t> list = [self randomList];
    NP::Heap<int32_t> heap{list, NP::HeapType::max};
    XCTAssertEqual(heap.size(), list.size());
    int32_t cur = INT32_MAX;
    while (heap.size() > 0) {
        const auto element = heap.pop();
        XCTAssertTrue(element <= cur);
        cur = element.value();
    }
    XCTAssertEqual(heap.size(), 0);
}

- (void)testEmptyHeap {
    NP::Heap<int> heap;
    XCTAssertTrue(heap.empty());
    XCTAssertEqual(heap.size(), 0);
    XCTAssertFalse(heap.top().has_value());
    XCTAssertFalse(heap.pop().has_value());
    XCTAssertEqual(heap.getType(), NP::HeapType::max);
}

- (void)testBuildFromEmptyList {
    NP::Heap<int> heap{std::vector<int>{}, NP::HeapType::min};
    XCTAssertTrue(heap.empty());
    XCTAssertFalse(heap.pop().has_value());
}

- (void)testDuplicatesAndClear {
    NP::Heap<int> heap{std::vector<int>{4, 4, 1, 4, 1}, NP::HeapType::min};
    XCTAssertEqual(heap.pop(), 1);
    XCTAssertEqual(heap.pop(), 1);
    XCTAssertEqual(heap.pop(), 4);
    heap.clear();
    XCTAssertTrue(heap.empty());
}

/// push() must take lvalues too, not just temporaries, and must move what it is given rather than
/// copying it.
- (void)testPushMovesAndAcceptsLvalues {
    NP::Heap<std::string> heap{NP::HeapType::min};
    std::string lvalue = "b";
    heap.push(lvalue);
    XCTAssertEqual(lvalue, "b");

    std::string movable(64, 'a');
    heap.push(std::move(movable));
    XCTAssertTrue(movable.empty());

    XCTAssertEqual(heap.pop().value(), std::string(64, 'a'));
    XCTAssertEqual(heap.pop().value(), "b");
}

@end
