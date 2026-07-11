//
//  NPFoundation.cpp
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

#include <NPFoundation/NPFoundation.h>

#include <type_traits>

// This translation unit is the one that matters for the check below: plain C++, no ARC. A struct
// with retainable fields is trivially copyable here but *not* under ARC, and clang passes the two
// differently — a non-trivial C struct is returned indirectly. Keeping NPScheduleWork trivial
// everywhere is what lets an ARC implementation and a non-ARC caller agree on the ABI.
static_assert(std::is_trivially_copyable<NPScheduleWork>::value,
              "NPScheduleWork must stay trivially copyable so that ARC and non-ARC translation "
              "units agree on how to pass it");
