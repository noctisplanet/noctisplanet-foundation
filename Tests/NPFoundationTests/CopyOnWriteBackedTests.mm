//
//  CopyOnWriteBackedTests.mm
//  npfoundation
//
//  Created by Jonathan Lee on 10/27/25.
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

struct DataSources {
    
    DataSources() {
        
    }
    
    DataSources(DataSources &ds) {
        
    }
    
    ~DataSources() {
        
    }
    
    void ctest() const {
        
    }
  
    void test() {
        
    }
};

using namespace NP;

@interface CopyOnWriteBackedTests : XCTestCase

@end

@implementation CopyOnWriteBackedTests

- (void)testMake {
    const auto cow = CopyOnWriteMake<DataSources>();
    XCTAssertTrue(cow.read() != nullptr);
}

- (void)testRead {
    const auto cow1 = CopyOnWriteMake<DataSources>();
    const auto cow2 = cow1;
    XCTAssertTrue(cow1.read() == cow2.read());
    XCTAssertTrue(cow1.retainCount() == 2);
    XCTAssertTrue(cow2.retainCount() == 2);
}

- (void)testWrite {
    auto cow1 = CopyOnWriteMake<DataSources>();
    auto cow2 = cow1;
    XCTAssertTrue(cow1.read() == cow2.read());
    XCTAssertTrue(cow1.retainCount() == 2);
    XCTAssertTrue(cow2.retainCount() == 2);
    cow1.unique()->ctest();
    XCTAssertTrue(cow1.retainCount() == 1);
    cow2.unique()->test();
    XCTAssertTrue(cow2.retainCount() == 1);
}

@end
