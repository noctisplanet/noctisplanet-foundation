//
//  ByteBufferTests.mm
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

using namespace NP;

@interface ByteBufferTests : XCTestCase {
    ByteBufferAllocator _allocator;
}

@end

@implementation ByteBufferTests

#pragma mark - Storage

- (void)testAllocate {
    ByteBufferStorage storage{_allocator, 0};
    XCTAssertEqual(1, storage.getCapacity());
    XCTAssertTrue(storage.reserve(1024));
    XCTAssertEqual(1024, storage.getCapacity());
}

- (void)testReserveRoundsUpAndNeverShrinks {
    ByteBufferStorage storage{_allocator, 0};
    XCTAssertTrue(storage.reserve(1000));
    XCTAssertEqual(1024, storage.getCapacity());
    XCTAssertTrue(storage.reserve(8));
    XCTAssertEqual(1024, storage.getCapacity());
}

- (void)testStorageBytes {
    NP::Size atIndex = 0;
    ByteBufferStorage storage{_allocator, 0};
    {
        const char *text = "hello world!";
        storage.setBytes((ConstBytes)text, strlen(text), atIndex);
        XCTAssertEqual(16, storage.getCapacity());
        XCTAssertEqual(0, strncmp(text, (char *)storage.getBytes(), strlen(text)));
        atIndex += strlen(text);
    }
    {
        const char *text = "Hello World!";
        storage.setBytes((ConstBytes)text, strlen(text), atIndex);
        XCTAssertEqual(32, storage.getCapacity());
        XCTAssertEqual(0, strncmp(text, (char *)storage.getBytes() + atIndex, strlen(text)));
    }
}

- (void)testStorageCopyKeepsSourceIntact {
    ByteBufferStorage storage{_allocator, 16};
    const char *text = "hello world!";
    storage.setBytes((ConstBytes)text, strlen(text), 0);

    ByteBufferStorage copied{storage};
    XCTAssertNotEqual(storage.getBytes(), copied.getBytes());
    XCTAssertEqual(storage.getCapacity(), copied.getCapacity());
    XCTAssertEqual(0, strncmp(text, (char *)storage.getBytes(), strlen(text)));
    XCTAssertEqual(0, strncmp(text, (char *)copied.getBytes(), strlen(text)));
}

#pragma mark - Writing

- (void)testSimpleWrites {
    auto buffer = _allocator.buffer(1024);
    XCTAssertEqual(1024, buffer.capacity());
    XCTAssertEqual(1024, buffer.writableBytes());
    XCTAssertEqual(0, buffer.readableBytes());

    auto written = buffer.writeString(std::string(1024, 'a'));
    XCTAssertEqual(1024, written);
    XCTAssertEqual(1024, buffer.readableBytes());
    XCTAssertEqual(0, buffer.writableBytes());

    written = buffer.writeCString("");
    XCTAssertEqual(0, written);
    XCTAssertEqual(1024, buffer.readableBytes());

    written = buffer.writeCString("X");
    XCTAssertEqual(1, written);
    XCTAssertEqual(1025, buffer.readableBytes());
    XCTAssertEqual(2048, buffer.capacity());

    written = buffer.writeCString("XXXXX");
    XCTAssertEqual(5, written);
    XCTAssertEqual(1030, buffer.readableBytes());
    XCTAssertEqual(2048, buffer.capacity());
}

#pragma mark - Reading

- (void)testReadAndSkip {
    auto buffer = _allocator.buffer(0);
    buffer.writeCString("hello world!");
    XCTAssertEqual(12, buffer.readableBytes());

    XCTAssertEqual("hello", buffer.readString(5));
    XCTAssertEqual(7, buffer.readableBytes());

    XCTAssertEqual(1, buffer.skipBytes(1));
    XCTAssertEqual(6, buffer.readableBytes());

    uint8_t destination[16] = {0};
    XCTAssertEqual(6, buffer.readBytes(destination, sizeof(destination)));
    XCTAssertEqual(0, strcmp("world!", (char *)destination));
    XCTAssertEqual(0, buffer.readableBytes());
    XCTAssertEqual(0, buffer.readBytes(destination, sizeof(destination)));
}

- (void)testDiscardReadBytes {
    auto buffer = _allocator.buffer(16);
    buffer.writeCString("hello world!");
    buffer.skipBytes(6);
    XCTAssertEqual(6, buffer.getReaderIndex());

    buffer.discardReadBytes();
    XCTAssertEqual(0, buffer.getReaderIndex());
    XCTAssertEqual(6, buffer.getWriterIndex());
    XCTAssertEqual(6, buffer.readableBytes());
    XCTAssertEqual("world!", buffer.readString(6));
}

- (void)testClear {
    auto buffer = _allocator.buffer(16);
    buffer.writeCString("hello");
    buffer.clear();
    XCTAssertEqual(0, buffer.readableBytes());
    XCTAssertEqual(16, buffer.writableBytes());
}

#pragma mark - Copy on write

- (void)testCopiedBufferSharesStorageUntilWritten {
    auto buffer = _allocator.buffer(16);
    buffer.writeCString("hello");

    auto copied = buffer;
    XCTAssertEqual(buffer.bytes(), copied.bytes());

    copied.writeCString("!");
    XCTAssertNotEqual(buffer.bytes(), copied.bytes());
    XCTAssertEqual(5, buffer.readableBytes());
    XCTAssertEqual(6, copied.readableBytes());
    XCTAssertEqual("hello", buffer.readString(5));
    XCTAssertEqual("hello!", copied.readString(6));
}

@end
