#import "iOS/TabBarController.h"

@implementation FuseNativeTabBarController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.onLayout) {
        self.onLayout();
    }
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];

    if (self.onLayout) {
        self.onLayout();
    }
}

@end
