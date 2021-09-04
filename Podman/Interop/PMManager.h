//
//  PMManager.h
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import <Foundation/Foundation.h>
#import "PMCommon.h"
#import "PMContainer.h"
#import "PMOperationResult.h"

NS_ASSUME_NONNULL_BEGIN

/// PMManagerInstallState provides a snapshot of the installation progress in a determined moment.
/// This class is passed as a parameter of PMInstallCompletionHandler.
@interface PMManagerInstallState : NSObject

/// Indicates the installation status on this snapshot
@property (readonly, nonatomic) PMManagerInstallStatus status;

/// Represents a value that indicates the total progress to complete a task.
@property (readonly, nonatomic) NSUInteger total;

/// Represents a value indicating the amount of progress completed in relation to `total`.
@property (readonly, nonatomic) NSUInteger completed;


/// Initialises a new PMManagerInstallState
/// @param status The status to contain in this state
/// @param total The total progress of the operation
/// @param completed The completed progress of  the operation
- (instancetype)initWithStatus:(PMManagerInstallStatus)status total:(NSUInteger)total andCompleted:(NSUInteger)completed;

@end

typedef void (^_Nonnull PMInstallProgressHandler)(PMManagerInstallState * _Nonnull state);
typedef void (^_Nonnull PMInstallCompletionHandler)(NSError * _Nullable error);
typedef void (^_Nonnull PMOperationCallback)(PMOperationResult *result);


/// PMManager provides utilities to execute operations against the local Podman installation
@interface PMManager : NSObject

/// Provides a singleton instance of this class.
@property (nonatomic, class, readonly) PMManager *manager;


/// Represents the current service status.
@property (nonatomic, readonly) PMServiceStatus serviceStatus;


/// Detects whether Podman is available in the current system. Use the method `detectStateValue` to obtain
/// the underlying value representing the result of this operation.
- (PMOperationResult *)detectPodman;


/// Detects whether a Podman machine is already provisioned on this system. Use `detectVMValue` to obtain
/// the underlying value representing the result of this operation.
- (PMOperationResult *)detectVM;


/// Provisions a default Podman machine on this system.
/// @param progress The handler to be called with information about the progress of the installation.
/// @param completion The handler to be called when the installation completes (with or without errors)
- (nullable NSTask *)installVirtualMachineWithProgress:(PMInstallProgressHandler)progress
                                andCompletion:(PMInstallCompletionHandler)completion;


/// Starts the default Podman machine provisioned on this system.
- (PMOperationResult *)startVM;

/// Stops the default Podman machine provisioned on this system.
- (PMOperationResult *)stopVM;


/// Lists all containers on this system.
/// @param callback Callback to be called with the result of the operation. The callback is already
/// executed in the main queue.
- (void)listContainersWithCallback:(void (^_Nonnull) (PMOperationResult<NSArray <PMContainer *> *> * _Nullable list))callback;


/// Starts a given PMContainer
/// @param container Container to be started
/// @param callback Callback to be called when the operation completes. The callback is invoked in the
/// main queue.
- (void)startContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback;

/// Stops a given PMContainer
/// @param container Container to be stopped
/// @param callback Callback to be called when the operation completes. The callback is invoked in the
/// main queue.
- (void)stopContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback;

/// Restarts a given PMContainer
/// @param container Container to be restarted
/// @param callback Callback to be called when the operation completes. The callback is invoked in the
/// main queue.
- (void)restartContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback;

/// Kills a given PMContainer
/// @param container Container to be killed
/// @param callback Callback to be called when the operation completes. The callback is invoked in the
/// main queue.
- (void)killContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback;

/// Deletes a given PMContainer
/// @param container Container to be deleted
/// @param callback Callback to be called when the operation completes. The callback is invoked in the
/// main queue.
- (void)deleteContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback;

@end

NS_ASSUME_NONNULL_END
