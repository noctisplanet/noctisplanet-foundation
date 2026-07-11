NPFoundation
===

A small foundation library for Apple platforms: C, C++ and Objective-C building blocks that sit
below application code — byte buffers, copy-on-write value semantics, diagnostics, thin `syscall`
wrappers, GCD scheduling helpers, and Objective-C runtime surgery.

Everything is exposed through a single umbrella header:

```C++
#import <NPFoundation/NPFoundation.h>
```

Individual modules can also be imported on their own, e.g. `#include <NPFoundation/ByteBuffer.h>`.
C++ APIs live in the `NP` namespace and require C++20; C and Objective-C APIs are prefixed with
`NP`.

# Installation

## Swift Package Manager
```Swift
dependencies: [
    .package(url: "https://github.com/noctisplanet/npfoundation.git", branch: "main")
]
```

## CocoaPods
```Ruby
pod 'NPFoundation', :git => 'https://github.com/noctisplanet/npfoundation.git'
```

# Modules

| Header | What it gives you |
| --- | --- |
| `ByteBuffer.h` | Growable byte buffer with reader/writer cursors and copy-on-write storage |
| `CopyOnWriteBacked.h` | Copy-on-write reference wrapper for any copy-constructible type |
| `Diagnostics.h` | Collectable, leveled diagnostic messages |
| `DataStructures/Heap.h` | Binary heap (min or max) |
| `sys.h` | `errno`-to-diagnostic wrappers around POSIX file and mmap calls |
| `dispatch/timer.h` | GCD timers, optionally bound to an object's lifetime |
| `dispatch/schedule.h` | Throttle and debounce on a dispatch queue |
| `objc/NSObjCRuntime.h` | Add, replace and override Objective-C methods |
| `objc/NSValueObserving.h` | Run a block when an object is deallocated |
| `machine/MachineContext.h` | Capture the register state of a thread |
| `Mixable.h` | Mix-ins, currently `Nocopy` |

# ByteBuffer

A growable byte buffer with independent reader and writer cursors:

```
0        readerIndex        writerIndex        capacity
+-------------+------------------+----------------+
| discardable |     readable     |    writable    |
+-------------+------------------+----------------+
```

Writes append at the writer cursor and grow the storage as needed — capacity is always a power of
two. Reads consume from the reader cursor. Every call reports how many bytes it actually moved, so
a failed allocation shows up as a short write instead of a trap.

```C++
using namespace NP;

ByteBufferAllocator allocator;
ByteBuffer buffer = allocator.buffer(16);

buffer.writeCString("hello world!");   // returns 12
buffer.readableBytes();                // 12
buffer.capacity();                     // 16

std::string hello = buffer.readString(5);   // "hello", reader cursor is now at 5
buffer.skipBytes(1);                        // drop the space
buffer.readableBytes();                     // 6

uint8_t out[8] = {0};
buffer.readBytes(out, sizeof(out));    // copies "world!", returns 6
```

Copying a buffer is cheap: both copies share one storage block, and the block is only duplicated
when one of them is about to write. Readers never copy.

```C++
ByteBuffer other = buffer;             // no allocation, storage is shared
other.writeCString("!");               // 'other' takes a private copy here; 'buffer' is untouched
```

`bytes()` hands out a read-only view of the block. `mutableBytes()` hands out a writable one and
performs the copy-on-write split first, so a mutation is never visible through another buffer.
`discardReadBytes()` moves the readable region back to the front of the block to reclaim the
already-consumed prefix, and `clear()` resets both cursors without touching the storage.

A `ByteBuffer` itself is not thread-safe. Two buffers that share a storage block may be used from
different threads: the reference count is atomic and the first writer splits the block off.

## Custom allocators

`ByteBufferAllocator` is the seam for putting a buffer somewhere other than the malloc heap — an
arena, a pool, shared memory. It is four function pointers, and the default is
malloc/realloc/free/memmove:

```C++
ByteBufferAllocator arena{arenaAllocate, arenaReallocate, arenaDeallocate, arenaCopybytes};
ByteBuffer buffer = arena.buffer(4096);
```

