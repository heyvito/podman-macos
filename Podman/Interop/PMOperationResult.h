//
//  PMOperationResult.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Foundation/Foundation.h>
#import "PMCommon.h"

NS_ASSUME_NONNULL_BEGIN

/// PMOperationResult represents the result of a background-running task, usually started by a PMManger
/// method.
@interface PMOperationResult <__covariant T> : NSObject

/// Indicates whether the operation succeeded. This flag indicates whether the underlying process exited with
/// a zeroed status code.
@property (nonatomic, readonly) BOOL succeeded;

/// Contains the text outputted to the standard output of the underlying process.
@property (nonatomic, readonly) NSString *output;

/// Contains an arbitrary value set by the method that created this result. Consult the method's documentation
/// to obtain further information.
@property (nonatomic, readonly, strong, nullable) T result;

+ (instancetype)resultWithSuccess:(BOOL)success andOutput:(nullable NSFileHandle *)output;
+ (instancetype)resultWithSuccess:(BOOL)success object:(nullable T)obj andOutput:(nullable NSFileHandle *)output;
+ (instancetype)resultWithTask:(NSTask *)task andPipe:(NSPipe *)pipe;

- (instancetype)initWithSuccess:(BOOL)success andOutput:(nullable NSFileHandle *)output;
- (instancetype)initWithSuccess:(BOOL)success object:(nullable T)obj andOutput:(nullable NSFileHandle *)output;

/// Returns the underlying value as a PMDetectState value
- (PMDetectState)detectStateValue;

/// Returns the underlying value as a PMServiceStatus value
- (PMServiceStatus)serviceStateValue;

/// Returns the underlying value as a PMVMPresence value
- (PMVMPresence)vmPresenceValue;
@end

NS_ASSUME_NONNULL_END
