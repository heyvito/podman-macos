//
//  PMManager.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import <Foundation/Foundation.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <AppKit/AppKit.h>
#include <sys/stat.h>

#import "PMManager.h"
#include "PMDispatch.h"

@import Darwin.C;

@implementation PMManagerInstallState

- (instancetype)initWithStatus:(PMManagerInstallStatus)status total:(NSUInteger)total andCompleted:(NSUInteger)completed {
    if ((self = [super init]) == nil) {
        return nil;
    }

    self->_status = status;
    self->_total = total;
    self->_completed = completed;

    return self;
}

@end

@implementation PMManager {
    NSString *podmanPath;
    NSString *podmanBasePath;
    NSDictionary *execEnvironments;

    NSRegularExpression *downloadExpr;
    NSRegularExpression *extractExpr;
    NSFileHandle *masterHandle, *slaveHandle;
}

+ (PMManager *)manager {
    static dispatch_once_t onceToken;
    static PMManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });

    return manager;
}

- (instancetype)init {
    if ((self = [super init]) == nil) {
        return nil;
    }

    NSError *exprErr = nil;
    downloadExpr = [NSRegularExpression
                    regularExpressionWithPattern:@"(?:\\^\\[\\[\\d*[A-Z])*([^:\\.]+): ?([^\\[]+)\\[([^\\]]+)\\] ?([a-zA-Z0-9\\. \\/]+)"
                    options:0
                    error:&exprErr];
    if (exprErr != nil) {
        NSLog(@"CRITICAL: installVirtualMachineWithProgress downloadExpr initialisation failed: %@", exprErr);
        abort();
    }

    extractExpr = [NSRegularExpression
                   regularExpressionWithPattern:@"(?:\\\\^\\[\\[\\d*[A-Z])*([Ee]xtracting[\\n]*)"
                   options:0
                   error:&exprErr
                   ];
    if (exprErr != nil) {
        NSLog(@"CRITICAL: installVirtualMachineWithProgress downloadExpr initialisation failed: %@", exprErr);
        abort();
    }

    return self;
}

- (PMServiceStatus)serviceStatus {
    if (![self vmRunning]) {
        return PMServiceStatusStopped;
    }

    if (![self serviceAccessible]) {
        return PMServiceStatusStarting;
    }

    return PMServiceStatusRunning;
}

- (NSArray<NSString *> *)paths {
    NSString *path = [NSProcessInfo.processInfo.environment objectForKey:@"PATH"];
    return [path componentsSeparatedByString:@":"];
}

- (NSString *)findInPath:(NSString *)appName {
    for (NSString *base in [self paths]) {
        NSString *target = [base stringByAppendingPathComponent:appName];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:target]) {
            return target;
        }
    }

    // Test for homebrew default paths as a last resort...
    NSArray *homebrewDefaultPaths = @[
        @"/usr/local/bin",
        @"/opt/homebrew/bin",
    ];

    for (NSString *base in homebrewDefaultPaths) {
        NSString *target = [base stringByAppendingPathComponent:appName];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:target]) {
            return target;
        }
    }

    return nil;
}

- (NSTask *)execCommand:(NSString *)command withPipe:(NSPipe *)pipe andArgs:(NSString *)procArgs, ... {
    NSMutableArray<NSString *> *argsArr = [[NSMutableArray alloc] init];
    [argsArr addObject:procArgs];
    va_list args;
    NSString *arg = nil;
    va_start(args, procArgs);
    while ((arg = va_arg(args, NSString *)) != nil) {
        [argsArr addObject:[arg copy]];
    }
    va_end(args);

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = command;
    task.arguments = argsArr;

    if (self->execEnvironments != nil) {
        task.environment = self->execEnvironments;
    }

    if (pipe != nil) {
        task.standardOutput = pipe;
    }

    return task;
}

