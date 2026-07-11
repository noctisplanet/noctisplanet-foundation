//
//  Diagnostics.h
//  npfoundation
//
//  Created by Jonathan Lee on 6/22/25.
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

#ifndef NP_DIAGNOSTICS_H
#define NP_DIAGNOSTICS_H

#ifdef __cplusplus

#include <NPFoundation/Definitions.h>
#include <cstdarg>
#include <cstdio>
#include <string>
#include <vector>

NP_NAMESPACE_BEGIN(NP)

/// Collects leveled diagnostic messages, optionally echoing them to a stream, and remembers whether
/// any of them was an error.
///
/// Only messages logged at `Behavior::error` are retained; the rest are echoed and dropped. This is
/// the error channel the Sys wrappers report through: a caller can run a sequence of calls and check
/// `hasError()` once at the end instead of testing each one.
class Diagnostics {

public:

    enum class Behavior {
        debug, info, warning, error
    };

    struct Message {
        Behavior behavior;
        std::string text;
    };

private:

    FILE *stream;

    std::string prefix;

    std::vector<Message> errors;

public:
    
    Diagnostics(FILE *stream = nullptr);
    
    Diagnostics(const std::string &prefix, FILE *stream = nullptr);
    
public:
    
    void append(const Message &message);
    
    void append(Behavior behavior, const char *format, va_list args);
    
    void debug(const char *format, ...) __attribute__((format(printf, 2, 3)));
    
    void info(const char *format, ...) __attribute__((format(printf, 2, 3)));
    
    void warning(const char *format, ...) __attribute__((format(printf, 2, 3)));
    
    void error(const char *format, ...) __attribute__((format(printf, 2, 3)));
    
public:
    
    bool hasError() const;

    bool noError() const;

    /// The errors collected so far, in the order they were logged.
    const std::vector<Message> & getErrors() const;

    void clearError();

    /// Prints every collected error and aborts the process if there is one. Does nothing otherwise.
    void assertNoError() const;
};

NP_NAMESPACE_END

#endif /* __cplusplus */

#endif /* NP_DIAGNOSTICS_H */
