//
//  schedule.h
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

#ifndef NP_DISPATCH_SCHEDULE_H
#define NP_DISPATCH_SCHEDULE_H
#ifdef __BLOCKS__

#include <NPFoundation/Definitions.h>
#include <dispatch/dispatch.h>

NP_CEXTERN_BEGIN

/// A handle to a scheduled callback: `resume` asks for the callback to run, `cancel` calls it off.
///
/// The two blocks are owned by the handle, not by ARC, which is what keeps the struct trivially
/// copyable in every translation unit. Fill one in with NPDispatchScheduleThrottle or
/// NPDispatchScheduleDebounce, and hand it to NPScheduleWorkRelease when you are done with it.
///
/// A handle is not thread-safe to fill in or release concurrently, but `resume` and `cancel` may be
/// called from any thread once it has been filled in.
struct NPScheduleWork {
    NP_UNRETAINED dispatch_block_t resume;
    NP_UNRETAINED dispatch_block_t cancel;
};
typedef struct NPScheduleWork NPScheduleWork;

/// Schedules a throttled execution of a callback on a dispatch queue.
///
/// Throttling runs the callback at most once per delay window, no matter how many times `resume` is
/// called within it. The first `resume` runs the callback immediately.
///
/// `cancel` does nothing for a throttle: by the time it could be called, the callback has already
/// been dispatched, or it was dropped.
///
/// - Parameters:
///   - delayInSeconds: The minimum delay (in seconds) between two callback executions. Calls to
///                     `resume` within this window are ignored.
///   - on: The dispatch queue on which to execute the callback.
///   - callback: The callback to execute when the throttling condition is met.
///   - work: Out-parameter, filled in with the handle. Must not be NULL. Release it with
///           NPScheduleWorkRelease.
NP_EXTERN void NPDispatchScheduleThrottle(double delayInSeconds, dispatch_queue_t on, dispatch_block_t callback, NPScheduleWork *work);

/// Schedules a debounced execution of a callback on a dispatch queue.
///
/// Debouncing delays the callback until `delayInSeconds` have passed with no further call to
/// `resume`. A burst of calls therefore collapses into a single execution.
///
/// `cancel` is effective for a debounce, since its work is always delayed: it calls off a pending
/// execution. A later `resume` starts a new one.
///
/// - Parameters:
///   - delayInSeconds: The quiet period (in seconds) that must pass after the last `resume` before
///                     the callback runs.
///   - leewayInSeconds: The tolerance (in seconds) the system may add to the timer to save power.
///   - on: The dispatch queue on which to execute the callback.
///   - callback: The callback to execute when the debounce condition is met.
///   - work: Out-parameter, filled in with the handle. Must not be NULL. Release it with
///           NPScheduleWorkRelease.
NP_EXTERN void NPDispatchScheduleDebounce(double delayInSeconds, double leewayInSeconds, dispatch_queue_t on, dispatch_block_t callback, NPScheduleWork *work);

/// Releases the blocks held by a schedule handle and clears it. Releasing a NULL or already-released
/// handle does nothing, and neither `resume` nor `cancel` may be called afterwards.
///
/// This does not call off a debounce that is already pending: call `cancel` first if the callback
/// must not run.
NP_EXTERN void NPScheduleWorkRelease(NPScheduleWork *work);

NP_CEXTERN_END

#endif /* __BLOCKS__ */
#endif /* NP_DISPATCH_SCHEDULE_H */
