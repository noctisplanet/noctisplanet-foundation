//
//  Heap.h
//  npfoundation
//
//  Created by Jonathan Lee on 9/20/25.
//
//  MIT License
//
//  Copyright (c) 2025 Jonathan Lee
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

#ifndef NP_DATASTRUCTURES_HEAP_H
#define NP_DATASTRUCTURES_HEAP_H

#ifdef __cplusplus

#include <NPFoundation/Definitions.h>
#include <cstdint>
#include <optional>
#include <utility>
#include <vector>

NP_NAMESPACE_BEGIN(NP)

enum class HeapType {
    max, min
};

/// A binary heap over a contiguous vector.
///
/// `top()` and `pop()` yield the largest element by `operator<` for HeapType::max, and the smallest
/// for HeapType::min. Building from an existing vector heapifies it in O(n) rather than pushing
/// element by element.
///
/// T must be movable and comparable with `operator<` / `operator>`.
template<class T>
class Heap {

public:

    typedef int64_t Index;

private:

    std::vector<T> storage;

    HeapType type;

public:

    explicit Heap(HeapType type = HeapType::max) : type(type) {

    }

    explicit Heap(const std::vector<T> &list, HeapType type = HeapType::max) : storage(list), type(type) {
        this->build();
    }

    explicit Heap(std::vector<T> &&list, HeapType type = HeapType::max) : storage(std::move(list)), type(type) {
        this->build();
    }

public:

    HeapType getType() const {
        return this->type;
    }

    Index size() const {
        return (Index)storage.size();
    }

    bool empty() const {
        return storage.empty();
    }

    void clear() {
        storage.clear();
    }

    void reserve(Index capacity) {
        if (capacity > 0) {
            storage.reserve((size_t)capacity);
        }
    }

    std::optional<T> top() const {
        if (storage.empty()) {
            return std::nullopt;
        }
        return storage[0];
    }

private:

    void build() {
        Index size = this->size();
        for (Index idx = size / 2 - 1; idx >= 0; idx --) {
            heapify(idx, size);
        }
    }

    bool lessThan(Index lhs, Index rhs) const {
        return storage[lhs] < storage[rhs];
    }

    bool greaterThan(Index lhs, Index rhs) const {
        return storage[lhs] > storage[rhs];
    }

    Index parentIndex(Index idx) const {
        return (idx - 1) / 2;
    }

    Index leftIndex(Index idx) const {
        return 2 * idx + 1;
    }
    
    Index rightIndex(Index idx) const {
        return 2 * idx + 2;
    }
    
private:
    
    void swap(Index lhs, Index rhs) {
        std::swap(storage[lhs], storage[rhs]);
    }
    
    bool comparator(Index lhs, Index rhs) const {
        if (type == HeapType::min) {
            return lessThan(lhs, rhs);
        } else {
            return greaterThan(lhs, rhs);
        }
    }

    void heapify(Index idx, Index size) {
        Index left = leftIndex(idx);
        while (left < size) {
            Index next = 0;
            if (comparator(left, idx)) {
                next = left;
            } else {
                next = idx;
            }
            Index right = rightIndex(idx);
            if (right < size && comparator(right, next)) {
                next = right;
            }
            if (next != idx) {
                swap(idx, next);
                idx = next;
                left = leftIndex(idx);
            } else {
                break;
            }
        }
    }
    
    /// Restores the heap property upwards from `idx`, which is where a freshly appended element sits.
    void siftUp(Index idx) {
        while (idx > 0) {
            Index parent = parentIndex(idx);
            if (!comparator(idx, parent)) {
                break;
            }
            swap(idx, parent);
            idx = parent;
        }
    }

public:

    void push(const T &value) {
        storage.push_back(value);
        this->siftUp(this->size() - 1);
    }

    void push(T &&value) {
        storage.push_back(std::move(value));
        this->siftUp(this->size() - 1);
    }

    std::optional<T> pop() {
        Index size = this->size();
        if (size < 1) {
            return std::nullopt;
        }

        size -= 1;
        if (size > 0) {
            swap(0, size);
            heapify(0, size);
        }

        std::optional<T> value{std::move(storage[size])};
        storage.pop_back();
        return value;
    }
};

NP_NAMESPACE_END

#endif /* __cplusplus */

#endif /* NP_DATASTRUCTURES_HEAP_H */
