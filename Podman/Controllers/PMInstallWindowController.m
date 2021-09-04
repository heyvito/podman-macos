//
//  PMInstallWindowController.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import "PMInstallWindowController.h"
#import "PMManager.h"

@interface PMInstallWindowController ()
@property (weak) IBOutlet NSButton *disclosureButton;
@property (weak) IBOutlet NSTextField *moreInfoLabel;
@property (strong) IBOutlet NSLayoutConstraint *moreInfoHideConstraint;

@end

@implementation PMInstallWindowController {
    CGSize initialSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.moreInfoHideConstraint.active = YES;
}

- (IBAction)moreInfoDidClick:(id)sender {
    self.disclosureButton.state = self.disclosureButton.state == 1 ? 0 : 1;
    [self disclosureDidClick:sender];
}

- (IBAction)disclosureDidClick:(id)sender {


    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.2;
        context.allowsImplicitAnimation = YES;

        self.moreInfoHideConstraint.animator.active = self.disclosureButton.state == 0;
        [self.view layoutSubtreeIfNeeded];

        NSWindow *window = self.view.window;
        NSRect rect = [window contentRectForFrameRect:window.frame];
        rect.size = self.view.fittingSize;
        NSRect frame = [window frameRectForContentRect:rect];
        frame.origin.y = window.frame.origin.y + (window.frame.size.height - frame.size.height);
        [self.view.window.animator setFrame:frame display:YES animate:YES];
    }];
}

- (IBAction)exitDidClick:(id)sender {
    [NSApplication.sharedApplication terminate:sender];
}

- (IBAction)installDidClick:(id)sender {
    NSWindow *window = self.view.window;
    NSViewController *newController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"PMInstallProgressViewController"];
    window.contentViewController = newController;
}


@end