`allocate` and `reallocate` may return `nullptr` to signal exhaustion; the buffer then reports a
zero-byte write and leaves its storage intact rather than corrupting it.

# CopyOnWriteBacked

Value semantics for a heap element, with the copy deferred until someone writes.

```C++
struct DataSources { /* ... */ };

auto ds = CopyOnWriteMake<DataSources>();
auto shared = ds;               // O(1), just a retain
ds.retainCount();               // 2

ds.read()->query();             // const view of the shared element
ds->query();                    // same, through operator->
ds.unique()->mutate();          // splits off a private copy first, retainCount() is 1 again
```

`read()` and `operator->` are the only const accessors; `unique()` is the only way to a mutable
pointer, which is what makes the copy-on-write invariant hold. The reference count is atomic, so
distinct instances sharing one element can be retained and released from different threads.

# Diagnostics

Diagnostics collects leveled messages, optionally echoing them to a `FILE *`, and remembers whether
anything went wrong. It is the error channel the `sys` wrappers report through.

```C++
Diagnostics diag("[npfoundation] ", stderr);

diag.info("loading %s", path);
diag.error("cannot load %s", path);

diag.hasError();        // true
diag.assertNoError();   // aborts, printing the collected errors
diag.clearError();
```

# Sys

Thin wrappers around POSIX calls. They never set `errno` for the caller to inspect and never throw;
failure is reported into a `Diagnostics`, so a sequence of calls can be written straight through and
checked once at the end.

```C++
Diagnostics diag(stderr);

int fd = Sys::open(diag, path, O_RDONLY, 0);
Sys::ftruncate(diag, fd, 0);
Sys::close(diag, fd);
if (diag.hasError()) { /* ... */ }

Sys::withMmapReadOnly(diag, path, ^(const void *mapping, size_t size, const char *realerPath) {
    // the mapping is unmapped when the block returns
});
```

Also available: `stat`, `fstatat`, `truncate`, `realpath`, `cwd`, `dirExists`, `fileExists`,
`mmapReadOnly`, `mmapReadWrite`, `munmap`.

# Heap

A binary heap over `std::vector`, max-heap by default.

```C++
Heap<int> heap(HeapType::min);
heap.push(3);
heap.push(1);
heap.top();     // std::optional<int>{1}
heap.pop();     // std::optional<int>{1}, removes it
heap.empty();

Heap<int> heapified({5, 1, 9, 3});   // heapified in place, O(n)
```

# Dispatch

## Timer

```Objective-C
NPTimer timer = NPDispatchTimer(nil, 1, 0, ^{
    // runs every second on the given queue (nil means a default queue)
});
NPDispatchTimerSuspend(timer);
NPDispatchTimerResume(timer);
NPDispatchTimerCancel(timer);
```

`NPDispatchTimerObservable` binds the timer to an object's lifetime — when the observable is
deallocated, the timer is cancelled for you:

```Objective-C
NP_WEAK(NSObject *) observable = [NSObject new];
NPDispatchTimerObservable(observable, nil, 1, 0, ^{
    // task code
});
```

## Throttle and debounce

Both return an `NPScheduleWorkRef`, an opaque handle you drive with `NPScheduleWorkSignal` and
`NPScheduleWorkCancel`. Signal it once per event you want the callback to answer, and the schedule
decides how many of those signals reach it. Ownership of the handle is yours, so free it when you are
done — it is not reference counted, so that is one `NPScheduleWorkFree` per handle. Throttle runs the
callback at most once per window (cancelling has no effect, since the work already ran); debounce
delays the callback until the signals stop, so cancelling can still call it off.

```Objective-C
NPScheduleWorkRef throttled = NPDispatchScheduleThrottle(0.5, queue, ^{ /* task */ });
NPScheduleWorkSignal(throttled);
NPScheduleWorkFree(throttled);

NPScheduleWorkRef debounced = NPDispatchScheduleDebounce(0.5, 0, queue, ^{ /* task */ });
NPScheduleWorkSignal(debounced);
NPScheduleWorkCancel(debounced);
NPScheduleWorkFree(debounced);
```

