//
//  PMOperationResult.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMOperationResult.h"

@implementation PMOperationResult

+ (instancetype)resultWithSuccess:(BOOL)success andOutput:(NSFileHandle *)output {
    return [self resultWithSuccess:success object:nil andOutput:output];
}

+ (instancetype)resultWithSuccess:(BOOL)success object:(id)obj andOutput:(NSFileHandle *)output {
    return [[self alloc] initWithSuccess:success object:obj andOutput:output];
}

+ (instancetype)resultWithTask:(NSTask *)task andPipe:(NSPipe *)pipe {
    return [self resultWithSuccess:task.terminationStatus == 0 andOutput:pipe.fileHandleForReading];
}

- (instancetype)initWithSuccess:(BOOL)success object:(id)obj andOutput:(NSFileHandle *)output {
    if ((self = [self initWithSuccess:success andOutput:output]) == nil) {
        return self;
    }
    self->_result = obj;
    return self;
}

- (instancetype)initWithSuccess:(BOOL)success andOutput:(NSFileHandle *)output {
    if ((self = [super init]) == nil) {
        return nil;
    }

    if (output != nil) {
        self->_output = [[NSString alloc] initWithData:[output readDataToEndOfFile] encoding:NSUTF8StringEncoding];
    } else {
        self->_output = @"";
    }
    
    self->_succeeded = success;

    return self;
}

- (PMDetectState)detectStateValue {
    NSNumber *value = self.result;
    return value.unsignedIntegerValue;
}

- (PMServiceStatus)serviceStateValue {
    NSNumber *value = self.result;
    return value.unsignedIntegerValue;
}

- (PMVMPresence)vmPresenceValue {
    NSNumber *value = self.result;
    return value.unsignedIntegerValue;
}

@end
