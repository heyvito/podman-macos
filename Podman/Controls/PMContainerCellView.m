//
//  PMContainerCellView.m
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import "PMContainerCellView.h"

@interface PMContainerCellView ()

@property (weak) IBOutlet NSTextField *containerNameLabel;
@property (weak) IBOutlet NSTextField *containerImageLabel;
@property (weak) IBOutlet NSTextField *containerStatusLabel;
@property (weak) IBOutlet NSBox *bottomSeparator;

@end

@implementation PMContainerCellView

- (void)setContainerName:(NSString *)containerName {
    self.containerNameLabel.stringValue = containerName;
}

- (NSString *)containerName {
    return self.containerNameLabel.stringValue;
}

- (void)setContainerImage:(NSString *)containerImage {
    self.containerImageLabel.stringValue = containerImage;
}

- (NSString *)containerImage {
    return self.containerImageLabel.stringValue;
}

- (void)setContainerStatus:(NSString *)containerStatus {
    self.containerStatusLabel.stringValue = containerStatus;
}

- (NSString *)containerStatus {
    return self.containerStatusLabel.stringValue;
}

- (void)setShowsSeparator:(BOOL)showsSeparator {
    self.bottomSeparator.hidden = !showsSeparator;
}

- (BOOL)showsSeparator {
    return !self.bottomSeparator.hidden;
}

@end
