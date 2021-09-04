//
//  PMCommon.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#ifndef PMCommon_h
#define PMCommon_h

typedef enum : NSUInteger {
    PMManagerInstallStatusDownloadingVM,
    PMManagerInstallStatusExtracting,
} PMManagerInstallStatus;

typedef enum : NSUInteger {
    PMServiceStatusRunning,
    PMServiceStatusStarting,
    PMServiceStatusStopped,
} PMServiceStatus;

typedef enum : NSUInteger {
    PMDetectStateNotInPath,
    PMDetectStateError,
    PMDetectStateOK,
} PMDetectState;

typedef enum : NSUInteger {
    PMVMPresencePresent,
    PMVMPresenceAbsent,
    PMVMPresenceError,
} PMVMPresence;

#endif /* PMCommon_h */
