//
//  NPSysTests.m
//  npfoundation
//
//  Created by Jonathan Lee on 10/7/25.
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

@interface NPSysTests : XCTestCase

@property (nonatomic, strong) NSString *temporaryDirectory;
@property (nonatomic, strong) NSString *testFile;

@end

@implementation NPSysTests

- (void)setUp {
    [super setUp];
    self.temporaryDirectory = NSTemporaryDirectory();
    self.testFile = [self.temporaryDirectory stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [[NSFileManager defaultManager] removeItemAtPath:self.testFile error:nil];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:self.testFile error:nil];
    [super tearDown];
}

- (void)testOpenCreateNewFile {
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, [self.testFile UTF8String], O_CREAT | O_RDWR, 0644);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(fd >= 0);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.testFile]);
    if (fd >= 0) {
        NP::Sys::close(diag, fd);
    }
}

- (void)testOpenExistingFileForReading {
    [@"Hello, World!" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, [self.testFile UTF8String], O_RDONLY, 0);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(fd >= 0);
    if (fd >= 0) {
        NP::Sys::close(diag, fd);
    }
}

- (void)testOpenNonExistentFileWithoutCreate {
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, [self.testFile UTF8String], O_RDONLY, 0);
    XCTAssertTrue(fd < 0);
    XCTAssertTrue(diag.hasError());
    XCTAssertEqual(errno, ENOENT);
}

- (void)testOpenWithExclusiveCreate {
    [@"Hello, World!" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, [self.testFile UTF8String], O_CREAT | O_EXCL | O_RDWR, 0);
    XCTAssertTrue(fd < 0);
    XCTAssertTrue(diag.hasError());
    XCTAssertEqual(errno, EEXIST);
}

- (void)testOpenWithInvalidPath {
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, "x", O_RDONLY, 0);
    XCTAssertTrue(fd < 0);
    XCTAssertTrue(diag.hasError());
}