- (PMOperationResult *)detectPodman {
    NSString *podmanPath = [self findInPath:@"podman"];
    if (podmanPath == nil) {
        NSLog(@"detectPodman: podman not in PATH");
        return [PMOperationResult resultWithSuccess:YES object:@(PMDetectStateNotInPath) andOutput:nil];
    }
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:podmanPath withPipe:pipe andArgs:@"--version", nil];
    [task launch];
    [task waitUntilExit];
    if (task.terminationStatus != 0) {
        return [PMOperationResult resultWithSuccess:NO object:@(PMDetectStateError) andOutput:pipe.fileHandleForReading];
    }
    self->podmanPath = podmanPath;
    self->podmanBasePath = [podmanPath stringByDeletingLastPathComponent];
    NSArray<NSString *> *pathComponents = [[NSProcessInfo.processInfo.environment objectForKey:@"PATH"] componentsSeparatedByString:@":"];

    NSDictionary *allEnvs = [NSProcessInfo.processInfo.environment mutableCopy];
    // Make sure podman's basedir is in PATH for commands we issue from the app
    if (![pathComponents containsObject:self->podmanBasePath]) {
        pathComponents = [pathComponents arrayByAddingObject:self->podmanBasePath];
        NSString *pathString = [pathComponents componentsJoinedByString:@":"];
        [allEnvs setValue:pathString forKey:@"PATH"];
    }
    self->execEnvironments = allEnvs;

    NSLog(@"detectPodman: Podman executable found at %@", podmanPath);
    return [PMOperationResult resultWithSuccess:YES object:@(PMDetectStateOK) andOutput:pipe.fileHandleForReading];
}

- (PMOperationResult *)detectVM {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"machine", @"list", @"--noheading", nil];
    [task launch];
    [task waitUntilExit];

    if (task.terminationStatus != 0) {
        return [PMOperationResult resultWithSuccess:NO object:@(PMVMPresenceError) andOutput:pipe.fileHandleForReading];
    }

    NSString *output = [[NSString alloc] initWithData:[pipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    if ([output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        return [PMOperationResult resultWithSuccess:YES object:@(PMVMPresenceAbsent) andOutput:nil];
    }

    return [PMOperationResult resultWithSuccess:YES object:@(PMVMPresencePresent) andOutput:nil];
}

- (void)handleInstallerOutput:(NSString *)input forProgressHandler:(PMInstallProgressHandler)handler {
    NSArray<NSTextCheckingResult *> *res = [downloadExpr matchesInString:input options:0 range:NSMakeRange(0, input.length)];
    if (res.count > 0) {
        NSTextCheckingResult *match = res[0];
//        NSString *status = [input substringWithRange:[match rangeAtIndex:1]];         // Downloading VM image
//        NSString *imageName = [input substringWithRange:[match rangeAtIndex:2]];    // fedora-coreos-34.20210821.1.1-qemu.x86_64.qcow2.xz
        NSString *progress = [input substringWithRange:[match rangeAtIndex:3]];       // =================>----------------------------------------
//        NSString *progressText = [input substringWithRange:[match rangeAtIndex:4]]; // 188.2MiB / 601.1MiB

        progress = [progress stringByReplacingOccurrencesOfString:@">" withString:@"="];
        NSUInteger total = 0, completed = 0;

        for (NSUInteger i = 0; i < progress.length; i++) {
            total++;
            if ([progress characterAtIndex:i] == '=') {
                completed++;
            }
        }

        handler([[PMManagerInstallState alloc] initWithStatus:PMManagerInstallStatusDownloadingVM total:total andCompleted:completed]);
        return;
    }

    res = [extractExpr matchesInString:input options:0 range:NSMakeRange(0, input.length)];
    if (res.count > 0) {
        handler([[PMManagerInstallState alloc] initWithStatus:PMManagerInstallStatusExtracting total:0 andCompleted:0]);
        return;
    }

    NSLog(@"%@", res);
}

- (NSTask *)installVirtualMachineWithProgress:(void (^)(PMManagerInstallState * _Nonnull))progress andCompletion:(void (^)(NSError * _Nullable))completion {
    // Fake a terminal so we can get download information while it runs.
    // This is a really ugly hack, but I'm really not sure what to do instead.

    int fdMaster, fdSlave;
    struct termios fakeTermios;
    struct winsize sz;
    sz.ws_col = 1024;
    sz.ws_row = 1024;
    sz.ws_xpixel = 60000;
    sz.ws_ypixel = 60000;
    memset(&fakeTermios, 0, sizeof(struct termios));

    int rc = openpty(&fdMaster, &fdSlave, NULL, &fakeTermios, &sz);
    if (rc != 0) {
        NSLog(@"installVirtualMachineWithProgress: openpty failed with status %d", rc);
        completion([NSError errorWithDomain:NSPOSIXErrorDomain code:rc userInfo:nil]);
        return nil;
    }

    fcntl(fdMaster, F_SETFD, FD_CLOEXEC);
    fcntl(fdSlave, F_SETFD, FD_CLOEXEC);

    masterHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdMaster closeOnDealloc:YES];
    slaveHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdSlave closeOnDealloc:YES];

    NSTask *task = [self execCommand:self->podmanPath withPipe:nil andArgs:@"machine", @"init", nil];
    task.standardInput = slaveHandle;
    task.standardOutput = slaveHandle;

    __weak typeof(self) weakSelf = self;
    masterHandle.readabilityHandler = ^(NSFileHandle *handle) {
        NSString *str = [[NSString alloc] initWithData:handle.availableData encoding:NSUTF8StringEncoding];
        NSLog(@"installVirtualMachineWithProgress: [handle offset %lld]: %@", handle.offsetInFile, str);
        [weakSelf handleInstallerOutput:str forProgressHandler:progress];
    };

    NSLog(@"installVirtualMachineWithProgress: Installation launch");
    [task launch];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [task waitUntilExit];
        self->masterHandle = nil;
        self->slaveHandle = nil;
        if (task.terminationStatus != 0) {
            completion([NSError errorWithDomain:@"PMMachineInitExitStatus" code:task.terminationStatus userInfo:nil]);
        } else {
            completion(nil);
        }
    });
    return task;
}

