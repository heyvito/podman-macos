//
//  PMPreferencesController.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMPreferencesController.h"
#import "PMPreferences.h"

@interface PMPreferencesController ()
@property (weak) IBOutlet NSButton *startAtLoginCheckbox;
@property (weak) IBOutlet NSButton *startVMCheckbox;
@property (weak) IBOutlet NSButton *checkForUpdatesCheckbox;

@end

@implementation PMPreferencesController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.startAtLoginCheckbox.state = PMPreferences.startAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
    self.startVMCheckbox.state = PMPreferences.startPodmanVM ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkForUpdatesCheckbox.state = PMPreferences.checkForUpdates ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)startAtLoginDidChange:(id)sender {
    PMPreferences.startAtLogin = self.startAtLoginCheckbox.state == NSControlStateValueOn;
}

- (IBAction)startVMDidChange:(id)sender {
    PMPreferences.startPodmanVM = self.startVMCheckbox.state == NSControlStateValueOn;
}

- (IBAction)checkForUpdatesDidChange:(id)sender {
    PMPreferences.checkForUpdates = self.checkForUpdatesCheckbox.state == NSControlStateValueOn;
}

@end
