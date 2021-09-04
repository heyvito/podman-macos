//
//  AppDelegate.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import <Sparkle/Sparkle.h>

#import "AppDelegate.h"
#import "PMStatusBarController.h"
#import "PopoverController.h"
#import "PMManager.h"
#import "PMMoveToApplications.h"
#import "PMPreferences.h"
#import "PMDispatch.h"

@interface AppDelegate ()

@end

@implementation AppDelegate {
    PMStatusBarController *controller;
    NSPopover *popover;
    BOOL agentRunning;
}

- (void)ensureSingleInstance {
    pid_t selfPid = [[NSRunningApplication currentApplication] processIdentifier];
    NSArray *appArray = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    for (NSRunningApplication *app in appArray) {
        if ([app processIdentifier] != selfPid) {
            [NSApp terminate:nil];
            break;
       }
    }
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [self ensureSingleInstance];
#ifndef DEBUG
    [PMMoveToApplications moveToApplicationsFolderIfNecessary];
#endif
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    SUUpdater *updater = [SUUpdater sharedUpdater];
    updater.automaticallyChecksForUpdates = PMPreferences.checkForUpdates;
    updater.feedURL = [NSURL URLWithString:@"https://heyvito.github.io/podman-macos/sparkle.xml"];

    PMOperationResult *detectPodmanResult = [PMManager.manager detectPodman];
    switch ([detectPodmanResult detectStateValue]) {
        case PMDetectStateNotInPath: {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = @"Podman for macOS did not find a Podman executable";
            alert.informativeText = @"Make sure Podman is installed and available in your PATH.";
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            [NSApp terminate:nil];
            return;
        }
        case PMDetectStateError: {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = @"Error detecting Podman executable";
            alert.informativeText = detectPodmanResult.output;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            [NSApp terminate:nil];
            return;
        }
        case PMDetectStateOK:
            NSLog(@"Podman detection succeeded.");
    }

    PMOperationResult *detectVMResult = [PMManager.manager detectVM];
    switch ([detectVMResult vmPresenceValue]) {
        case PMVMPresenceError: {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = @"Error detecting Podman Machine";
            alert.informativeText = detectVMResult.output;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            [NSApp terminate:nil];
            return;
        }

        case PMVMPresenceAbsent: {
            NSStoryboard *story = [NSStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
            NSWindowController *windowController = [story instantiateControllerWithIdentifier:@"InstallWindow"];
            [windowController showWindow:self];
            return;
        }

        case PMVMPresencePresent:
            NSLog(@"Podman Machine detection succeeded.");
    }

    [self startAgent];
}


- (void)startAgent {
    if (self->agentRunning) {
        return;
    }
    self->agentRunning = YES;

    NSStoryboard *story = [NSStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    NSViewController *viewController = [story instantiateControllerWithIdentifier:@"PopoverViewController"];
    popover = [[NSPopover alloc] init];
    popover.contentViewController = viewController;
    popover.behavior = NSPopoverBehaviorTransient;
    controller = [[PMStatusBarController alloc] initWithPopover:popover];
    if (PMPreferences.startPodmanVM) {
        NSLog(@"PM is set to autostart VM");
        if (PMManager.manager.serviceStatus == PMServiceStatusStopped) {
            [PMDispatch background:^{
                PMOperationResult *result = [PMManager.manager startVM];
                if (!result.succeeded) {
                    [PMDispatch sync:^{
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.alertStyle = NSAlertStyleWarning;
                        alert.messageText = @"Podman for macOS could not automatically start Podman's VM";
                        alert.informativeText = result.output;
                        [alert addButtonWithTitle:@"OK"];
                        [alert runModal];
                    }];
                } else {
                    NSLog(@"VM started successfully.");
                }
            }];
        } else {
            NSLog(@"VM is already running.");
        }
    }

    if (!PMPreferences.askedToStartAtLogin) {
        PMPreferences.askedToStartAtLogin = YES;
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleInformational;
        alert.messageText = @"Would you like to Podman for macOS to start at login?";
        alert.informativeText = @"This can be changed both in Podman for macOS's preferences and the System Preferences.";
        NSButton *yesButton = [alert addButtonWithTitle:@"Yes"];
        yesButton.keyEquivalent = @"\r";
        NSButton *noButton = [alert addButtonWithTitle:@"No"];
        noButton.keyEquivalent = @"\033";
        if([alert runModal] == NSAlertFirstButtonReturn) {
            PMPreferences.startAtLogin = YES;
        }
    }
}


- (void)applicationWillResignActive:(NSNotification *)notification {
    [popover close];
}


@end
