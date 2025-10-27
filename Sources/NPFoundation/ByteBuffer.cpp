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
#include <NPFoundation/sys.h>
#include <malloc/malloc.h>

NP_NAMESPACE_BEGIN(NP)

NP_STATIC_INLINE Size nextPowerOf2ClampedToMax(Size minimumCapacity) {
    if (minimumCapacity <= 0) {
        return 1;
    }
    Size capacity = minimumCapacity;
    
    capacity -= 1;
    capacity |= capacity >> 1;
    capacity |= capacity >> 2;
    capacity |= capacity >> 4;
    capacity |= capacity >> 8;
    capacity |= capacity >> 16;
    if (capacity != UINT32_MAX) {
        return capacity += 1;
    }
    return capacity;
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

NP_STATIC_INLINE void defaultCopybytes(Bytes dst, const Bytes source, Size len) {
    ::memmove(dst, source, len);
}

ByteBufferAllocator::ByteBufferAllocator() : allocate(defaultAllocate), reallocate(defaultReallocate), deallocate(defaultDeallocate), copybytes(defaultCopybytes) {
    
}

ByteBufferAllocator::ByteBufferAllocator(Allocate allocate, Reallocate reallocate, Deallocate deallocate, Copybytes copybytes) : allocate(allocate), reallocate(reallocate), deallocate(deallocate), copybytes(copybytes) {
    
}

ByteBuffer ByteBufferAllocator::buffer(uint32_t capacity) const {
    return ByteBuffer(*this, capacity);
}

ByteBufferStorage::ByteBufferStorage(ByteBufferAllocator allocator, Size capacity) : allocator(allocator) {
    this->capacity = nextPowerOf2ClampedToMax(capacity);
    this->bytes = this->allocator.allocate(this->capacity);
}

ByteBufferStorage::ByteBufferStorage(const ByteBufferStorage &storage) : allocator(storage.allocator) {
    this->capacity = storage.capacity;
    this->bytes = this->allocator.allocate(storage.capacity);
    this->allocator.copybytes(storage.bytes, this->bytes, this->capacity);
}

ByteBufferStorage::~ByteBufferStorage() {
    this->allocator.deallocate(this->bytes, this->capacity);
}

void ByteBufferStorage::reallocated(Size minimumNeededCapacity) {
    this->capacity = nextPowerOf2ClampedToMax(minimumNeededCapacity);
    Bytes newBytes = this->allocator.reallocate(this->bytes, this->capacity);
    if (newBytes) {
        this->bytes = newBytes;
    }
}

Size ByteBufferStorage::setBytes(const Bytes bytes, Size size, Size atIndex) {
    if (size <= 0) {
        return 0;
    }
    Size bytesCount = size;
    Size newEndIndex = atIndex + bytesCount;
    if (newEndIndex > this->capacity) {
        this->reallocated(newEndIndex);
    }
    this->allocator.copybytes(this->bytes + atIndex, bytes, size);
    return size;
}

ByteBuffer::ByteBuffer(ByteBufferAllocator allocator, Size capacity) : storage(CopyOnWriteMake<ByteBufferStorage>(allocator, capacity)), readerIndex(0), writerIndex(0) {
    
}

Bytes ByteBuffer::bytes() const {
    return this->storage->getBytes();
}

Size ByteBuffer::capacity() const {
    return this->storage->getCapacity();
}

Size ByteBuffer::writableBytes() const {
    if (this->capacity() > this->writerIndex) {
        return this->capacity() - this->writerIndex;
    } else {
        return 0;
    }
}

Size ByteBuffer::readableBytes() const {
    if (this->writerIndex > this->readerIndex) {
        return this->writerIndex - this->readerIndex;
    } else {
        return 0;
    }
}

Size ByteBuffer::writeBytes(const Bytes bytes, Size size) {
    Size written = this->storage.unique()->setBytes(bytes, size, this->writerIndex);
    this->moveWriterIndexForwardBy(written);
    return written;
}

Size ByteBuffer::writeString(const std::string &string) {
    return this->writeBytes((Bytes)string.data(), string.size());
}

Size ByteBuffer::writeCString(const char * cString) {
    return this->writeBytes((Bytes)cString, strlen(cString));
}

NP_NAMESPACE_END
