//
//  DiagnosticsTests.mm
//  npfoundation
//
//  Created by Jonathan Lee on 6/22/25.
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

using namespace NP;

@interface DiagnosticsTests : XCTestCase

@end

@implementation DiagnosticsTests

- (void)testDebug {
    Diagnostics diagnostics;
    diagnostics.debug("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testPrefixDebug {
    Diagnostics diagnostics{"test"};
    diagnostics.debug("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testWarning {
    Diagnostics diagnostics;
    diagnostics.warning("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testPrefixWarning {
    Diagnostics diagnostics{"test"};
    diagnostics.warning("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testError {
    Diagnostics diagnostics;
    diagnostics.error("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertTrue(diagnostics.hasError());
    XCTAssertFalse(diagnostics.noError());
    diagnostics.clearError();
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testPrefixError {
    Diagnostics diagnostics{"test"};
    diagnostics.error("%s %fs", __func__, CFAbsoluteTimeGetCurrent());
    XCTAssertTrue(diagnostics.hasError());
    XCTAssertFalse(diagnostics.noError());
    diagnostics.clearError();
    XCTAssertFalse(diagnostics.hasError());
    XCTAssertTrue(diagnostics.noError());
}

- (void)testCollectsOnlyErrorsInOrder {
    Diagnostics diagnostics;
    diagnostics.debug("a debug line");
    diagnostics.info("an info line");
    diagnostics.warning("a warning line");
    diagnostics.error("first error: %d", 1);
    diagnostics.error("second error: %d", 2);

    const auto &errors = diagnostics.getErrors();
    XCTAssertEqual(errors.size(), 2);
    XCTAssertEqual(errors[0].text, "first error: 1");
    XCTAssertEqual(errors[1].text, "second error: 2");
    XCTAssertTrue(errors[0].behavior == Diagnostics::Behavior::error);

    diagnostics.clearError();
    XCTAssertTrue(diagnostics.getErrors().empty());
}

/// Every level is echoed to the stream, with the prefix, whatever its behavior.
- (void)testWritesEveryLevelToTheStream {
    FILE *stream = ::tmpfile();
    XCTAssertTrue(stream != nullptr);
    {
        Diagnostics diagnostics{"np", stream};
        diagnostics.debug("d");
        diagnostics.warning("w");
        diagnostics.error("e");
    }
    ::rewind(stream);
    char contents[256] = {0};
    size_t read = ::fread(contents, 1, sizeof(contents) - 1, stream);
    ::fclose(stream);

    XCTAssertTrue(read > 0);
    XCTAssertEqual(std::string(contents), std::string("[np] d\n[np] w\n[np] e\n"));
}

- (void)testLongMessageIsNotTruncated {
    Diagnostics diagnostics;
    std::string long_(4096, 'x');
    diagnostics.error("%s", long_.c_str());
    XCTAssertEqual(diagnostics.getErrors().size(), 1);
    XCTAssertEqual(diagnostics.getErrors()[0].text.size(), 4096);
}

@end
