//
//  AppDelegate.h
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>


/// Starts the agent by placing an icon in the system's Menu Bar.
/// Multiple calls to this method has no effect.
- (void)startAgent;

@end

