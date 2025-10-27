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
#include <NPFoundation/Diagnostics.h>
#include <assert.h>

NP_NAMESPACE_BEGIN(NP)

class ByteBufferAllocator;
class ByteBufferStorage;
class ByteBuffer;

typedef size_t Size;
typedef uint8_t * Bytes;

using ByteBufferStorageBacked = CopyOnWriteBacked<ByteBufferStorage>;

class ByteBufferAllocator {
    
public:
    
    typedef Bytes (*Allocate)(Size);
    typedef Bytes (*Reallocate)(Bytes, Size);
    typedef void (*Deallocate)(Bytes, Size);
    typedef void (*Copybytes)(Bytes, const Bytes, Size);
    
public:
    
    const Allocate allocate;
    const Reallocate reallocate;
    const Deallocate deallocate;
    const Copybytes copybytes;
    
public:
    
    ByteBufferAllocator();
    
    ByteBufferAllocator(Allocate allocate, Reallocate reallocate, Deallocate deallocate, Copybytes copybytes);
    
    ByteBuffer buffer(uint32_t capacity) const;
    
};

class ByteBufferStorage {
        
private:
    
    Bytes bytes;
    Size capacity;
    ByteBufferAllocator allocator;
    
public:
    
    ByteBufferStorage(ByteBufferAllocator allocator, Size capacity);
    
    ByteBufferStorage(const ByteBufferStorage &storage);
    
    ~ByteBufferStorage();
    
public:
    
    void reallocated(Size minimumNeededCapacity);

public:
    
    Bytes getBytes() const {
        return bytes;
    }
    
    Size getCapacity() const {
        return capacity;
    }
    
    Size setBytes(const Bytes bytes, Size size, Size atIndex);
};

class ByteBuffer {
    
private:
    
    Size readerIndex;
    Size writerIndex;
    ByteBufferStorageBacked storage;
    
public:
    
    ByteBuffer(ByteBufferAllocator allocator, Size capacity);
    
public:
    
    Bytes bytes() const;
    
    Size capacity() const;
    
    Size writableBytes() const;
    
    Size readableBytes() const;
    
private:
    
    void moveReaderIndexTo(Size index) {
        assert(index >= 0 && index <= this->writerIndex);
        this->readerIndex = index;
    }

    void moveReaderIndexForwardBy(Size offset) {
        this->moveReaderIndexTo(this->readerIndex + offset);
    }

    void moveWriterIndexTo(Size index) {
        assert(index >= 0 && index <= this->capacity());
        this->writerIndex = index;
    }

    void moveWriterIndexForwardBy(Size offset) {
        this->moveWriterIndexTo(this->writerIndex + offset);
    }
    
public:
        
    Size writeBytes(const Bytes bytes, Size size);
    
    Size writeString(const std::string &string);
    
    Size writeCString(const char * cString);

};

NP_NAMESPACE_END

#endif /* __cplusplus */

#endif /* NP_BYTEBUFFER_H */
