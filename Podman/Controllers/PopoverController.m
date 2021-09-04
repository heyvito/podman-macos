//
//  ViewController.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import "PopoverController.h"
#import "PMManager.h"
#import "PMContainerCellView.h"
#import <Sparkle/Sparkle.h>

@interface PopoverController () <NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, SUUpdaterDelegate>

@property (weak) IBOutlet NSButton *optionsButton;
@property (weak) IBOutlet NSButton *vmStateChangeButton;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSImageView *statusIndicatorImage;
@property (strong) IBOutlet NSMenu *optionsMenu;
@property (weak) IBOutlet NSTableView *containersTableView;
@property (strong) IBOutlet NSMenu *contextMenu;

@property (weak) IBOutlet NSMenuItem *startContainerMenuItem;
@property (weak) IBOutlet NSMenuItem *restartContainerMenuItem;
@property (weak) IBOutlet NSMenuItem *killContainerMenuItem;
@property (weak) IBOutlet NSMenuItem *deleteContainerMenuItem;

@end

typedef NS_ENUM(NSUInteger, ServiceState) {
    ServiceStateAny,
    ServiceStateStopped,
    ServiceStateStopping,
    ServiceStateStarting,
    ServiceStateRunning,
};

@implementation PopoverController {
    NSTimer *updateTimer;
    PMManager *manager;
    ServiceState serviceState;
    ServiceState expectedNextState;
    NSArray<PMContainer *> *containers;
}

- (void)setPodmanState:(ServiceState)newState {
    if (self->expectedNextState != ServiceStateAny) {
        if (newState != self->expectedNextState) {
            return;
        }
        self->expectedNextState = ServiceStateAny;
    }

    switch (newState) {
        case ServiceStateAny:
            NSLog(@"BUG: Attempt to setPodmanState to ServiceStateAny");
            abort();
            return;
        case ServiceStateStopping:
            self.statusLabel.stringValue = @"Podman is Stopping";
            self.statusIndicatorImage.image = [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
            self.vmStateChangeButton.title = @"Stop Podman";
            self.vmStateChangeButton.enabled = NO;
            break;
        case ServiceStateRunning:
            self.statusLabel.stringValue = @"Podman is Running";
            self.statusIndicatorImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
            self.vmStateChangeButton.title = @"Stop Podman";
            self.vmStateChangeButton.enabled = YES;
            self.vmStateChangeButton.tag = ServiceStateStopped;
            break;
        case ServiceStateStopped:
            self.vmStateChangeButton.enabled = YES;
            self.vmStateChangeButton.tag = ServiceStateRunning;
            self.vmStateChangeButton.title = @"Start Podman";
            self.statusLabel.stringValue = @"Podman is Stopped";
            self.statusIndicatorImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
            break;
        case ServiceStateStarting:
            self.vmStateChangeButton.enabled = NO;
            self.vmStateChangeButton.title = @"Stop Podman";
            self.statusLabel.stringValue = @"Podman is Starting";
            self.statusIndicatorImage.image = [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
            break;
    }
    self->serviceState = newState;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.containersTableView.delegate = self;
    self.containersTableView.dataSource = self;
    self->expectedNextState = ServiceStateAny;
    self->manager = [PMManager manager];
    [self executePeriodicTasks:nil];
    [self.contextMenu setDelegate:self];
}

- (void)scheduleNextPeriodicTasks {
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(executePeriodicTasks:)
                                                 userInfo:nil
                                                  repeats:NO];
}

- (void)executePeriodicTasks:(NSTimer *)timer {
    if (timer != nil) {
        [timer invalidate];
        updateTimer = nil;
    }

    switch (self->manager.serviceStatus) {
        case PMServiceStatusRunning: {
            [self setPodmanState:ServiceStateRunning];
            [self->manager listContainersWithCallback:^(PMOperationResult<NSArray<PMContainer *> *> * result) {
                if (result.succeeded) {
                    self->containers = result.result;
                    NSInteger row = [self.containersTableView selectedRow];
                    [self.containersTableView reloadData];
                    [self.containersTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                }
                [self scheduleNextPeriodicTasks];
            }];
            return;
        }

        case PMServiceStatusStarting: {
            [self setPodmanState:ServiceStateStarting];
            break;
        }

        case PMServiceStatusStopped: {
            [self setPodmanState:ServiceStateStopped];
            break;
        }
    }
    
    [self scheduleNextPeriodicTasks];
}

- (IBAction)optionsButtonDidClick:(id)sender {
    [self.optionsMenu popUpMenuPositioningItem:[self.optionsMenu itemAtIndex:0] atLocation:NSEvent.mouseLocation inView:nil];
}

- (IBAction)vmStateChangeButtonDidClick:(id)sender {
    if (self->updateTimer != nil) {
        [self->updateTimer invalidate];
        self->updateTimer = nil;
    }

    if (self.vmStateChangeButton.tag == ServiceStateRunning) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self->manager startVM];
        });
        [self setPodmanState:ServiceStateStarting];
        self->expectedNextState = ServiceStateRunning;
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleWarning;
        alert.messageText = @"Are you sure you want to stop Podman?";
        alert.informativeText = @"Ensure you stopped your containers before continuing. Otherwise, data loss may occur.";
        NSButton *yesButton = [alert addButtonWithTitle:@"Yes"];
        yesButton.keyEquivalent = @"\r";
        NSButton *noButton = [alert addButtonWithTitle:@"No"];
        noButton.keyEquivalent = @"\033";
        if([alert runModal] == NSAlertFirstButtonReturn) {
            [self setPodmanState:ServiceStateStopping];
            self->expectedNextState = ServiceStateStopped;
            [self->manager stopVM];
        }
    }
    [self scheduleNextPeriodicTasks];
}

