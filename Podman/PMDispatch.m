//
//  PMDispatch.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMDispatch.h"

@implementation PMDispatch

+ (void)background:(void (^)(void))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block);
}

+ (void)async:(void (^)(void))block {
    dispatch_async(dispatch_get_main_queue(), block);
}

+ (void)sync:(void (^)(void))block {
    dispatch_sync(dispatch_get_main_queue(), block);
}

@end