- (void)testMmapReadOnlySuccess {
    [@"Hello, World!" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NP::Diagnostics diag;
    size_t size = 0;
    const void *mapping = NP::Sys::mmapReadOnly(diag, [self.testFile UTF8String], &size, nullptr);
    XCTAssertNotEqual(mapping, nullptr);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(size == 13);
    XCTAssertTrue(::strncmp("Hello, World!", (char *)mapping, size) == 0);
    NP::Sys::munmap(diag, (char *)mapping, size);
    XCTAssertFalse(diag.hasError());
}

- (void)testMmapReadOnlyFailed {
    NP::Diagnostics diag;
    size_t size = 0;
    const void *mapping = NP::Sys::mmapReadOnly(diag, [self.testFile UTF8String], &size, nullptr);
    XCTAssertEqual(mapping, nullptr);
    XCTAssertTrue(diag.hasError());
}

- (void)testMmapReadOnlyOfAnEmptyFileIsAnEmptyMapping {
    [[NSFileManager defaultManager] createFileAtPath:self.testFile contents:[NSData data] attributes:nil];

    NP::Diagnostics diag;
    size_t size = 123;
    const void *mapping = NP::Sys::mmapReadOnly(diag, [self.testFile UTF8String], &size, nullptr);
    XCTAssertEqual(mapping, nullptr);
    XCTAssertEqual(size, 0);
    XCTAssertFalse(diag.hasError());
}

- (void)testWithMmapReadOnly {
    [@"Hello, World!" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NP::Diagnostics diag;
    __block bool invoked = false;
    NP::Sys::withMmapReadOnly(diag, [self.testFile UTF8String], ^(const void *mapping, size_t size, const char *realerPath) {
        invoked = true;
        XCTAssertTrue(mapping != nullptr);
        XCTAssertEqual(size, 13);
        XCTAssertTrue(::strncmp("Hello, World!", (const char *)mapping, size) == 0);
        // The resolved path must be a real NUL-terminated path, not whatever was on the stack.
        XCTAssertTrue(::strlen(realerPath) > 0);
        XCTAssertTrue(::strstr(realerPath, [self.testFile.lastPathComponent UTF8String]) != nullptr);
    });
    XCTAssertTrue(invoked);
    XCTAssertFalse(diag.hasError());
}

- (void)testWithMmapReadOnlyOfMissingFileDoesNotInvokeHandler {
    NP::Diagnostics diag;
    __block bool invoked = false;
    NP::Sys::withMmapReadOnly(diag, [self.testFile UTF8String], ^(const void *mapping, size_t size, const char *realerPath) {
        invoked = true;
    });
    XCTAssertFalse(invoked);
    XCTAssertTrue(diag.hasError());
}

/// A read-write mapping has to be shared, otherwise writes through it are private to the process
/// and the file on disk never changes.
- (void)testMmapReadWriteIsWrittenBackToTheFile {
    [@"aaaa" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NP::Diagnostics diag;
    size_t size = 0;
    void *mapping = NP::Sys::mmapReadWrite(diag, [self.testFile UTF8String], &size, nullptr);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(mapping != nullptr);
    XCTAssertEqual(size, 4);

    ::memcpy(mapping, "bbbb", 4);
    NP::Sys::munmap(diag, mapping, size);
    XCTAssertFalse(diag.hasError());

    NSString *contents = [NSString stringWithContentsOfFile:self.testFile encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects(contents, @"bbbb");
}

- (void)testMmapReadWriteCreatesAPageForANewFile {
    NP::Diagnostics diag;
    size_t size = 0;
    void *mapping = NP::Sys::mmapReadWrite(diag, [self.testFile UTF8String], &size, nullptr);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(mapping != nullptr);
    XCTAssertEqual(size, 4096);
    NP::Sys::munmap(diag, mapping, size);
}

/// realpath() has to resolve regular files, not only directories.
- (void)testRealpathOfAFile {
    [@"Hello" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NP::Diagnostics diag;
    char output[PATH_MAX] = {0};
    NP::Sys::realpath(diag, [self.testFile UTF8String], output);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(::strstr(output, [self.testFile.lastPathComponent UTF8String]) != nullptr);
}

- (void)testRealpathOfADirectory {
    NP::Diagnostics diag;
    char output[PATH_MAX] = {0};
    NP::Sys::realpath(diag, [self.temporaryDirectory UTF8String], output);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(::strlen(output) > 0);
}

- (void)testRealpathOfAMissingPath {
    NP::Diagnostics diag;
    char output[PATH_MAX] = {0};
    NP::Sys::realpath(diag, [self.testFile UTF8String], output);
    XCTAssertTrue(diag.hasError());
}

- (void)testCwd {
    NP::Diagnostics diag;
    char output[PATH_MAX] = {0};
    NP::Sys::cwd(diag, output);
    XCTAssertFalse(diag.hasError());
    XCTAssertTrue(::strlen(output) > 0);
}

- (void)testCloseReportsABadDescriptor {
    NP::Diagnostics diag;
    NP::Sys::close(diag, -1);
    XCTAssertTrue(diag.hasError());
}

- (void)testFileExistsAndDirExists {
    [@"Hello" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    XCTAssertTrue(NP::Sys::fileExists([self.testFile UTF8String]));
    XCTAssertFalse(NP::Sys::dirExists([self.testFile UTF8String]));
    XCTAssertTrue(NP::Sys::dirExists([self.temporaryDirectory UTF8String]));
    XCTAssertFalse(NP::Sys::fileExists([self.temporaryDirectory UTF8String]));
    XCTAssertFalse(NP::Sys::fileExists("/no/such/path"));
    XCTAssertFalse(NP::Sys::dirExists("/no/such/path"));
}

- (void)testTruncateAndStat {
    [@"Hello, World!" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NP::Diagnostics diag;
    NP::Sys::truncate(diag, [self.testFile UTF8String], 5);
    XCTAssertFalse(diag.hasError());

    struct stat statbuf;
    NP::Sys::stat(diag, [self.testFile UTF8String], &statbuf);
    XCTAssertFalse(diag.hasError());
    XCTAssertEqual(statbuf.st_size, 5);
}

- (void)testFtruncate {
    NP::Diagnostics diag;
    int fd = NP::Sys::open(diag, [self.testFile UTF8String], O_CREAT | O_RDWR, 0644);
    XCTAssertTrue(fd >= 0);
    NP::Sys::ftruncate(diag, fd, 128);
    XCTAssertFalse(diag.hasError());
    NP::Sys::close(diag, fd);

    struct stat statbuf;
    NP::Sys::stat(diag, [self.testFile UTF8String], &statbuf);
    XCTAssertFalse(diag.hasError());
    XCTAssertEqual(statbuf.st_size, 128);
}

- (void)testFstatat {
    [@"Hello" writeToFile:self.testFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NP::Diagnostics diag;
    int dirfd = NP::Sys::open(diag, [self.temporaryDirectory UTF8String], O_RDONLY | O_DIRECTORY, 0);
    XCTAssertTrue(dirfd >= 0);

    struct stat statbuf;
    NP::Sys::fstatat(diag, dirfd, [self.testFile.lastPathComponent UTF8String], &statbuf, 0);
    XCTAssertFalse(diag.hasError());
    XCTAssertEqual(statbuf.st_size, 5);
    NP::Sys::close(diag, dirfd);
}

@end
