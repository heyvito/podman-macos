//
//  PMContainerCellView.h
//  Podman macOS
//
//  Created by Victor Gama on 03/09/2021.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PMContainerCellView : NSTableCellView

@property (nonatomic) NSString *containerName;
@property (nonatomic) NSString *containerImage;
@property (nonatomic) NSString *containerStatus;
@property (nonatomic, strong) NSString *containerID;
@property (nonatomic) BOOL showsSeparator;

@end

NS_ASSUME_NONNULL_END