The same from Swift, where the handle imports as `NPScheduleWorkRef?`:

```Swift
let throttled = NPDispatchScheduleThrottle(0.5, queue, { /* task */ })
NPScheduleWorkSignal(throttled)
NPScheduleWorkFree(throttled)
```

The handle is opaque on purpose. Its layout is a pair of blocks, and a struct with block fields is
non-trivial under ARC but trivial without it — the two disagree on how to pass it, and Swift's C
importer refuses to import it at all. Behind a pointer, none of that reaches the caller. Since the
blocks are owned by the handle rather than by ARC, they need an explicit `NPScheduleWorkFree`.
Signalling and cancelling are safe from any thread; freeing is not, so make sure nothing else still
holds the handle.

# Objective-C runtime

## NSObjCRuntime

Add a new method to a class: the implementation goes after `BEGIN`, and the result of the
installation is available after `PROCESS`.

```Objective-C
NP_CLASS_ADDMETHOD_BEGIN([NSObject class], @selector(name), NULL,
        NP_RETURN(NSString *), NP_ARGS(id self, SEL name)) {
    return @"ObjectName";
}
NP_CLASS_ADDMETHOD_PROCESS {
    NSLog(@"  class: %@", _np_cls);
    NSLog(@"    sel: %s", sel_getName(_np_sel));
    NSLog(@"  types: %s", _np_types);
    NSLog(@"success: %d", _np_success);
}
NP_CLASS_ADDMETHOD_END
```

Replace an existing method; the original implementation is reachable through `_np_next_imp`, which
`NP_METHOD_OVERLOAD` calls for you.

```Objective-C
NP_CLASS_REPLACEMETHOD_BEGIN([NSObject class], @selector(description), NULL,
        NP_RETURN(NSString *), NP_ARGS(id self, SEL name)) {
    NSString *description = NP_METHOD_OVERLOAD(self, _np_sel);
    return description;
}
NP_CLASS_REPLACEMETHOD_PROCESS {
    NSLog(@"   class: %@", _np_cls);
    NSLog(@"     sel: %s", sel_getName(_np_sel));
    NSLog(@"   types: %s", _np_types);
    NSLog(@"NEXT_IMP: %p", _np_next_imp);
}
NP_CLASS_REPLACEMETHOD_END
```

Override a superclass method, calling `[super method]` via `NP_MAKE_OBJC_SUPER` and
`NP_METHOD_OVERRIDE`.

```Objective-C
NP_CLASS_OVERRIDEMETHOD_BEGIN([Sub class], @selector(description), NULL,
        NP_RETURN(NSString *), NP_ARGS(id self, SEL name)) {
    NP_MAKE_OBJC_SUPER(self);
    NSString *description = NP_METHOD_OVERRIDE(_np_sel);
    return description;
}
NP_CLASS_OVERRIDEMETHOD_PROCESS {
    NSLog(@"   class: %@", _np_cls);
    NSLog(@"     sel: %s", sel_getName(_np_sel));
    NSLog(@"   types: %s", _np_types);
    NSLog(@"  method: %p", _np_super_method);
}
NP_CLASS_OVERRIDEMETHOD_END
```

## NSValueObserving

```Objective-C
NPAttachDeallocationHandler(object, ^{
    // runs when 'object' is deallocated
});
```

# Machine context

Capture the register state of a thread — the basis for walking a stack from outside it.

```C
struct NPMachineContext context;
if (NPMachineContextGet(&context, pthread_self())) {
    uintptr_t pc = NPMachineContextGetInstructionAddress(&context);
    uintptr_t fp = NPMachineContextGetFramePointer(&context);
    uintptr_t sp = NPMachineContextGetStackPointer(&context);
    uintptr_t lr = NPMachineContextGetLinkRegister(&context);
}
```

# Development

```
swift build
swift test
swift test --sanitize=address
```

# License

MIT. See [LICENSE](LICENSE).
