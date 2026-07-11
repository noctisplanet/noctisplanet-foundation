//
//  sys.cpp
//  npfoundation
//
//  Created by Jonathan Lee on 10/6/25.
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

#include <NPFoundation/sys.h>
#include <cerrno>
#include <climits>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

NP_NAMESPACE_BEGIN(NP)
NP_NAMESPACE_BEGIN(Sys)

int open(Diagnostics &diag, const char *path, int flag, int other) noexcept {
    int fd;
    do {
        fd = ::open(path, flag, other);
    } while ((fd < 0) && ((errno == EAGAIN) || (errno == EINTR)));
    if (fd < 0) {
        int err = errno;
        diag.error("open() failed with errno=%d, %s", err, strerror(err));
    }
    return fd;
}

void close(Diagnostics &diag, int fd) noexcept {
    // close() must not be retried on EINTR: the descriptor is already gone, and retrying could
    // close a descriptor another thread has since opened with the same number.
    if (::close(fd) != 0 && errno != EINTR) {
        int err = errno;
        diag.error("close() failed with errno=%d, %s", err, strerror(err));
    }
}

void stat(Diagnostics &diag, const char *path, struct ::stat *buf) noexcept {
    int result;
    do {
        result = ::stat(path, buf);
    } while ((result == -1) && ((errno == EAGAIN) || (errno == EINTR)));
    if (result != 0) {
        int err = errno;
        diag.error("stat() failed with errno=%d, %s", err, strerror(err));
    }
}

void fstatat(Diagnostics &diag, int fd, const char *path, struct ::stat *buf, int flag) noexcept {
    int result;
    do {
        result = ::fstatat(fd, path, buf, flag);
    } while ((result == -1) && ((errno == EAGAIN) || (errno == EINTR)));
    if (result != 0) {
        int err = errno;
        diag.error("fstatat() failed with errno=%d, %s", err, strerror(err));
    }
}

void truncate(Diagnostics &diag, const char *path, size_t size) noexcept {
    int result;
    do {
        result = ::truncate(path, size);
    } while ((result == -1) && ((errno == EAGAIN) || (errno == EINTR)));
    if (result != 0) {
        int err = errno;
        diag.error("truncate() failed with errno=%d, %s", err, strerror(err));
    }
}

void ftruncate(Diagnostics &diag, int fd, size_t size) noexcept {
    int result;
    do {
        result = ::ftruncate(fd, size);
    } while ((result == -1) && ((errno == EAGAIN) || (errno == EINTR)));
    if (result != 0) {
        int err = errno;
        diag.error("ftruncate() failed with errno=%d, %s", err, strerror(err));
    }
}

void cwd(Diagnostics &diag, char *output) noexcept {
    int fd = open(diag, ".", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0) {
        return;
    }
    if (::fcntl(fd, F_GETPATH, output) != 0) {
        int err = errno;
        diag.error("fcntl(F_GETPATH) failed with errno=%d, %s", err, strerror(err));
    }
    close(diag, fd);
}

void realpath(Diagnostics &diag, const char *input, char *output) noexcept {
    // No O_DIRECTORY here: realpath() has to resolve regular files too, and F_GETPATH works on any
    // descriptor.
    int fd = open(diag, input, O_RDONLY, 0);
    if (fd < 0) {
        return;
    }
    if (::fcntl(fd, F_GETPATH, output) != 0) {
        int err = errno;
        diag.error("fcntl(F_GETPATH) failed with errno=%d, %s", err, strerror(err));
    }
    close(diag, fd);
}

bool dirExists(const char *path) noexcept {
    Diagnostics diag;
    struct stat statbuf;
    stat(diag, path, &statbuf);
    if (diag.hasError()) {
        return false;
    }
    return S_ISDIR(statbuf.st_mode);;
}

