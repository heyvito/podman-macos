//
//  PMPreferences.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// PMPreferences provides helper properties for handling the application's preferences
@interface PMPreferences : NSObject

/// Determines whether the application should start automatically during login
@property (nonatomic, class) BOOL startAtLogin;

/// Determines whether the application should start Podman's VM at startup
@property (nonatomic, class) BOOL startPodmanVM;

/// Determines whether the application should check for updates automatically
@property (nonatomic, class) BOOL checkForUpdates;

/// Determines whether the application already offered to start at login
@property (nonatomic, class) BOOL askedToStartAtLogin;

@end

NS_ASSUME_NONNULL_END
