//
//  timer.h
//  npfoundation
//
//  Created by Jonathan Lee on 7/13/25.
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

#include <NPFoundation/dispatch.h>
#include <NPFoundation/objc.h>
#include <os/lock.h>

@interface _NPTimer : NSObject {
    bool _isCancelled;
    bool _isSuspended;
    os_unfair_lock _unfair_lock;
}

@end

@implementation _NPTimer

- (instancetype)init {
    if (self = [super init]) {
        _isCancelled = false;
        _isSuspended = false;
        _unfair_lock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

- (void)resume:(NPTimer)timer {
    bool isExecutable = false;
    os_unfair_lock_lock(&_unfair_lock);
    if (!_isCancelled && _isSuspended) {
        _isSuspended = false;
        isExecutable = true;
    }
    os_unfair_lock_unlock(&_unfair_lock);
    if (isExecutable) {
        dispatch_resume(timer);
    }
}

- (void)suspend:(NPTimer)timer {
    bool isExecutable = false;
    os_unfair_lock_lock(&_unfair_lock);
    if (!_isCancelled && !_isSuspended) {
        _isSuspended = true;
        isExecutable = true;
    }
    os_unfair_lock_unlock(&_unfair_lock);
    if (isExecutable) {
        dispatch_suspend(timer);
    }
}

- (void)cancel:(NPTimer)timer {
    bool isExecutable = false;
    bool wasSuspended = false;
    os_unfair_lock_lock(&_unfair_lock);
    if (!_isCancelled) {
        _isCancelled = true;
        wasSuspended = _isSuspended;
        _isSuspended = false;
        isExecutable = true;
    }
    os_unfair_lock_unlock(&_unfair_lock);
    if (isExecutable) {
        dispatch_source_cancel(timer);
        // Releasing a suspended source traps in libdispatch ("BUG IN CLIENT OF LIBDISPATCH: Release
        // of a suspended object"), and a suspended source never processes its cancellation anyway.
        // Balance the suspend so the cancellation can run and the source can be reclaimed.
        if (wasSuspended) {
            dispatch_resume(timer);
        }
    }
}

@end

static UInt8 gTimerKey = 0;
NP_STATIC_INLINE void setAssociated(NPTimer timer) {
    objc_setAssociatedObject(timer, &gTimerKey, [_NPTimer new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NP_STATIC_INLINE _NPTimer * associated(NPTimer timer) {
    return objc_getAssociatedObject(timer, &gTimerKey);
}

NPTimer NPDispatchTimer(dispatch_queue_t dispatchQueue, double intervalInSeconds, double leewayInSeconds, dispatch_block_t block) {
    if (dispatchQueue == NULL) {
        dispatchQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    }
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatchQueue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, intervalInSeconds * NSEC_PER_SEC, leewayInSeconds * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, block);
    dispatch_activate(timer);
    setAssociated(timer);
    return timer;
}

NPTimer NPDispatchTimerObservable(id observable, dispatch_queue_t dispatchQueue, double intervalInSeconds, double leewayInSeconds, dispatch_block_t block) {
    NPTimer timer = NPDispatchTimer(dispatchQueue, intervalInSeconds, leewayInSeconds, block);
    NPAttachDeallocationHandler(observable, ^{
        NPDispatchTimerCancel(timer);
    });
    return timer;
}

void NPDispatchTimerResume(NPTimer timer) {
    [associated(timer) resume:timer];
}

void NPDispatchTimerSuspend(NPTimer timer) {
    [associated(timer) suspend:timer];
}

void NPDispatchTimerCancel(NPTimer timer) {
    [associated(timer) cancel:timer];
}