bool fileExists(const char *path) noexcept {
    Diagnostics diag;
    struct stat statbuf;
    stat(diag, path, &statbuf);
    if (diag.hasError()) {
        return false;
    }
    return S_ISREG(statbuf.st_mode);;
}

/// Resolves `path` into `realerPath` without disturbing the caller's diagnostics: a buffer that
/// cannot be resolved is left empty rather than filled with stack garbage.
NP_STATIC_INLINE void resolveRealerPath(const char *path, char *realerPath) noexcept {
    if (realerPath == nullptr) {
        return;
    }
    realerPath[0] = '\0';
    Diagnostics quiet{nullptr};
    realpath(quiet, path, realerPath);
}

const void * mmapReadOnly(Diagnostics &diag, const char *path, size_t *size, char *realerPath) noexcept {
    struct stat statbuf;
    stat(diag, path, &statbuf);
    if (diag.hasError()) {
        return nullptr;
    }
    if (statbuf.st_size <= 0) {
        // Nothing to map. mmap() of a zero-length range fails with EINVAL, so report it as an
        // empty mapping instead of an error.
        if (size != nullptr) {
            *size = 0;
        }
        return nullptr;
    }

    int fd = open(diag, path, O_RDONLY, 0);
    if (fd < 0) {
        return nullptr;
    }

    size_t mappedSize = (size_t)statbuf.st_size;
    const void *result = ::mmap(nullptr, mappedSize, PROT_READ, MAP_PRIVATE, fd, 0);
    if (result == MAP_FAILED) {
        int err = errno;
        diag.error("mmap(size=0x%0lX) failed with errno=%d, %s", mappedSize, err, strerror(err));
        close(diag, fd);
        return nullptr;
    }

    if (size != nullptr) {
        *size = mappedSize;
    }
    resolveRealerPath(path, realerPath);
    close(diag, fd);
    return result;
}

void withMmapReadOnly(Diagnostics &diag, const char *path, void (^handler)(const void *mapping, size_t size, const char* realerPath)) noexcept {
    size_t mappedSize = 0;
    char realerPath[PATH_MAX] = {0};
    const void *mapping = mmapReadOnly(diag, path, &mappedSize, realerPath);
    if (mapping == nullptr) {
        return;
    }
    handler(mapping, mappedSize, realerPath);
    munmap(diag, (void *)mapping, mappedSize);
}

void * mmapReadWrite(Diagnostics &diag, const char *path, size_t *size, char *realerPath) noexcept {
    int fd = open(diag, path, O_RDWR | O_CREAT, 0666);
    if (fd < 0) {
        return nullptr;
    }

    struct stat statbuf;
    stat(diag, path, &statbuf);
    if (diag.hasError()) {
        close(diag, fd);
        return nullptr;
    }

    size_t mappedSize = (size_t)statbuf.st_size;
    if (statbuf.st_size <= 0) {
        // mmap() cannot map an empty file, so give a freshly created one a page to live in.
        mappedSize = 1024 * 4;
        ftruncate(diag, fd, mappedSize);
        if (diag.hasError()) {
            close(diag, fd);
            return nullptr;
        }
    }

    // MAP_SHARED, not MAP_PRIVATE: a private mapping is copy-on-write, so nothing written through
    // it would ever reach the file.
    void *result = ::mmap(nullptr, mappedSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (result == MAP_FAILED) {
        int err = errno;
        diag.error("mmap(size=0x%0lX) failed with errno=%d, %s", mappedSize, err, strerror(err));
        close(diag, fd);
        return nullptr;
    }

    if (size != nullptr) {
        *size = mappedSize;
    }
    resolveRealerPath(path, realerPath);
    close(diag, fd);
    return result;
}

void munmap(Diagnostics &diag, void *buf, size_t size) noexcept {
    if (::munmap(buf, size) != 0) {
        diag.error("munmap() failed with errno=%d, %s", errno, strerror(errno));
    }
}

NP_NAMESPACE_END
NP_NAMESPACE_END
