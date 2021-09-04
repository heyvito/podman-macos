//
//  PMDispatch.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// PMDispatch provides utility functions for dispatching blocks through the Grand Central Dispatch
@interface PMDispatch : NSObject

/// Asynchronously executes a given block in a background queue. Blocks being executed here must not
/// attempt to update the UI. In case that's needed, execute any UI updates in another block provided to
/// `sync:`
/// @param block Block to be executed asynchronously.
+ (void)background:(void (^ _Nonnull) (void))block;

/// Executes a block asynchronously in the main queue.
/// @param block Block to be executed asynchronously.
+ (void)async:(void (^ _Nonnull) (void))block;

/// Executes a block synchronously in the main queue.
/// @param block Block to be executed synchronously.
+ (void)sync:(void (^ _Nonnull) (void))block;

@end

NS_ASSUME_NONNULL_END
