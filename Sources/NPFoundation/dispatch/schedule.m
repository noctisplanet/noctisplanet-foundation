//
//  schedule.m
//  npfoundation
//
//  Created by Jonathan Lee on 8/14/25.
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
#include <Foundation/Foundation.h>
#include <time.h>

/// A monotonic clock: unlike CFAbsoluteTimeGetCurrent(), it cannot jump backwards when the wall
/// clock is adjusted, which would otherwise let a throttle stall for the length of the jump.
NP_STATIC_INLINE double monotonicSeconds(void) {
    return (double)clock_gettime_nsec_np(CLOCK_MONOTONIC) / (double)NSEC_PER_SEC;
}

NPScheduleWork NPDispatchScheduleThrottle(double delayInSeconds, dispatch_queue_t on, dispatch_block_t callback) {
    NP_BLOCK(double) previous = 0;
    NP_BLOCK(bool) hasFired = false;
    dispatch_queue_attr_t attribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    dispatch_queue_t queue = dispatch_queue_create("com.dispatch.throttle-queue", attribute);
    dispatch_block_t resume = ^{
        double timestamp = monotonicSeconds();
        if (!hasFired || timestamp - previous >= delayInSeconds) {
            hasFired = true;
            previous = timestamp;
            dispatch_async(on, callback);
        }
    };
    NPScheduleWork scheduleWork = {
        .resume = ^{
            dispatch_async(queue, resume);
        },
        .cancel = ^{
            // Nothing to cancel: the throttled callback has already been dispatched by the time
            // resume() returns, or it was dropped.
        },
    };
    return scheduleWork;
}

NPScheduleWork NPDispatchScheduleDeboundce(double delayInSeconds, double leewayInSeconds, dispatch_queue_t on, dispatch_block_t callback) {
    NP_BLOCK(bool) canceled = false;
    NP_BLOCK(uint64_t) generation = 0;
    dispatch_queue_attr_t attribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    dispatch_queue_t queue = dispatch_queue_create("com.dispatch.debounce-queue", attribute);
    dispatch_block_t resume = ^{
        canceled = false;
        uint64_t current = ++generation;
        // A one-shot timer source rather than dispatch_after(): dispatch_after() has no way to
        // honour a leeway, and the source releases itself once it has been cancelled.
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)),
                                  DISPATCH_TIME_FOREVER,
                                  (uint64_t)(leewayInSeconds * NSEC_PER_SEC));
        dispatch_source_set_event_handler(timer, ^{
            dispatch_source_cancel(timer);
            // Every state read here happens on the serial queue the source targets, so `generation`
            // and `canceled` are stable. A newer resume() bumped the generation, and that newer
            // timer is the one allowed to fire.
            if (!canceled && current == generation) {
                dispatch_async(on, callback);
            }
        });
        dispatch_activate(timer);
    };
    dispatch_block_t cancel = ^{
        canceled = true;
    };
    NPScheduleWork scheduleWork = {
        .resume = ^{
            dispatch_async(queue, resume);
        },
        .cancel = ^{
            dispatch_async(queue, cancel);
        },
    };
    return scheduleWork;
}
