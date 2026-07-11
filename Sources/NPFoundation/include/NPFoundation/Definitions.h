//
//  Definitions.h
//  npfoundation
//
//  Created by Jonathan Lee on 5/6/25.
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

#ifndef NP_DEFINITION_H
#define NP_DEFINITION_H

#ifdef __APPLE__
#include <Availability.h>
#include <TargetConditionals.h>
#define NP_PLATFORM_APPLE 1
#endif

#if defined(TARGET_OS_VISION) && TARGET_OS_VISION
#define NP_DESTINATION_XROS 1
#else
#define NP_DESTINATION_XROS 0
#endif

#define NP_DESTINATION_IOS     (NP_PLATFORM_APPLE && TARGET_OS_IOS  )
#define NP_DESTINATION_TVOS    (NP_PLATFORM_APPLE && TARGET_OS_TV   )
#define NP_DESTINATION_WATCHOS (NP_PLATFORM_APPLE && TARGET_OS_WATCH)
#define NP_DESTINATION_MACOS   (NP_PLATFORM_APPLE && TARGET_OS_MAC && !(TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH || NP_DESTINATION_XROS))

#if NP_DESTINATION_IOS || NP_DESTINATION_TVOS || NP_DESTINATION_WATCHOS || NP_DESTINATION_XROS
#define NP_HAS_UIKIT 1
#else
#define NP_HAS_UIKIT 0
#endif

#if defined(__cplusplus)
#define NP_EXTERN extern "C"
#else
#define NP_EXTERN extern
#endif

#define NP_EXPORT NP_EXTERN
#define NP_IMPORT NP_EXTERN

#define NP_STATIC_INLINE static __inline__
#define NP_EXTERN_INLINE extern __inline__
#define NP_BLOCK(TYPE) __block TYPE
#define NP_WEAK(TYPE) __weak TYPE

// Keeps a retainable field or variable out of ARC's hands: ownership of it is then manual, and
// whoever fills it in says how it is released.
#if defined(__has_feature) && __has_feature(objc_arc)
#define NP_UNRETAINED __unsafe_unretained
#else
#define NP_UNRETAINED
#endif

#if defined(__cplusplus)
#define NP_CEXTERN_BEGIN extern "C" {
#define NP_CEXTERN_END }
#else
#define NP_CEXTERN_BEGIN
#define NP_CEXTERN_END
#endif

#define NP_NAMESPACE_BEGIN(NAME) namespace NAME {
#define NP_NAMESPACE_END }

#endif /* NP_DEFINITION_H */
