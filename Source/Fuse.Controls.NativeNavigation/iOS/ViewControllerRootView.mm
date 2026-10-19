#import "iOS/ViewControllerRootView.h"

@implementation FuseViewControllerRootView

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (self.onLayout) {
        self.onLayout();
    }
}

@end