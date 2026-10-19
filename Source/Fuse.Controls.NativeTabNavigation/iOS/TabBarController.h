#import <UIKit/UIKit.h>

#pragma once

/**
 The tab controller used for a `NativeTabNavigationView`. It reports each layout (and safe-area change)
 through `onLayout`, so the tab pages can follow the status bar / safe-area insets after rotation and
 window changes.
 */
@interface FuseNativeTabBarController : UITabBarController

@property (nonatomic, copy) void (^onLayout)(void);

@end
