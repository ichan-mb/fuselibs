#import "iOS/NativeNavigationDelegate.h"

@implementation FuseNavigationDelegate

- (instancetype)initWithCallbacks:(void (^)(NSString*))willShow
                          didShow:(void (^)(NSString*))didShow
{
    self = [super init];
    if (self) {
        _onWillShowViewController = willShow;
        _onDidShowViewController = didShow;
    }
    return self;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (_onWillShowViewController && viewController.view.accessibilityIdentifier) {
        _onWillShowViewController(viewController.view.accessibilityIdentifier);
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (_onDidShowViewController && viewController.view.accessibilityIdentifier) {
        _onDidShowViewController(viewController.view.accessibilityIdentifier);
    }
}

@end
