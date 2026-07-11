//
//  ByteBuffer.h
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

#ifndef NP_BYTEBUFFER_H
#define NP_BYTEBUFFER_H

#ifdef __cplusplus

#include <NPFoundation/CopyOnWriteBacked.h>
#include <NPFoundation/Definitions.h>
#include <cstddef>
#include <cstdint>
#include <string>

NP_NAMESPACE_BEGIN(NP)

class ByteBuffer;
class ByteBufferStorage;

typedef size_t Size;
typedef uint8_t * Bytes;
typedef const uint8_t * ConstBytes;

using ByteBufferStorageBacked = CopyOnWriteBacked<ByteBufferStorage>;

/// The set of primitives a ByteBuffer uses to manage its memory.
///
/// The default allocator is backed by malloc / realloc / free / memmove. Supplying a custom
/// allocator lets a buffer live in an arena, a pool, or shared memory. All four hooks must be
/// non-null and consistent with each other: memory handed out by `allocate` or `reallocate`
/// must be releasable by `deallocate`.
///
/// `allocate` and `reallocate` are allowed to fail by returning nullptr; the buffer treats that
/// as "no space" and reports a short write rather than trapping.
class ByteBufferAllocator {

public:

    typedef Bytes (*Allocate)(Size);
    typedef Bytes (*Reallocate)(Bytes, Size);
    typedef void (*Deallocate)(Bytes, Size);
    typedef void (*Copybytes)(Bytes, ConstBytes, Size);

public:

    Allocate allocate;
    Reallocate reallocate;
    Deallocate deallocate;
    Copybytes copybytes;

public:

    ByteBufferAllocator();

    ByteBufferAllocator(Allocate allocate, Reallocate reallocate, Deallocate deallocate, Copybytes copybytes);

public:

    /// Creates a buffer whose storage is owned by this allocator.
    ByteBuffer buffer(Size capacity) const;

};

/// The heap block behind a ByteBuffer.
///
/// Storage is value-semantic and is shared between buffers through CopyOnWriteBacked; a deep copy
/// only happens when a shared buffer is about to be mutated. Capacity is always rounded up to a
/// power of two.
class ByteBufferStorage {

private:

    Bytes bytes;
    Size capacity;
    ByteBufferAllocator allocator;

public:

    ByteBufferStorage(const ByteBufferAllocator &allocator, Size capacity);

    ByteBufferStorage(const ByteBufferStorage &storage);

    ByteBufferStorage & operator=(const ByteBufferStorage &storage) = delete;

    ~ByteBufferStorage();

public:

    /// Grows the block so that it holds at least `minimumNeededCapacity` bytes, rounded up to a
    /// power of two. Never shrinks. Returns false if the allocator could not satisfy the request,
    /// in which case the block is left untouched and remains usable.
    bool reserve(Size minimumNeededCapacity);

    /// Copies `size` bytes into the block at `atIndex`, growing it if needed.
    /// Returns the number of bytes written: `size` on success, 0 if the growth failed.
    /// The source range may overlap the block.
    Size setBytes(ConstBytes bytes, Size size, Size atIndex);

    /// Copies `size` bytes out of the block, starting at `fromIndex`, into `destination`.
    /// Returns the number of bytes copied, clamped to what the block actually holds.
    Size copyBytesTo(Bytes destination, Size size, Size fromIndex) const;

public:

    Bytes getBytes() const {
        return this->bytes;
    }

    Size getCapacity() const {
        return this->capacity;
    }

};

/// A growable byte buffer with independent reader and writer cursors.
///
///     0        readerIndex        writerIndex        capacity
///     +-------------+------------------+----------------+
///     | discardable |     readable     |    writable    |
///     +-------------+------------------+----------------+
///
/// Copying a ByteBuffer is cheap: the two buffers share one storage block until either of them
/// writes, at which point the writer takes a private copy. Reads never copy.
///
/// A ByteBuffer is not thread-safe. Two buffers sharing a storage block may be used from different
/// threads, but a single buffer must not be.
class ByteBuffer {

private:

    Size readerIndex;
    Size writerIndex;
    ByteBufferStorageBacked storage;

public:

    explicit ByteBuffer(const ByteBufferAllocator &allocator, Size capacity);

public:

    /// A read-only view of the whole block. Invalidated by any write.
    ConstBytes bytes() const;

    /// A writable view of the whole block; takes a private copy first if the storage is shared.
    Bytes mutableBytes();

    /// A read-only view of the readable region, i.e. `bytes() + readerIndex`.
    ConstBytes readableBytesView() const;

    Size capacity() const;

    /// Bytes that can be written before the buffer has to grow. Writes past this point still
    /// succeed; the buffer reallocates.
    Size writableBytes() const;

    /// Bytes between the reader and the writer cursor.
    Size readableBytes() const;

    Size getReaderIndex() const {
        return this->readerIndex;
    }

    Size getWriterIndex() const {
        return this->writerIndex;
    }

public:

    /// Appends `size` bytes at the writer cursor, growing the buffer if needed.
    /// Returns the number of bytes written, which is 0 if allocation failed.
    Size writeBytes(ConstBytes bytes, Size size);

    Size writeString(const std::string &string);

    /// Writes the characters of `cString`, excluding the terminating NUL.
    Size writeCString(const char * cString);

public:

    /// Copies up to `size` readable bytes into `destination` and advances the reader cursor by the
    /// amount actually copied. Returns that amount, which is min(size, readableBytes()).
    Size readBytes(Bytes destination, Size size);

    /// Consumes up to `size` readable bytes and returns them as a string.
    std::string readString(Size size);

    /// Advances the reader cursor without copying. Returns the number of bytes skipped.
    Size skipBytes(Size size);

    /// Drops the already-read prefix by moving the readable region to the front of the block, so
    /// the discardable region becomes writable again. Does not reallocate.
    void discardReadBytes();

    /// Resets both cursors. Does not touch the storage.
    void clear();

private:

    void moveReaderIndexTo(Size index);

    void moveReaderIndexForwardBy(Size offset);

    void moveWriterIndexTo(Size index);

    void moveWriterIndexForwardBy(Size offset);

};

NP_NAMESPACE_END

#endif /* __cplusplus */

#endif /* NP_BYTEBUFFER_H */
