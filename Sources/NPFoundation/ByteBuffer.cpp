//
//  ByteBuffer.cpp
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

#include <NPFoundation/ByteBuffer.h>
#include <assert.h>
#include <cstdlib>
#include <cstring>

NP_NAMESPACE_BEGIN(NP)

/// Rounds `minimumCapacity` up to the next power of two, saturating instead of wrapping to zero
/// when the value is too large to round up.
NP_STATIC_INLINE Size nextPowerOf2ClampedToMax(Size minimumCapacity) {
    if (minimumCapacity <= 1) {
        return 1;
    }
    Size capacity = minimumCapacity - 1;

    capacity |= capacity >> 1;
    capacity |= capacity >> 2;
    capacity |= capacity >> 4;
    capacity |= capacity >> 8;
    capacity |= capacity >> 16;
    capacity |= capacity >> (sizeof(Size) * 4);
    if (capacity == SIZE_MAX) {
        return SIZE_MAX;
    }
    return capacity + 1;
}

NP_STATIC_INLINE Size minimumOf(Size lhs, Size rhs) {
    return lhs < rhs ? lhs : rhs;
}

NP_STATIC_INLINE Bytes defaultAllocate(Size len) {
    return (Bytes)::malloc(len);
}

NP_STATIC_INLINE Bytes defaultReallocate(Bytes bytes, Size len) {
    return (Bytes)::realloc(bytes, len);
}

NP_STATIC_INLINE void defaultDeallocate(Bytes bytes, Size len) {
    ::free((void *)bytes);
}

NP_STATIC_INLINE void defaultCopybytes(Bytes dst, ConstBytes source, Size len) {
    ::memmove(dst, source, len);
}

ByteBufferAllocator::ByteBufferAllocator() : allocate(defaultAllocate), reallocate(defaultReallocate), deallocate(defaultDeallocate), copybytes(defaultCopybytes) {

}

ByteBufferAllocator::ByteBufferAllocator(Allocate allocate, Reallocate reallocate, Deallocate deallocate, Copybytes copybytes) : allocate(allocate), reallocate(reallocate), deallocate(deallocate), copybytes(copybytes) {
    assert(allocate != nullptr && reallocate != nullptr && deallocate != nullptr && copybytes != nullptr);
}

ByteBuffer ByteBufferAllocator::buffer(Size capacity) const {
    return ByteBuffer(*this, capacity);
}

ByteBufferStorage::ByteBufferStorage(const ByteBufferAllocator &allocator, Size capacity) : bytes(nullptr), capacity(0), allocator(allocator) {
    Size rounded = nextPowerOf2ClampedToMax(capacity);
    Bytes allocated = this->allocator.allocate(rounded);
    if (allocated != nullptr) {
        this->bytes = allocated;
        this->capacity = rounded;
    }
}

ByteBufferStorage::ByteBufferStorage(const ByteBufferStorage &storage) : bytes(nullptr), capacity(0), allocator(storage.allocator) {
    if (storage.bytes == nullptr) {
        return;
    }
    Bytes allocated = this->allocator.allocate(storage.capacity);
    if (allocated == nullptr) {
        return;
    }
    this->allocator.copybytes(allocated, storage.bytes, storage.capacity);
    this->bytes = allocated;
    this->capacity = storage.capacity;
}

ByteBufferStorage::~ByteBufferStorage() {
    if (this->bytes != nullptr) {
        this->allocator.deallocate(this->bytes, this->capacity);
    }
}

bool ByteBufferStorage::reserve(Size minimumNeededCapacity) {
    if (this->bytes != nullptr && minimumNeededCapacity <= this->capacity) {
        return true;
    }
    Size newCapacity = nextPowerOf2ClampedToMax(minimumNeededCapacity);
    if (newCapacity < minimumNeededCapacity) {
        return false;
    }
    Bytes newBytes = this->bytes == nullptr
        ? this->allocator.allocate(newCapacity)
        : this->allocator.reallocate(this->bytes, newCapacity);
    if (newBytes == nullptr) {
        return false;
    }
    this->bytes = newBytes;
    this->capacity = newCapacity;
    return true;
}

