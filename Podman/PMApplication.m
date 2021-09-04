//
//  PMApplication.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import "PMApplication.h"
#import "AppDelegate.h"

@implementation PMApplication {
    AppDelegate *appDelegate;
}

- (instancetype)init {
    if ((self = [super init]) == nil) {
        return self;
    }

    self->appDelegate = [[AppDelegate alloc] init];
    self.delegate = self->appDelegate;

    return self;
}

@end
