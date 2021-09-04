//
//  PMStatusBarController.m
//  Podman macOS
//
//  Created by Victor Gama on 02/09/2021.
//

#import "PMStatusBarController.h"

@implementation PMStatusBarController {
    NSStatusBar *statusBar;
    NSStatusItem *statusItem;
    NSPopover *popover;
}

- (instancetype)initWithPopover:(NSPopover *)popover {
    if ((self = [super init]) == nil) {
        return nil;
    }

    self->popover = popover;
    self->statusBar = [[NSStatusBar alloc] init];
    self->statusItem = [statusBar statusItemWithLength:28];
    self->statusItem.button.image = [NSImage imageNamed:@"icon"];
    self->statusItem.button.image.size = CGSizeMake(17.27, 16);
    self->statusItem.button.image.template = YES;
    self->statusItem.button.action = @selector(togglePopover:);
    self->statusItem.button.target = self;

    return self;
}

- (void)togglePopover:(id)sender {
    if (self->popover.isShown) {
        [self hidePopover:sender];
    } else {
        [self showPopover:sender];
    }
}

- (void)showPopover:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [self->popover showRelativeToRect:self->statusItem.button.bounds ofView:self->statusItem.button preferredEdge:NSRectEdgeMaxY];
}

- (void)hidePopover:(id)sender {
    [self->popover performClose:sender];
}

@end