Size ByteBufferStorage::setBytes(ConstBytes bytes, Size size, Size atIndex) {
    if (bytes == nullptr || size == 0) {
        return 0;
    }
    if (atIndex > SIZE_MAX - size) {
        return 0;
    }
    if (!this->reserve(atIndex + size)) {
        return 0;
    }
    this->allocator.copybytes(this->bytes + atIndex, bytes, size);
    return size;
}

Size ByteBufferStorage::copyBytesTo(Bytes destination, Size size, Size fromIndex) const {
    if (destination == nullptr || this->bytes == nullptr || fromIndex >= this->capacity) {
        return 0;
    }
    Size count = minimumOf(size, this->capacity - fromIndex);
    if (count == 0) {
        return 0;
    }
    this->allocator.copybytes(destination, this->bytes + fromIndex, count);
    return count;
}

ByteBuffer::ByteBuffer(const ByteBufferAllocator &allocator, Size capacity) : readerIndex(0), writerIndex(0), storage(CopyOnWriteMake<ByteBufferStorage>(allocator, capacity)) {

}

ConstBytes ByteBuffer::bytes() const {
    return this->storage.read()->getBytes();
}

Bytes ByteBuffer::mutableBytes() {
    return this->storage.unique()->getBytes();
}

ConstBytes ByteBuffer::readableBytesView() const {
    ConstBytes base = this->bytes();
    return base == nullptr ? nullptr : base + this->readerIndex;
}

Size ByteBuffer::capacity() const {
    return this->storage.read()->getCapacity();
}

Size ByteBuffer::writableBytes() const {
    Size capacity = this->capacity();
    return capacity > this->writerIndex ? capacity - this->writerIndex : 0;
}

Size ByteBuffer::readableBytes() const {
    return this->writerIndex > this->readerIndex ? this->writerIndex - this->readerIndex : 0;
}

Size ByteBuffer::writeBytes(ConstBytes bytes, Size size) {
    Size written = this->storage.unique()->setBytes(bytes, size, this->writerIndex);
    this->moveWriterIndexForwardBy(written);
    return written;
}

Size ByteBuffer::writeString(const std::string &string) {
    return this->writeBytes((ConstBytes)string.data(), string.size());
}

Size ByteBuffer::writeCString(const char * cString) {
    if (cString == nullptr) {
        return 0;
    }
    return this->writeBytes((ConstBytes)cString, ::strlen(cString));
}

Size ByteBuffer::readBytes(Bytes destination, Size size) {
    Size count = minimumOf(size, this->readableBytes());
    if (count == 0) {
        return 0;
    }
    Size read = this->storage.read()->copyBytesTo(destination, count, this->readerIndex);
    this->moveReaderIndexForwardBy(read);
    return read;
}

std::string ByteBuffer::readString(Size size) {
    Size count = minimumOf(size, this->readableBytes());
    if (count == 0) {
        return std::string();
    }
    std::string string((const char *)this->readableBytesView(), count);
    this->moveReaderIndexForwardBy(count);
    return string;
}

Size ByteBuffer::skipBytes(Size size) {
    Size count = minimumOf(size, this->readableBytes());
    this->moveReaderIndexForwardBy(count);
    return count;
}

void ByteBuffer::discardReadBytes() {
    if (this->readerIndex == 0) {
        return;
    }
    Size readable = this->readableBytes();
    if (readable > 0) {
        ByteBufferStorage *storage = this->storage.unique();
        storage->setBytes(storage->getBytes() + this->readerIndex, readable, 0);
    }
    this->readerIndex = 0;
    this->writerIndex = readable;
}

void ByteBuffer::clear() {
    this->readerIndex = 0;
    this->writerIndex = 0;
}

void ByteBuffer::moveReaderIndexTo(Size index) {
    assert(index <= this->writerIndex);
    this->readerIndex = index;
}

void ByteBuffer::moveReaderIndexForwardBy(Size offset) {
    this->moveReaderIndexTo(this->readerIndex + offset);
}

void ByteBuffer::moveWriterIndexTo(Size index) {
    assert(index <= this->capacity());
    this->writerIndex = index;
}

void ByteBuffer::moveWriterIndexForwardBy(Size offset) {
    this->moveWriterIndexTo(this->writerIndex + offset);
}

NP_NAMESPACE_END
