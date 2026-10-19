#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma once

/**
 A page's own container, which reports each layout through `onLayout`. Modals keep the app frame
 their insets are derived from (see PresentModal), so they ignore these reports.
 */
@interface FuseViewControllerRootView : UIView

@property (nonatomic, copy) void (^onLayout)(void);

@end