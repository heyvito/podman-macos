//
//  PMLoginItem.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMLoginItem.h"
#import <CoreServices/CoreServices.h>

@implementation PMLoginItem

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (BOOL)loginItemExistsWithURL:(NSURL *)url {
    LSSharedFileListRef itemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    CFArrayRef items = LSSharedFileListCopySnapshot(itemsRef, nil);

    BOOL exists = NO;
    for (id item in (__bridge NSArray *)items) {
        CFURLRef loginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, nil);
        if (loginItem == nil) {
            continue;
        }

        if ([(__bridge NSURL *)loginItem isEqual:url]) {
            exists = YES;
            CFRelease(loginItem);
            break;
        }
        CFRelease(loginItem);
    }

    CFRelease(itemsRef);
    CFRelease(items);

    return exists;
}

+ (void)addLoginItemWithURL:(NSURL *)url {
    if ([self loginItemExistsWithURL:url]) {
        return;
    }
    LSSharedFileListRef itemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    LSSharedFileListItemRef newItem = LSSharedFileListInsertItemURL(itemsRef, kLSSharedFileListItemLast, nil, nil, (__bridge CFURLRef)url, nil, nil);
    CFRelease(newItem);
    CFRelease(itemsRef);
}

+ (void)removeLoginItemWithURL:(NSURL *)url {
    if (![self loginItemExistsWithURL:url]) {
        return;
    }

    LSSharedFileListRef itemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    CFArrayRef items = LSSharedFileListCopySnapshot(itemsRef, nil);

    for (id item in (__bridge NSArray *)items) {
        CFURLRef loginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, nil);
        if ([(__bridge NSURL *)loginItem isEqual:url]) {
            LSSharedFileListItemRemove(itemsRef, (__bridge LSSharedFileListItemRef)item);
            CFRelease(loginItem);
            break;
        }
        CFRelease(loginItem);
    }

    CFRelease(items);
    CFRelease(itemsRef);
}

#pragma clang diagnostic pop

@end
