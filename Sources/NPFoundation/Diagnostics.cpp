//
//  Diagnostics.cpp
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

#include <NPFoundation/Diagnostics.h>
#include <stdio.h>
#include <stdlib.h>

NP_NAMESPACE_BEGIN(NP)

Diagnostics::Diagnostics(FILE *stream) : stream(stream) {

}

Diagnostics::Diagnostics(const std::string &prefix, FILE *stream) : stream(stream), prefix(prefix) {

}

void Diagnostics::append(const Message &message) {
    if (stream != nullptr) {
        if (!prefix.empty()) {
            ::fprintf(stream, "[%s] ", prefix.c_str());
        }
        ::fprintf(stream, "%s\n", message.text.c_str());
    }
    if (message.behavior == Behavior::error) {
        errors.push_back(message);
    }
}


void Diagnostics::append(Behavior behavior, const char *format, va_list args) {
    va_list list;
    va_copy(list, args);
    int length = vsnprintf(nullptr, 0, format, list);
    va_end(list);
    if (length <= 0)
        return;
    std::vector<char> buf(length + 1);
    vsnprintf(buf.data(), buf.size(), format, args);
    this->append({behavior, std::string(buf.data(), length)});
}

void Diagnostics::debug(const char *format, ...) {
    va_list args;
    va_start(args, format);
    this->append(Behavior::debug, format, args);
    va_end(args);
}

void Diagnostics::info(const char *format, ...) {
    va_list args;
    va_start(args, format);
    this->append(Behavior::info, format, args);
    va_end(args);
}

void Diagnostics::warning(const char *format, ...) {
    va_list args;
    va_start(args, format);
    this->append(Behavior::warning, format, args);
    va_end(args);
}

void Diagnostics::error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    this->append(Behavior::error, format, args);
    va_end(args);
}

bool Diagnostics::hasError() const {
    return !errors.empty();
}

bool Diagnostics::noError() const {
    return errors.empty();
}

const std::vector<Diagnostics::Message> & Diagnostics::getErrors() const {
    return errors;
}

void Diagnostics::clearError() {
    errors.clear();
}

void Diagnostics::assertNoError() const {
    if (noError()) {
        return;
    }
    FILE *out = stream != nullptr ? stream : stderr;
    for (const Message &message : errors) {
        if (!prefix.empty()) {
            ::fprintf(out, "[%s] ", prefix.c_str());
        }
        ::fprintf(out, "assertNoError: %s\n", message.text.c_str());
    }
    ::fflush(out);
    ::abort();
}

NP_NAMESPACE_END
