#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma once

/**
 Reports the tab the user selected back to the shared layer, which keeps its state in step.

 Only user selections arrive here; selecting a tab from code does not, as the shared layer already
 knows about that change.
 */
@interface FuseNativeTabBarDelegate : NSObject <UITabBarControllerDelegate>

@property (nonatomic, copy) void (^onSelected)(int index);

- (instancetype)initWithCallback:(void (^)(int))selected;

@end
