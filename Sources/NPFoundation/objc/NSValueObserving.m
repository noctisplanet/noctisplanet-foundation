//
//  NSValueObserving.m
//  npfoundation
//
//  Created by Jonathan Lee on 8/19/25.
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

#import <NPFoundation/objc.h>

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

@interface NPNSValueObserving : NSObject

@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *handlers;

@end

@implementation NPNSValueObserving

- (instancetype)init {
    if (self = [super init]) {
        _handlers = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc {
    for (dispatch_block_t handler in _handlers) {
        handler();
    }
    [_handlers removeAllObjects];
}

- (void)addObserverHandler:(dispatch_block_t)handler {
    // -addObject: only retains, and retaining a stack block is a no-op. An ARC caller happens to
    // hand us a heap block already, but a caller compiled without ARC does not, and the block would
    // then dangle as soon as its frame returns. Copying is a plain retain for a heap block.
    [_handlers addObject:[handler copy]];
}

@end

void NPAttachDeallocationHandler(id<NSObject> observable, dispatch_block_t handler) {
    static uint8_t key = 0;
    if (!observable) {
        handler();
        return;
    }
    
    NPNSValueObserving *observing = nil;
    @synchronized (observable) {
        observing = objc_getAssociatedObject(observable, &key);
        if (!observing) {
            observing = [NPNSValueObserving new];
            objc_setAssociatedObject(observable, &key, observing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [observing addObserverHandler:handler];
    }
}
