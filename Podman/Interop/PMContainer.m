//
//  PMContainer.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMContainer.h"
#import "PMManager.h"

@implementation PMContainer

- (BOOL)isRunning {
    return [self.containerStatus containsString:@"Up"];
}

@end
