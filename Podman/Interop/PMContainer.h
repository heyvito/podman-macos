//
//  PMContainer.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Foundation/Foundation.h>
#import "PMOperationResult.h"

NS_ASSUME_NONNULL_BEGIN

/// PMContainer represents a single container in the Podman
@interface PMContainer : NSObject


/// Represents the container ID
@property (nonatomic) NSString *containerID;

/// Represents the container name
@property (nonatomic) NSString *containerName;

/// Represents the image this container is running
@property (nonatomic) NSString *containerImage;

/// Represents the container status
@property (nonatomic) NSString *containerStatus;

/// Returns whether the container is running inferring the value of `containerStatus`
@property (readonly, nonatomic) BOOL isRunning;

@end

NS_ASSUME_NONNULL_END
