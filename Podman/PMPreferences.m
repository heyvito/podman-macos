//
//  PMPreferences.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMPreferences.h"
#import "PMLoginItem.h"

@implementation PMPreferences

+ (BOOL)startAtLogin {
    return [PMLoginItem loginItemExistsWithURL:[[NSBundle mainBundle] bundleURL]];
}

+ (void)setStartAtLogin:(BOOL)startAtLogin {
    if (startAtLogin) {
        [PMLoginItem addLoginItemWithURL:[[NSBundle mainBundle] bundleURL]];
    } else {
        [PMLoginItem removeLoginItemWithURL:[[NSBundle mainBundle] bundleURL]];
    }
}

+ (BOOL)startPodmanVM {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"autoStartVM"] == nil) {
        return YES;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autoStartVM"];
}

+ (void)setStartPodmanVM:(BOOL)startPodmanVM {
    [[NSUserDefaults standardUserDefaults] setBool:startPodmanVM forKey:@"autoStartVM"];
}

+ (BOOL)checkForUpdates {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"autoUpdate"];
}

+ (void)setCheckForUpdates:(BOOL)checkForUpdates {
    [[NSUserDefaults standardUserDefaults] setBool:checkForUpdates forKey:@"autoUpdate"];
}

+ (BOOL)askedToStartAtLogin {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"askedToAutoStart"];
}

+ (void)setAskedToStartAtLogin:(BOOL)askedToStartAtLogin {
    [[NSUserDefaults standardUserDefaults] setBool:askedToStartAtLogin forKey:@"askedToAutoStart"];
}

@end
