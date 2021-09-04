//
//  PFMoveApplication.m, version 1.25
//  LetsMove
//
//  Created by Andy Kim at Potion Factory LLC on 9/17/09
//  Updated by Victor Gama on 9/03/21
//
//  The contents of this file are dedicated to the public domain.

#import "PMMoveToApplications.h"
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import <sys/mount.h>

// Strings
// These are macros to be able to use custom i18n tools
#define _I10NS(nsstr) NSLocalizedStringFromTableInBundle(nsstr, @"MoveApplication", [PMMoveToApplications bundle], nil)
#define kStrMoveApplicationCouldNotMove _I10NS(@"Could not move to Applications folder")
#define kStrMoveApplicationQuestionTitle  _I10NS(@"Move to Applications folder?")
#define kStrMoveApplicationQuestionTitleHome _I10NS(@"Move to Applications folder in your Home folder?")
#define kStrMoveApplicationQuestionMessage _I10NS(@"I can move myself to the Applications folder if you'd like.")
#define kStrMoveApplicationButtonMove _I10NS(@"Move to Applications Folder")
#define kStrMoveApplicationButtonDoNotMove _I10NS(@"Do Not Move")
#define kStrMoveApplicationQuestionInfoWillRequirePasswd _I10NS(@"Note that this will require an administrator password.")
#define kStrMoveApplicationQuestionInfoInDownloadsFolder _I10NS(@"This will keep your Downloads folder uncluttered.")

// By default, we use a small control/font for the suppression button.
// If you prefer to use the system default (to match your other alerts),
// set this to 0.
#define PFUseSmallAlertSuppressCheckbox 1

@interface PMMoveToApplications ()

+ (NSBundle *)bundle;

@end

@implementation PMMoveToApplications

+ (NSBundle *)bundle {
    return [NSBundle mainBundle];
}

static NSString *AlertSuppressKey = @"moveToApplicationsFolderAlertSuppress";
static BOOL MoveInProgress = NO;

