#pragma once

#import <UIKit/UIKit.h>

/**
 The navigation controller wrapping a presented modal. It reports each layout of its view through
 `onLayout` (see SetModalLayoutCallback), so the page follows size changes (sheet, rotation).
 */
@interface FuseModalNavigationController : UINavigationController

@property (nonatomic, copy) void (^onLayout)(void);

@end
