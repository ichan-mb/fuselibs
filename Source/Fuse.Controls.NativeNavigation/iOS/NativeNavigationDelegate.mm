#import "iOS/NativeNavigationDelegate.h"

@implementation FuseNavigationDelegate

- (instancetype)initWithCallbacks:(void (^)(NSString*))willAppear 
                       didAppear:(void (^)(NSString*))didAppear 
                   willDisappear:(void (^)(NSString*))willDisappear 
                    didDisappear:(void (^)(NSString*))didDisappear
{
    self = [super init];
    if (self) {
        _onViewWillAppear = willAppear;
        _onViewDidAppear = didAppear;
        _onViewWillDisappear = willDisappear;
        _onViewDidDisappear = didDisappear;
    }
    return self;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated
{
    if (_onViewWillAppear && viewController.title) {
        _onViewWillAppear(viewController.title);
    }
}

- (void)navigationController:(UINavigationController *)navigationController 
       didShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated
{
    if (_onViewDidAppear && viewController.title) {
        _onViewDidAppear(viewController.title);
    }
}

@end