// Main worker function
+ (void)moveToApplicationsFolderIfNecessary {
    // Make sure to do our work on the main thread.
    // Apparently Electron apps need this for things to work properly.
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self moveToApplicationsFolderIfNecessary];
        });
        return;
    }

    // Skip if user suppressed the alert before
    if ([[NSUserDefaults standardUserDefaults] boolForKey:AlertSuppressKey]) return;

    // Path of the bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

    // Check if the bundle is embedded in another application
    BOOL isNestedApplication = [self isApplicationAtPathNested:bundlePath];

    // Skip if the application is already in some Applications folder,
    // unless it's inside another app's bundle.
    if ([self isInApplicationsFolder:bundlePath] && !isNestedApplication) return;

    // OK, looks like we'll need to do a move - set the status variable appropriately
    MoveInProgress = YES;

    // File Manager
    NSFileManager *fm = [NSFileManager defaultManager];

    // Are we on a disk image?
    NSString *diskImageDevice = [self containingDiskImageDevice:bundlePath];

    // Since we are good to go, get the preferred installation directory.
    BOOL installToUserApplications = NO;
    NSString *applicationsDirectory = [self preferredInstallLocation:&installToUserApplications];
    NSString *bundleName = [bundlePath lastPathComponent];
    NSString *destinationPath = [applicationsDirectory stringByAppendingPathComponent:bundleName];

    // Check if we need admin password to write to the Applications directory
    BOOL needAuthorization = ([fm isWritableFileAtPath:applicationsDirectory] == NO);

    // Check if the destination bundle is already there but not writable
    needAuthorization |= ([fm fileExistsAtPath:destinationPath] && ![fm isWritableFileAtPath:destinationPath]);

    // Setup the alert
    NSAlert *alert = [[NSAlert alloc] init];
    {
        NSString *informativeText = nil;

        [alert setMessageText:(installToUserApplications ? kStrMoveApplicationQuestionTitleHome : kStrMoveApplicationQuestionTitle)];

        informativeText = kStrMoveApplicationQuestionMessage;

        if (needAuthorization) {
            informativeText = [informativeText stringByAppendingString:@" "];
            informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoWillRequirePasswd];
        }
        else if ([self isInDownloadsFolder:bundlePath]) {
            // Don't mention this stuff if we need authentication. The informative text is long enough as it is in that case.
            informativeText = [informativeText stringByAppendingString:@" "];
            informativeText = [informativeText stringByAppendingString:kStrMoveApplicationQuestionInfoInDownloadsFolder];
        }

        [alert setInformativeText:informativeText];

        // Add accept button
        [alert addButtonWithTitle:kStrMoveApplicationButtonMove];

        // Add deny button
        NSButton *cancelButton = [alert addButtonWithTitle:kStrMoveApplicationButtonDoNotMove];
        [cancelButton setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x1b]]; // Escape key

        // Setup suppression button
        [alert setShowsSuppressionButton:YES];

        if (PFUseSmallAlertSuppressCheckbox) {
            NSCell *cell = [[alert suppressionButton] cell];
            [cell setControlSize:NSControlSizeSmall];
            [cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        }
    }

    // Activate app -- work-around for focus issues related to "scary file from internet" OS dialog.
    if (![NSApp isActive]) {
        [NSApp activateIgnoringOtherApps:YES];
    }

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSLog(@"INFO -- Moving myself to the Applications folder");

        // Move
        if (needAuthorization) {
            BOOL authorizationCanceled;
            if (![self authorizedInstallAt:bundlePath withDestinationPath:destinationPath andCancelFlag:&authorizationCanceled]) {
                if (authorizationCanceled) {
                    NSLog(@"INFO -- Not moving because user canceled authorization");
                    MoveInProgress = NO;
                    return;
                }
                else {
                    NSLog(@"ERROR -- Could not copy myself to /Applications with authorization");
                    goto fail;
                }
            }
        }
        else {
            // If a copy already exists in the Applications folder, put it in the Trash
            if ([fm fileExistsAtPath:destinationPath]) {
                // But first, make sure that it's not running
                if ([self isApplicationAtPathRunning:destinationPath]) {
                    // Give the running app focus and terminate myself
                    NSLog(@"INFO -- Switching to an already running version");
                    [[NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObject:destinationPath]] waitUntilExit];
                    MoveInProgress = NO;
                    exit(0);
                }
                else {
                    if (![self trash:[applicationsDirectory stringByAppendingPathComponent:bundleName]])
                        goto fail;
                }
            }

            if (![self copyBundleAt:bundlePath to:destinationPath]) {
                NSLog(@"ERROR -- Could not copy myself to %@", destinationPath);
                goto fail;
            }
        }

        // Trash the original app. It's okay if this fails.
        // NOTE: This final delete does not work if the source bundle is in a network mounted volume.
        //       Calling rm or file manager's delete method doesn't work either. It's unlikely to happen
        //       but it'd be great if someone could fix this.
        if (!isNestedApplication && diskImageDevice == nil && ![self deleteOrTrash:bundlePath]) {
            NSLog(@"WARNING -- Could not delete application after moving it to Applications folder");
        }

        // Relaunch.
        [self relaunchWithPath:destinationPath];

        // Launched from within a disk image? -- unmount (if no files are open after 5 seconds,
        // otherwise leave it mounted).
        if (diskImageDevice && !isNestedApplication) {
            NSString *script = [NSString stringWithFormat:@"(/bin/sleep 5 && /usr/bin/hdiutil detach %@) &", [self shellQuotedString:diskImageDevice]];
            [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
        }

        MoveInProgress = NO;
        exit(0);
    }
    // Save the alert suppress preference if checked
    else if ([[alert suppressionButton] state] == NSControlStateValueOn) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:AlertSuppressKey];
    }

    MoveInProgress = NO;
    return;

fail:
    {
        // Show failure message
        alert = [[NSAlert alloc] init];
        [alert setMessageText:kStrMoveApplicationCouldNotMove];
        [alert runModal];
        MoveInProgress = NO;
    }
}

+ (BOOL) PFMoveIsInProgres {
    return MoveInProgress;
}



#pragma mark -
#pragma mark Helper Functions

+ (NSString *)preferredInstallLocation:(BOOL *)isUserDirectory {
    // Return the preferred install location.
    // Assume that if the user has a ~/Applications folder, they'd prefer their
    // applications to go there.

    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *userApplicationsDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES);

    if ([userApplicationsDirs count] > 0) {
        NSString *userApplicationsDir = [userApplicationsDirs objectAtIndex:0];
        BOOL isDirectory;

        if ([fm fileExistsAtPath:userApplicationsDir isDirectory:&isDirectory] && isDirectory) {
            // User Applications directory exists. Get the directory contents.
            NSArray *contents = [fm contentsOfDirectoryAtPath:userApplicationsDir error:NULL];

            // Check if there is at least one ".app" inside the directory.
            for (NSString *contentsPath in contents) {
                if ([[contentsPath pathExtension] isEqualToString:@"app"]) {
                    if (isUserDirectory) *isUserDirectory = YES;
                    return [userApplicationsDir stringByResolvingSymlinksInPath];
                }
            }
        }
    }

    // No user Applications directory in use. Return the machine local Applications directory
    if (isUserDirectory) *isUserDirectory = NO;

    return [[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES) lastObject] stringByResolvingSymlinksInPath];
}