- (IBAction)aboutPodmanMenuDidClick:(id)sender {
    NSWindowController *controller = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"PMAboutWindow"];
    [controller showWindow:sender];
}

- (IBAction)quitPodmanMenuDidClick:(id)sender {
    if (self->serviceState == ServiceStateRunning) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleInformational;
        alert.messageText = @"Do you wish to keep Podman VM running?";
        alert.informativeText = @"Podman's VM seems to be running. Choosing Yes will keep the Podman Virtual Machine running, and will close this application. Otherwise, the VM will be stopped.";
        NSButton *yesButton = [alert addButtonWithTitle:@"Yes"];
        yesButton.keyEquivalent = @"\r";
        NSButton *noButton = [alert addButtonWithTitle:@"No"];
        noButton.keyEquivalent = @"\033";
        if([alert runModal] == NSAlertSecondButtonReturn) {
            [self->manager stopVM];
        }
    }

    [NSApp terminate:self];
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self->containers.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    PMContainer *container = self->containers[row];
    PMContainerCellView *view = [tableView makeViewWithIdentifier:@"ContainerCellView" owner:nil];
    view.containerID = container.containerID;
    view.containerStatus = container.containerStatus;
    view.containerName = container.containerName;
    view.containerImage = container.containerImage;
    view.showsSeparator = row < self->containers.count - 1;
    return view;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 52;
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu != self.contextMenu) {
        return;
    }
    
    if (self.containersTableView.selectedRow == -1) {
        self.startContainerMenuItem.enabled = NO;
        self.restartContainerMenuItem.enabled = NO;
        self.killContainerMenuItem.enabled = NO;
        self.deleteContainerMenuItem.enabled = NO;
        return;
    }
    
    PMContainer *container = [self->containers objectAtIndex:self.containersTableView.selectedRow];
    
    self.startContainerMenuItem.enabled = YES;
    self.deleteContainerMenuItem.enabled = YES;
    if (container.isRunning) {
        self.startContainerMenuItem.title = @"Stop";
        self.restartContainerMenuItem.enabled = YES;
        self.killContainerMenuItem.enabled = YES;
    } else {
        self.startContainerMenuItem.title = @"Start";
        self.restartContainerMenuItem.enabled = NO;
        self.killContainerMenuItem.enabled = NO;
    }
}


- (IBAction)startContainerMenuDidClick:(id)sender {
    if (self.containersTableView.selectedRow == -1) {
        return;
    }

    PMContainer *container = [self->containers objectAtIndex:self.containersTableView.selectedRow];
    __block NSString *operation;
    PMOperationCallback callback = ^(PMOperationResult *result) {
        if (!result.succeeded) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText = [NSString stringWithFormat:@"Could not %@ container %@", operation, container.containerName];
            alert.informativeText = result.output;
            NSButton *yesButton = [alert addButtonWithTitle:@"OK"];
            yesButton.keyEquivalent = @"\r";
            [alert runModal];
        }
    };

    if (container.isRunning) {
        container.containerStatus = @"Stopping...";
        operation = @"stop";
        [PMManager.manager stopContainer:container withCallback:callback];
    } else {
        container.containerStatus = @"Starting...";
        operation = @"start";
        [PMManager.manager startContainer:container withCallback:callback];
    }
}

- (IBAction)restartContainerMenuDidClick:(id)sender {
    if (self.containersTableView.selectedRow == -1) {
        return;
    }

    PMContainer *container = [self->containers objectAtIndex:self.containersTableView.selectedRow];
    [PMManager.manager restartContainer:container withCallback:^(PMOperationResult * _Nonnull result) {
        if (!result.succeeded) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText = [NSString stringWithFormat:@"Could not restart %@", container.containerName];
            alert.informativeText = result.output;
            NSButton *yesButton = [alert addButtonWithTitle:@"OK"];
            yesButton.keyEquivalent = @"\r";
            [alert runModal];
        }
    }];
}

- (IBAction)killContainerMenuDidClick:(id)sender {
    if (self.containersTableView.selectedRow == -1) {
        return;
    }

    PMContainer *container = [self->containers objectAtIndex:self.containersTableView.selectedRow];
    [PMManager.manager killContainer:container withCallback:^(PMOperationResult * _Nonnull result) {
        if (!result.succeeded) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText = [NSString stringWithFormat:@"Could not kill %@", container.containerName];
            alert.informativeText = result.output;
            NSButton *yesButton = [alert addButtonWithTitle:@"OK"];
            yesButton.keyEquivalent = @"\r";
            [alert runModal];
        }
    }];
}

- (IBAction)deleteContainerMenuDidClick:(id)sender {
    if (self.containersTableView.selectedRow == -1) {
        return;
    }

    PMContainer *container = [self->containers objectAtIndex:self.containersTableView.selectedRow];
    [PMManager.manager deleteContainer:container withCallback:^(PMOperationResult * _Nonnull result) {
        if (!result.succeeded) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText = [NSString stringWithFormat:@"Could not delete %@", container.containerName];
            alert.informativeText = result.output;
            NSButton *yesButton = [alert addButtonWithTitle:@"OK"];
            yesButton.keyEquivalent = @"\r";
            [alert runModal];
        }
    }];
}

- (IBAction)preferencesMenuItemDidClick:(id)sender {
    NSStoryboard *story = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSWindowController *controller = [story instantiateControllerWithIdentifier:@"PMPreferencesWindow"];
    [controller showWindow:sender];
}

@end
