#import "iOS/ModalNavigationController.h"

@implementation FuseModalNavigationController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.onLayout) {
        self.onLayout();
    }
}

@end