- (bool)vmRunning {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"machine", @"list", @"--noheading", @"--format", @"\"{{.LastUp}}\"", nil];
    [task launch];
    [task waitUntilExit];
    NSString *output = [[NSString alloc] initWithData:[pipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    return [output containsString:@"Currently running"];
}

- (bool)serviceAccessible {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"ps", nil];
    [task launch];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (PMOperationResult *)startVM {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"machine", @"start", nil];
    [task launch];
    [task waitUntilExit];
    return [PMOperationResult resultWithTask:task andPipe:pipe];
}

- (PMOperationResult *)stopVM {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"machine", @"stop", nil];
    [task launch];
    [task waitUntilExit];
    return [PMOperationResult resultWithTask:task andPipe:pipe];
}

- (void)listContainersWithCallback:(void (^)(PMOperationResult<NSArray<PMContainer *> *> *))callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath
                            withPipe:pipe
                             andArgs:@"ps", @"-a", @"--format", @"{{.ID}}${{.Image}}${{.Names}}${{.State}}", nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        if (task.terminationStatus != 0) {
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
            return;
        }

        NSString *output = [[NSString alloc] initWithData:[pipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        NSArray<NSString *> *lines = [output componentsSeparatedByString:@"\n"];
        NSMutableArray<PMContainer *> *result = [[NSMutableArray alloc] initWithCapacity:lines.count];
        for (NSString *line in lines) {
            NSArray<NSString *> *components = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"$"];
            if (components.count != 4) {
                continue;
            }
            PMContainer *container = [[PMContainer alloc] init];
            container.containerID = components[0];
            container.containerImage = components[1];
            container.containerName = components[2];
            NSString *status = [components[3] stringByReplacingOccurrencesOfString:@" ago" withString:@""];
            container.containerStatus = status;
            [result addObject:container];
        }
        [result sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            PMContainer *ca = obj1, *cb = obj2;
            return [ca.containerName compare:cb.containerName];
        }];

        [PMDispatch sync:^{
            callback([PMOperationResult resultWithSuccess:YES object:result andOutput:nil]);
        }];
    }];
}

- (void)startContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"start", container.containerID, nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        [PMDispatch sync:^{
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
        }];
    }];
}

- (void)stopContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"stop", container.containerID, nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        [PMDispatch sync:^{
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
        }];
    }];
}

- (void)restartContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"restart", container.containerID, nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        [PMDispatch sync:^{
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
        }];
    }];
}

- (void)killContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"kill", container.containerID, nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        [PMDispatch sync:^{
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
        }];
    }];
}

- (void)deleteContainer:(PMContainer *)container withCallback:(PMOperationCallback)callback {
    NSPipe *pipe = [NSPipe pipe];
    NSTask *task = [self execCommand:self->podmanPath withPipe:pipe andArgs:@"rm", @"-f", container.containerID, nil];
    [PMDispatch background:^{
        [task launch];
        [task waitUntilExit];
        [PMDispatch sync:^{
            callback([PMOperationResult resultWithTask:task andPipe:pipe]);
        }];
    }];
}

@end
