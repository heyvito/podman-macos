//
//  PFMoveApplication.h, version 1.25
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//  Updated by Victor Gama on 9/03/21
//
//  The contents of this file are dedicated to the public domain.


#import <Foundation/Foundation.h>

@interface PMMoveToApplications : NSObject

/**
 Moves the running application to ~/Applications or /Applications if the former does not exist.
 After the move, it relaunches app from the new location.
 DOES NOT work for sandboxed applications.

 Call from \c NSApplication's delegate method \c -applicationWillFinishLaunching: method. */
+ (void)moveToApplicationsFolderIfNecessary;

@end
