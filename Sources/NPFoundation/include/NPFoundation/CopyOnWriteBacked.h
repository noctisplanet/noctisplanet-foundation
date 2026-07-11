//
//  CopyOnWriteBacked.hpp
//  npfoundation
//
//  Created by Jonathan Lee on 8/9/25.
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

#ifndef NP_COPYONWRITEBACKED_H
#define NP_COPYONWRITEBACKED_H

#ifdef __cplusplus

#include <atomic>
#include <cstdint>
#include <utility>
#include <NPFoundation/Definitions.h>
#include <NPFoundation/Mixable.h>

NP_NAMESPACE_BEGIN(NP)

/// A reference to a heap element with copy-on-write value semantics.
///
/// Copying the reference is O(1) and only bumps a reference count; the element itself is shared.
/// `read()` and `operator->` hand out a const view of the shared element. `unique()` is the only
/// way to get a mutable view, and it first splits the element off into a private copy whenever it
/// is shared, so a mutation is never visible through another reference.
///
/// The reference count is atomic, so distinct CopyOnWriteBacked instances that share one element
/// may be retained and released from different threads. A single instance is not thread-safe, and
/// `unique()` is only safe against concurrent `read()` on *other* instances, which is exactly what
/// the copy-on-write split guarantees.
///
/// T must be copy-constructible.
template <typename T>
class CopyOnWriteBacked {

private:

    struct Block: Nocopy {

        T *element;

        std::atomic<uint32_t> retainCount;

        explicit Block(T *element) : element(element), retainCount(1) {

        }

        Block * retain() noexcept {
            this->retainCount.fetch_add(1, std::memory_order_relaxed);
            return this;
        }

        void release() noexcept {
            // fetch_sub returns the value *before* the decrement, so exactly one releaser observes
            // 1 and destroys the block. Reading the counter back with a second load would let two
            // threads both observe 0 and double free.
            if (this->retainCount.fetch_sub(1, std::memory_order_acq_rel) == 1) {
                delete this->element;
                delete this;
            }
        }
    };

private:

    Block *block;

public:

    /// Takes ownership of `element`, which must be a live pointer obtained from `new`.
    explicit CopyOnWriteBacked(T *element) : block(new Block(element)) {

    }

    ~CopyOnWriteBacked() {
        if (this->block != nullptr) {
            this->block->release();
        }
    }

    CopyOnWriteBacked(const CopyOnWriteBacked &other) : block(other.block->retain()) {

    }

    CopyOnWriteBacked(CopyOnWriteBacked &&other) noexcept : block(other.block) {
        other.block = nullptr;
    }

    CopyOnWriteBacked & operator=(const CopyOnWriteBacked &other) {
        if (this->block != other.block) {
            Block *retained = other.block->retain();
            if (this->block != nullptr) {
                this->block->release();
            }
            this->block = retained;
        }
        return *this;
    }

    CopyOnWriteBacked & operator=(CopyOnWriteBacked &&other) noexcept {
        if (this != &other) {
            if (this->block != nullptr) {
                this->block->release();
            }
            this->block = other.block;
            other.block = nullptr;
        }
        return *this;
    }

public:

    uint32_t retainCount() const {
        return this->block->retainCount.load(std::memory_order_relaxed);
    }

    const T * operator->() const {
        return this->block->element;
    }

    /// A const view of the shared element. Never copies.
    const T * read() const {
        return this->block->element;
    }

    /// A mutable view of the element, copying it first if it is shared with anyone else.
    T * unique() {
        if (this->retainCount() > 1) {
            Block *unshared = new Block(new T(*this->block->element));
            this->block->release();
            this->block = unshared;
        }
        return this->block->element;
    }
};

template <typename T, typename... Args>
CopyOnWriteBacked<T> CopyOnWriteMake(Args&&... args) {
    return CopyOnWriteBacked<T>(new T(std::forward<Args>(args)...));
}

NP_NAMESPACE_END

#endif /* __cplusplus */

#endif /* NP_COPYONWRITEBACKED_H */