+ (BOOL)isInApplicationsFolder:(NSString *)path {
    // Check all the normal Application directories
    NSArray *applicationDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
    for (NSString *appDir in applicationDirs) {
        if ([path hasPrefix:appDir]) return YES;
    }

    // Also, handle the case that the user has some other Application directory (perhaps on a separate data partition).
    if ([[path pathComponents] containsObject:@"Applications"]) return YES;

    return NO;
}

+ (BOOL)isInDownloadsFolder:(NSString *)path {
    NSArray *downloadDirs = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSAllDomainsMask, YES);
    for (NSString *downloadsDirPath in downloadDirs) {
        if ([path hasPrefix:downloadsDirPath]) return YES;
    }

    return NO;
}

+ (BOOL)isApplicationAtPathRunning:(NSString *)bundlePath {
    bundlePath = [bundlePath stringByStandardizingPath];

    for (NSRunningApplication *runningApplication in [[NSWorkspace sharedWorkspace] runningApplications]) {
        NSString *runningAppBundlePath = [[[runningApplication bundleURL] path] stringByStandardizingPath];
        if ([runningAppBundlePath isEqualToString:bundlePath]) {
            return YES;
        }
    }

    return NO;
}

+ (BOOL)isApplicationAtPathNested:(NSString *)path {
    NSString *containingPath = [path stringByDeletingLastPathComponent];

    NSArray *components = [containingPath pathComponents];
    for (NSString *component in components) {
        if ([[component pathExtension] isEqualToString:@"app"]) {
            return YES;
        }
    }

    return NO;
}

+ (NSString *)containingDiskImageDevice:(NSString *)path {
    NSString *containingPath = [path stringByDeletingLastPathComponent];

    struct statfs fs;
    if (statfs([containingPath fileSystemRepresentation], &fs) || (fs.f_flags & MNT_ROOTFS))
        return nil;

    NSString *device = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:fs.f_mntfromname length:strlen(fs.f_mntfromname)];

    NSTask *hdiutil = [[NSTask alloc] init];
    [hdiutil setLaunchPath:@"/usr/bin/hdiutil"];
    [hdiutil setArguments:[NSArray arrayWithObjects:@"info", @"-plist", nil]];
    [hdiutil setStandardOutput:[NSPipe pipe]];
    [hdiutil launch];
    [hdiutil waitUntilExit];

    NSData *data = [[[hdiutil standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSDictionary *info = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];;

    if (![info isKindOfClass:[NSDictionary class]]) return nil;

    NSArray *images = (NSArray *)[info objectForKey:@"images"];
    if (![images isKindOfClass:[NSArray class]]) return nil;

    for (NSDictionary *image in images) {
        if (![image isKindOfClass:[NSDictionary class]]) return nil;

        id systemEntities = [image objectForKey:@"system-entities"];
        if (![systemEntities isKindOfClass:[NSArray class]]) return nil;

        for (NSDictionary *systemEntity in systemEntities) {
            if (![systemEntity isKindOfClass:[NSDictionary class]]) return nil;

            NSString *devEntry = [systemEntity objectForKey:@"dev-entry"];
            if (![devEntry isKindOfClass:[NSString class]]) return nil;

            if ([devEntry isEqualToString:device])
                return device;
        }
    }

    return nil;
}

+ (BOOL) trash:(NSString *)path {
    BOOL result = [[NSFileManager defaultManager] trashItemAtURL:[NSURL fileURLWithPath:path] resultingItemURL:NULL error:NULL];

    // As a last resort try trashing with AppleScript.
    // This allows us to trash the app in macOS Sierra even when the app is running inside
    // an app translocation image.
    if (!result) {
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:
                                       [NSString stringWithFormat:@"\
                                        set theFile to POSIX file \"%@\" \n\
                                           tell application \"Finder\" \n\
                                              move theFile to trash \n\
                                        end tell", path]];
        NSDictionary *errorDict = nil;
        NSAppleEventDescriptor *scriptResult = [appleScript executeAndReturnError:&errorDict];
        if (scriptResult == nil) {
            NSLog(@"Trash AppleScript error: %@", errorDict);
        }
        result = (scriptResult != nil);
    }

    if (!result) {
        NSLog(@"ERROR -- Could not trash '%@'", path);
    }

    return result;
}

