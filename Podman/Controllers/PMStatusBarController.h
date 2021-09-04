//
//  PMStatusBarController.h
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PMStatusBarController : NSObject

- (instancetype)initWithPopover:(NSPopover *)popover;

@end

NS_ASSUME_NONNULL_END
