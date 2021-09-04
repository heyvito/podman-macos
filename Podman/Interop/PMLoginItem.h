//
//  PMLoginItem.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PMLoginItem : NSObject


/// Determines whether a Login Item exists with the provided URL
/// @param url URL to check for
+ (BOOL)loginItemExistsWithURL:(NSURL *)url;


/// Adds a given URL to the Login Items list in case it still does not exist.
/// @param url URL to the Application to be added to Login Items
+ (void)addLoginItemWithURL:(NSURL *)url;


/// Removes a given URL from the Login Items list in case it exists
/// @param url URL to the Application to be removed from Login Items
+ (void)removeLoginItemWithURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
