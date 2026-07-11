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

/// An opaque handle to a scheduled callback: NPScheduleWorkResume asks for the callback to run,
/// NPScheduleWorkCancel calls it off.
///
/// Create one with NPDispatchScheduleThrottle or NPDispatchScheduleDebounce, and hand it to
/// NPScheduleWorkRelease when you are done with it. The layout is private: the handle owns whatever
/// state the schedule needs, which is why it is passed around as a pointer and released explicitly
/// rather than being reclaimed by ARC.
///
/// Resume and cancel may be called from any thread. Releasing is not thread-safe against them: a
/// released handle is dangling, so make sure no other thread still holds it.
typedef struct NPScheduleWork *NPScheduleWorkRef;

/// Schedules a throttled execution of a callback on a dispatch queue.
///
/// Throttling runs the callback at most once per delay window, no matter how many times the handle
/// is resumed within it. The first resume runs the callback immediately.
///
/// Cancelling does nothing for a throttle: by the time it could take effect, the callback has
/// already been dispatched, or it was dropped.
///
/// - Parameters:
///   - delayInSeconds: The minimum delay (in seconds) between two callback executions. Resumes
///                     within this window are ignored.
///   - on: The dispatch queue on which to execute the callback.
///   - callback: The callback to execute when the throttling condition is met.
/// - Returns: The handle, or NULL if it could not be allocated. Release it with
///            NPScheduleWorkRelease.
NP_EXTERN NPScheduleWorkRef _Nullable NPDispatchScheduleThrottle(double delayInSeconds, dispatch_queue_t _Nonnull on, dispatch_block_t _Nonnull callback);

/// Schedules a debounced execution of a callback on a dispatch queue.
///
/// Debouncing delays the callback until `delayInSeconds` have passed with no further resume. A burst
/// of resumes therefore collapses into a single execution.
///
/// Cancelling is effective for a debounce, since its work is always delayed: it calls off a pending
/// execution. A later resume starts a new one.
///
/// - Parameters:
///   - delayInSeconds: The quiet period (in seconds) that must pass after the last resume before the
///                     callback runs.
///   - leewayInSeconds: The tolerance (in seconds) the system may add to the timer to save power.
///   - on: The dispatch queue on which to execute the callback.
///   - callback: The callback to execute when the debounce condition is met.
/// - Returns: The handle, or NULL if it could not be allocated. Release it with
///            NPScheduleWorkRelease.
NP_EXTERN NPScheduleWorkRef _Nullable NPDispatchScheduleDebounce(double delayInSeconds, double leewayInSeconds, dispatch_queue_t _Nonnull on, dispatch_block_t _Nonnull callback);

/// Asks for the scheduled callback to run, subject to the throttle or debounce condition of the
/// handle. Resuming a NULL handle does nothing.
NP_EXTERN void NPScheduleWorkResume(NPScheduleWorkRef _Nullable work);

/// Calls off a callback the handle has not run yet, and does nothing for a throttle or for a NULL
/// handle. A later resume schedules the callback again.
NP_EXTERN void NPScheduleWorkCancel(NPScheduleWorkRef _Nullable work);

/// Releases a schedule handle. Releasing a NULL handle does nothing, and the handle must not be
/// used — resumed, cancelled or released again — afterwards.
///
/// This does not call off a debounce that is already pending: cancel it first if the callback must
/// not run.
NP_EXTERN void NPScheduleWorkRelease(NPScheduleWorkRef _Nullable work);

NP_CEXTERN_END

#endif /* __BLOCKS__ */
#endif /* NP_DISPATCH_SCHEDULE_H */
