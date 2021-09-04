//
//  PMInstallProgressViewController.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import "PMInstallProgressViewController.h"
#import "PMManager.h"
#import "AppDelegate.h"

@interface PMInstallProgressViewController ()
@property (weak) IBOutlet NSTextField *stateLabel;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSButton *cancelButton;

@end

@implementation PMInstallProgressViewController {
    NSTask *installTask;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)viewDidAppear {
    self.progressBar.maxValue = 100;
    self.progressBar.doubleValue = 0;
    installTask = [[PMManager manager] installVirtualMachineWithProgress:^(PMManagerInstallState * _Nonnull state) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (state.status == PMManagerInstallStatusDownloadingVM) {
                self.stateLabel.stringValue = @"Downloading VM Image...";
                self.progressBar.maxValue = state.total;
                self.progressBar.doubleValue = state.completed;
            } else {
                self.stateLabel.stringValue = @"Extracting image...";
                if (!self.progressBar.indeterminate) {
                    self.progressBar.indeterminate = YES;
                    self.progressBar.usesThreadedAnimation = YES;
                    [self.progressBar startAnimation:self];
                }
            }
        });
    } andCompletion:^(NSError * _Nullable error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (error != nil) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.alertStyle = NSAlertStyleCritical;
                alert.messageText = @"An error occurred during the installation process";
                alert.informativeText = @"Extra details may be available in the system's log.";
                [alert addButtonWithTitle:@"OK"];
                [alert beginSheetModalForWindow:self.view.window
                              completionHandler:^(NSModalResponse returnCode) {
                    [NSApplication.sharedApplication terminate:nil];
                }];
            } else {
                [[PMManager manager] startVM];
                AppDelegate *delegate = [NSApp delegate];
                [delegate startAgent];
                [self.view.window close];
            }
        });
    }];
}

- (IBAction)cancelButtonDidClick:(id)sender {

}

@end