+ (BOOL)deleteOrTrash:(NSString *)path {
    NSError *error;

    if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        return YES;
    }
    else {
        // Don't log warning if on Sierra and running inside App Translocation path
        if ([path rangeOfString:@"/AppTranslocation/"].location == NSNotFound)
            NSLog(@"WARNING -- Could not delete '%@': %@", path, [error localizedDescription]);

        return [self trash:path];
    }
}

+ (BOOL)authorizedInstallAt:(NSString *)srcPath withDestinationPath:(NSString *)dstPath andCancelFlag:(BOOL *)canceled {
    if (canceled) *canceled = NO;

    // Make sure that the destination path is an app bundle. We're essentially running 'sudo rm -rf'
    // so we really don't want to fuck this up.
    if (![[dstPath pathExtension] isEqualToString:@"app"]) return NO;

    // Do some more checks
    if ([[dstPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;
    if ([[srcPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;

    int pid, status;
    AuthorizationRef myAuthorizationRef;

    // Get the authorization
    OSStatus err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
    if (err != errAuthorizationSuccess) return NO;

    AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights myRights = {1, &myItems};
    AuthorizationFlags myFlags = (AuthorizationFlags)(kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize);

    err = AuthorizationCopyRights(myAuthorizationRef, &myRights, NULL, myFlags, NULL);
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled && canceled)
            *canceled = YES;
        goto fail;
    }

    static OSStatus (*security_AuthorizationExecuteWithPrivileges)(AuthorizationRef authorization, const char *pathToTool,
                                                                   AuthorizationFlags options, char * const *arguments,
                                                                   FILE **communicationsPipe) = NULL;
    if (!security_AuthorizationExecuteWithPrivileges) {
        // On 10.7, AuthorizationExecuteWithPrivileges is deprecated. We want to still use it since there's no
        // good alternative (without requiring code signing). We'll look up the function through dyld and fail
        // if it is no longer accessible. If Apple removes the function entirely this will fail gracefully. If
        // they keep the function and throw some sort of exception, this won't fail gracefully, but that's a
        // risk we'll have to take for now.
        security_AuthorizationExecuteWithPrivileges = (OSStatus (*)(AuthorizationRef, const char*,
                                                                   AuthorizationFlags, char* const*,
                                                                   FILE **)) dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
    }
    if (!security_AuthorizationExecuteWithPrivileges) goto fail;

    // Delete the destination
    {
        char *args[] = {"-rf", (char *)[dstPath fileSystemRepresentation], NULL};
        err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/rm", kAuthorizationFlagDefaults, args, NULL);
        if (err != errAuthorizationSuccess) goto fail;

        // Wait until it's done
        pid = wait(&status);
        if (pid == -1 || !WIFEXITED(status)) goto fail; // We don't care about exit status as the destination most likely does not exist
    }

    // Copy
    {
        char *args[] = {"-pR", (char *)[srcPath fileSystemRepresentation], (char *)[dstPath fileSystemRepresentation], NULL};
        err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, args, NULL);
        if (err != errAuthorizationSuccess) goto fail;

        // Wait until it's done
        pid = wait(&status);
        if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;
    }

    AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
    return YES;

fail:
    AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
    return NO;
}

+ (BOOL)copyBundleAt:(NSString *)srcPath to:(NSString *)dstPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    if ([fm copyItemAtPath:srcPath toPath:dstPath error:&error]) {
        return YES;
    }
    else {
        NSLog(@"ERROR -- Could not copy '%@' to '%@' (%@)", srcPath, dstPath, error);
        return NO;
    }
}

+ (NSString *)shellQuotedString:(NSString *)string {
    return [NSString stringWithFormat:@"'%@'", [string stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

+ (void)relaunchWithPath:(NSString *)destinationPath {
    // The shell script waits until the original app process terminates.
    // This is done so that the relaunched app opens as the front-most app.
    int pid = [[NSProcessInfo processInfo] processIdentifier];

    // Command run just before running open /final/path
    NSString *preOpenCmd = @"";

    NSString *quotedDestinationPath = [self shellQuotedString:destinationPath];

    // OS X >=10.5:
    // Before we launch the new app, clear xattr:com.apple.quarantine to avoid
    // duplicate "scary file from the internet" dialog.
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) {
        // Add the -r flag on 10.6
        preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine %@", quotedDestinationPath];
    }
    else {
        preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d com.apple.quarantine %@", quotedDestinationPath];
    }

    NSString *script = [NSString stringWithFormat:@"(while /bin/kill -0 %d >&/dev/null; do /bin/sleep 0.1; done; %@; /usr/bin/open %@) &", pid, preOpenCmd, quotedDestinationPath];

    [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
}


@end


